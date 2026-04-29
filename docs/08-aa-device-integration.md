# CSA AA Device Integration Workflow

**Version**: 1.0  
**Last Updated**: 2026-04-28  
**Status**: Active  

---

## Overview

CSA (Crooked Sentry Appliances) now consumes device attestation handoffs from AA (acephalous-assembler) to drive downstream integrations. This document describes the complete workflow: from AA device discovery through CSA camera integration in Frigate and Home Assistant.

### Key Principles

1. **AA is source of truth** – Device discovery, identity verification, and capabilities detection happen in AA
2. **CSA is consumer** – CSA reads AA handoffs and generates integration configs
3. **No secrets in handoff** – AA handoff contains no credentials; CSA sources those separately
4. **Clear audit trail** – All integration decisions are logged with reasoning
5. **Fail safely** – Unverified or unreachable devices are blocked, not integrated silently

---

## Workflow Phases

```
┌─────────────────────────────────────────────────────────────────┐
│ Phase 1: AA Device Discovery (AA owns this)                     │
├─────────────────────────────────────────────────────────────────┤
│ • Scan network for LAN devices                                  │
│ • Probe each device (HTTP, RTSP, ONVIF, etc.)                  │
│ • Verify device identity (serial #, capabilities match)         │
│ • Collect endpoints and capabilities                            │
│ • Generate device attestation record                            │
│ • Emit handoff artifact (JSON)                                  │
└─────────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────────┐
│ Phase 2: CSA Handoff Consumption (CSA owns this)                │
├─────────────────────────────────────────────────────────────────┤
│ • Read AA device handoff artifact                               │
│ • Validate schema and device records                            │
│ • Determine eligibility for integration                         │
│ • Classify devices: READY | PARTIAL | BLOCKED                  │
│ • Generate integration configs for eligible devices             │
│ • Produce audit trail with decisions and reasoning              │
└─────────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────────┐
│ Phase 3: Operator Review & Deployment                           │
├─────────────────────────────────────────────────────────────────┤
│ • Operator reviews CSA audit report                             │
│ • Validates integration configs (Frigate, HA)                   │
│ • Deploys configs to running services                           │
│ • Restarts/reloads services if needed                           │
│ • Verifies devices appear in UIs                                │
└─────────────────────────────────────────────────────────────────┘
```

---

## Device Eligibility Rules

### READY Status ✅

Device is **READY** for integration if:

1. `identity_verified == true` (AA confirmed device identity via serial, capabilities match, etc.)
2. At least one capability is present (RTSP, HTTP, etc.)
3. No blocking failures in firmware_operation or hostname_operation

**Action**: Generate full integration configs (Frigate camera, HA device, MQTT topics)

**Example**:

```json
{
  "device_name": "front_door",
  "identity_verified": true,
  "identity": {"serial": "ABC123", "verified_at": "2026-04-28T15:30:00Z"},
  "capabilities": [
    {"protocol": "rtsp", "endpoint": "rtsp://192.168.0.150:554/stream"}
  ],
  "firmware_operation": {"status": "success", "version": "2.0.1"}
}
```

### PARTIAL Status ⚠️

Device is **PARTIAL** if:

1. Device is reachable (network-accessible)
2. Has at least one capability (RTSP, HTTP, etc.)
3. BUT identity is **NOT verified** by AA (verification_message indicates uncertainty)
4. No critical blockers (not unreachable)

**Action**: Generate integration configs with cautions/notes. Operator may integrate with verification caveat.

**Example**:

```json
{
  "device_name": "garage",
  "identity_verified": false,
  "verification_message": "Device reachable but identity confirmation pending",
  "capabilities": [
    {"protocol": "rtsp", "endpoint": "rtsp://192.168.0.152:554/stream"}
  ]
}
```

### BLOCKED Status 🚫

Device is **BLOCKED** from integration if:

1. Device is unreachable (network unavailable) – verification_message contains "not reachable"
2. Critical capability missing (camera with no RTSP endpoint)
3. Firmware operation failed with blocking status
4. Identity verification failed with hard error (not just "pending")

**Action**: Skip integration, document blocker in audit report with remediation steps.

**Example**:

```json
{
  "device_name": "backyard",
  "identity_verified": false,
  "verification_message": "Device at 192.168.0.151 not reachable",
  "capabilities": []
}
```

---

## Integration Targets

### 1. Frigate

**When**: Device has RTSP endpoint and READY or PARTIAL status

**Output**: `frigate/cameras.yml` fragment

**Fields from handoff**:

- `device_name` → camera name in Frigate
- `rtsp_endpoint` → ffmpeg input path
- `brand`, `model` → comments for reference
- `desired_hostname` → DNS name in setup

**Generated config**:

```yaml
front_door:
  enabled: true
  ffmpeg:
    inputs:
      - path: rtsp://192.168.0.150:554/stream
        roles:
          - detect
          - record
          - rtmp
  detect:
    width: 1920
    height: 1080
    fps: 5
```

**Deployment**:

```bash
# 1. Review the generated config
cat .coordination/integration-output/frigate/cameras.yml

# 2. Append to your Frigate config
cat .coordination/integration-output/frigate/cameras.yml >> \
  ~/frigate-setup/frigate/config/config.yml

# 3. Validate and restart
docker restart frigate

# 4. Check Frigate sees the camera
curl http://192.168.0.18:5000/api/cameras
```

### 2. Home Assistant

**When**: Device is READY or PARTIAL status

**Output**: `homeassistant/devices.yaml` fragment (YAML)

**Fields from handoff**:

- `device_name` → HA device ID
- `desired_hostname`, `ip_address` → connections
- `brand`, `model` → manufacturer/model
- `identity_verified` → integration trust level
- `http_endpoint` → configuration URL

**Generated entry**:

```yaml
- id: "csa_camera_front_door"
  name: "front_door"
  manufacturer: "anke"
  model: "I51DL"
  identifiers:
    - ["csa_device", "front_door"]
  connections:
    - ["ip", "192.168.0.150"]
    - ["hostname", "front-door.local"]
  configuration_url: "http://192.168.0.150:80"
```

**Deployment**:

1. Home Assistant auto-discovers MQTT devices and can import YAML
2. Or operator manually creates devices in HA UI using the generated YAML as reference
3. Or use HA automation to import via REST API

---

## AA → CSA Data Flow

### Input: AA Device Handoff

```json
{
  "schema_version": "1.0",
  "generated_at": "2026-04-28T15:32:06.256413+00:00",
  "aa_version": "0.4.0",
  "devices": [
    {
      "device_name": "front_door",
      "desired_hostname": "front-door.local",
      "ip_address": "192.168.0.150",
      "brand": "anke",
      "model": "I51DL",
      "identity": {"serial": "ABC123", "verified_at": "2026-04-28T15:30:00Z"},
      "capabilities": [
        {
          "protocol": "http",
          "endpoint": "http://192.168.0.150:80",
          "description": "HTTP API access"
        },
        {
          "protocol": "rtsp",
          "endpoint": "rtsp://192.168.0.150:554/stream",
          "description": "RTSP stream endpoint"
        }
      ],
      "identity_verified": true,
      "verification_message": "Device identity verified",
      "firmware_operation": {"status": "success", "version": "2.0.1"},
      "hostname_operation": {"status": "success", "hostname": "front-door.local"}
    }
  ],
  "handoff_notes": "All devices verified and ready for integration."
}
```

### Processing: CSA Parser

The `aa-handoff-parser.sh` script:

1. Validates handoff schema
2. For each device, determines eligibility (READY/PARTIAL/BLOCKED)
3. Outputs structured JSON with integration-ready devices

**Output**: `parsed-devices.json`

```json
{
  "devices": [
    {
      "device_name": "front_door",
      "status": "READY",
      "reason": "Device verified with capabilities",
      "blockers": [],
      "device_name": "front_door",
      "desired_hostname": "front-door.local",
      "ip_address": "192.168.0.150",
      "brand": "anke",
      "model": "I51DL",
      "identity_verified": true,
      "rtsp_endpoint": "rtsp://192.168.0.150:554/stream",
      "http_endpoint": "http://192.168.0.150:80"
    }
  ]
}
```

### Integration: CSA Integrator

The `aa-device-integrator.sh` script:

1. Reads parsed device JSON
2. For each READY/PARTIAL device, generates:
   - Frigate camera config
   - Home Assistant device definition
   - Integration audit record
3. Outputs configs to standardized directories

**Output**:

```
.coordination/integration-output/
├── frigate/
│   └── cameras.yml          # Append to Frigate config
├── homeassistant/
│   └── devices.yaml         # Import to HA
└── audit/
    └── integration-report.md  # Audit trail and next steps
```

---

## Usage: Step-by-Step

### Step 1: Obtain AA Device Handoff

AA emits handoff to `.coordination/device-handoff-latest.json`:

```bash
# Check if handoff exists and is recent
ls -lh .coordination/device-handoff-latest.json

# Or trigger AA to generate fresh handoff
# (AA-specific command, e.g., aa-cli device-handoff --output=.coordination/device-handoff-latest.json)
```

### Step 2: Parse and Validate Handoff

```bash
./scripts/aa-handoff-parser.sh .coordination/device-handoff-latest.json

# Output:
# [INFO] Parsing AA device handoff: .coordination/device-handoff-latest.json
# [INFO] AA Version: 0.4.0 (Schema: 1.0)
# ...
# ### Device: front_door
# - Status: **READY**
# - Reason: Device verified with capabilities
#
# | Status | Count |
# |--------|-------|
# | READY | 1 |
# | PARTIAL | 0 |
# | BLOCKED | 1 |
```

### Step 3: Generate Integration Configs

```bash
# Parse handoff and store output
./scripts/aa-handoff-parser.sh .coordination/device-handoff-latest.json > \
  .coordination/parsed-devices.json

# Generate Frigate/HA configs
./scripts/aa-device-integrator.sh .coordination/parsed-devices.json \
  .coordination/integration-output

# Output files created:
# .coordination/integration-output/
#   ├── frigate/cameras.yml
#   ├── homeassistant/devices.yaml
#   └── audit/integration-report.md
```

### Step 4: Review Audit Trail

```bash
cat .coordination/integration-output/audit/integration-report.md

# Output:
# # CSA Device Integration Report
# Generated: 2026-04-28 15:35:00
#
# ## Summary
#
# - **Total Devices**: 3
# - **Frigate Cameras Integrated**: 2
# - **Home Assistant Devices**: 3
#
# ### Device: front_door
# - **IP**: 192.168.0.150
# - **Hostname**: front-door.local
# - **Brand/Model**: ANKE I51DL
# - **Identity Verified**: true
# - **RTSP Endpoint**: rtsp://192.168.0.150:554/stream
# ...
```

### Step 5: Deploy Configurations

#### For Frigate

```bash
# 1. Preview what will be added
echo "=== New cameras to add to Frigate ==="
cat .coordination/integration-output/frigate/cameras.yml

# 2. Back up current config
cp ~/frigate-setup/frigate/config/config.yml \
   ~/frigate-setup/frigate/config/config.yml.backup.$(date +%s)

# 3. Append camera configs
cat .coordination/integration-output/frigate/cameras.yml >> \
  ~/frigate-setup/frigate/config/config.yml

# 4. Validate syntax
docker exec frigate frigate config --check || {
    echo "Config validation failed, restoring..."
    cp ~/frigate-setup/frigate/config/config.yml.backup.* \
       ~/frigate-setup/frigate/config/config.yml
    exit 1
}

# 5. Restart Frigate
docker restart frigate

# 6. Verify cameras registered
sleep 5
curl http://192.168.0.18:5000/api/cameras
```

#### For Home Assistant

```bash
# Option A: Manual import via HA UI
# 1. Log into HA: http://192.168.0.13:8123
# 2. Settings > Devices & Services > Devices
# 3. Manually add device using info from:
#    .coordination/integration-output/homeassistant/devices.yaml

# Option B: Automated import (if HA has automation scripts)
# 1. Copy YAML to HA config directory
# 2. Reload HA YAML
# 3. Devices should appear in UI

# Option C: Use HA REST API
cat .coordination/integration-output/homeassistant/devices.yaml | \
  python3 - << 'PYTHON'
import yaml
import sys
import requests

# Parse HA device YAML
devices = yaml.safe_load(sys.stdin)

# Call HA API for each device
ha_url = "http://192.168.0.13:8123"
ha_token = "YOUR_HA_TOKEN_HERE"  # Set from secrets

headers = {"Authorization": f"Bearer {ha_token}"}

for device in devices:
    response = requests.post(
        f"{ha_url}/api/devices",
        json=device,
        headers=headers
    )
    print(f"Device {device['name']}: {response.status_code}")
PYTHON
```

### Step 6: Verify Integration

```bash
# Check Frigate sees all cameras
echo "=== Frigate Cameras ==="
curl -s http://192.168.0.18:5000/api/cameras | jq '.[] | {name, status}'

# Check HA device registry (via SSH to HA)
echo "=== Home Assistant Devices ==="
ssh root@192.168.0.13 "cat /config/storage/device_registry.json | jq '.devices[] | {name, model}'"

# Test MQTT topics (if using MQTT integration)
echo "=== MQTT Device Topics ==="
mosquitto_sub -h 192.168.0.13 -u homeassistant -P '<password>' \
  -t 'homeassistant/#' \
  -v \
  -C 5  # Read first 5 messages then exit
```

---

## Error Handling & Troubleshooting

### Scenario: "Device not reachable"

**AA Handoff Shows**:

```json
{
  "device_name": "backyard",
  "verification_message": "Device at 192.168.0.151 not reachable",
  "capabilities": []
}
```

**CSA Action**: Blocks device (BLOCKED status)

**Remediation**:

1. Check physical connection (power, Ethernet/WiFi)
2. Verify device IP is correct (`ping 192.168.0.151`)
3. Re-run AA discovery after device comes online
4. Re-run CSA handoff parser and integrator

### Scenario: "Identity not verified"

**AA Handoff Shows**:

```json
{
  "device_name": "garage",
  "identity_verified": false,
  "verification_message": "Device reachable but identity confirmation pending",
  "capabilities": [...]
}
```

**CSA Action**: PARTIAL status (integrable with caution)

**Remediation**:

1. Device is reachable and has endpoints
2. Safe to integrate if you trust the IP/brand/model info
3. Operator should review audit report and validate device manually
4. OR wait for AA to verify device on next discovery run

### Scenario: "Firmware operation failed"

**AA Handoff Shows**:

```json
{
  "device_name": "driveway",
  "firmware_operation": {"status": "failed", "error": "Device firmware too old"},
  "identity_verified": false
}
```

**CSA Action**: BLOCKED (firmware issue prevents integration)

**Remediation**:

1. Device firmware is outdated
2. AA can auto-update if enabled
3. Or manually update device firmware (consult device vendor)
4. Re-run AA discovery after update
5. Re-run CSA handoff parser

---

## Audit Report Interpretation

CSA generates audit reports in markdown format at:

```
.coordination/integration-output/audit/integration-report.md
```

### Report Structure

```markdown
# CSA Device Integration Report
Generated: 2026-04-28 15:35:00

## Summary
| Status | Count |
|--------|-------|
| READY | 2 |
| PARTIAL | 1 |
| BLOCKED | 1 |

**Total Devices**: 4
**Integrable**: 3

## Device Integration Details

### front_door
- **IP**: 192.168.0.150
- **Hostname**: front-door.local
- **Brand/Model**: ANKE I51DL
- **Identity Verified**: true
- **RTSP Endpoint**: rtsp://192.168.0.150:554/stream
- **HTTP Endpoint**: http://192.168.0.150:80

### backyard
- **IP**: 192.168.0.151
- **Hostname**: backyard.local
- **Brand/Model**: ANKE I51DL
- **Identity Verified**: false
- **RTSP Endpoint**: N/A  ← ⚠️ NO RTSP = BLOCKED
- **HTTP Endpoint**: N/A
```

**Key Points**:

- **READY**: Device appears in integration outputs (Frigate, HA configs generated)
- **PARTIAL**: Device appears in audit but may need operator review
- **BLOCKED**: Device listed but NOT in integration outputs; see blocker reason

---

## Testing

Run the integration test suite:

```bash
./scripts/test-aa-integration.sh

# Output:
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CSA AA Device Integration Test Suite
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 
# TEST: Parser validates AA schema
# ✓ PASS: Parser accepts valid schema
# 
# TEST: Parser identifies READY devices
# ✓ PASS: Parser marks verified device as READY
# 
# ...
# 
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Tests Passed: 9 | Tests Failed: 0
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Security Considerations

### Secrets NOT in Handoff

AA handoff contains NO secrets:

- ✅ Device IPs, hostnames, capabilities (public)
- ✅ Firmware versions, model info (public)
- ❌ Passwords, API tokens (NOT included)
- ❌ MQTT credentials (NOT included)

**CSA sourcing secrets**:

- MQTT credentials: Loaded from `.coordination/mqtt-credentials.env` (operator-managed)
- Device admin passwords: Not needed for basic integration; sourced separately if required
- API tokens: Sourced from HA/Frigate at runtime

### Validation

- Parser validates handoff schema strictly
- Integrator checks device eligibility before generating configs
- Blocked devices never appear in output configs
- Audit trail documents all decisions for compliance

---

## Next Steps / Future Enhancements

- [ ] Auto-update device firmware via AA if available
- [ ] Support for ONVIF device discovery and configuration
- [ ] Integration with Home Assistant YAML-based device provisioning
- [ ] Support for multi-brand device classes (doorbell, thermostat, sensor, etc.)
- [ ] Dynamic re-probing of PARTIAL devices with operator action
- [ ] Integration with CSA monitoring/alerting (device offline, unreachable, etc.)
- [ ] Support for device group configurations (e.g., "front entrance cameras")

---

## Questions?

See the main CSA README for general guidance. For AA-specific issues, see acephalous-assembler documentation.
