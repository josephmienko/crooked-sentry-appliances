# AA v2.0 → CSA v2.0 Handoff Integration Guide

**Purpose**: Document how to capture and validate bootstrap handoff from acephalous-assembler.

**Schema Reference**: See [examples/bootstrap-handoff.example.json](../examples/bootstrap-handoff.example.json)

---

## Quick Start

After AA bootstrap completes on your machine:

```bash
# Option 1: Validate handoff from standard location (if accessible)
./scripts/validate-network-connectivity.sh --print-config /var/lib/acephalous-assembler/bootstrap-handoff.json

# Option 2: Pull handoff via SCP from bootstrapped machine
scp ubuntu@192.168.1.20:/var/lib/acephalous-assembler/bootstrap-handoff.json ./bootstrap-handoff.json
./scripts/validate-network-connectivity.sh --print-config ./bootstrap-handoff.json
```

✓ If validation passes, proceed to Phase 1.

---

## Handoff Flow

```
AA Bootstrap (End)
    ↓
    Writes: /var/lib/acephalous-assembler/bootstrap-handoff.json
    Contains: schema_version=2.0, machine.*, bootstrap.*, verification.*
    ↓
CSA Coordinator (Reads)
    ↓
    ./scripts/validate-network-connectivity.sh --print-config <handoff>
    ↓
    Parses: IP/hostname, SSH user/port, marker path
    ↓
    ✓ Ready for Phase 1
```

---

## Implementation Options

### Option 1: Standard Location (Easiest)

AA writes to standard path; CSA reads from there.

```bash
./scripts/validate-network-connectivity.sh --print-config /var/lib/acephalous-assembler/bootstrap-handoff.json
```

**Prerequisites**:

- Handoff location accessible from coordinator
- File permissions readable

---

### Option 2: SCP from Bootstrapped Machine (Portable)

Retrieve handoff from running machine via SSH.

```bash
# Define connection details
BOOTSTRAP_HOST="192.168.1.20"
BOOTSTRAP_USER="ubuntu"
BOOTSTRAP_KEY="~/.ssh/id_ed25519"

# Retrieve handoff
scp -i "$BOOTSTRAP_KEY" \
    "$BOOTSTRAP_USER@$BOOTSTRAP_HOST:/var/lib/acephalous-assembler/bootstrap-handoff.json" \
    ./bootstrap-handoff.json

# Validate
./scripts/validate-network-connectivity.sh --print-config ./bootstrap-handoff.json
```

**Prerequisites**:

- SSH access to bootstrapped machine
- SSH key in ~/.ssh/

---

### Option 3: SSH with Output Redirection (No SCP Needed)

Use SSH to cat handoff if SCP unavailable.

```bash
ssh -i "$BOOTSTRAP_KEY" \
    "$BOOTSTRAP_USER@$BOOTSTRAP_HOST" \
    "cat /var/lib/acephalous-assembler/bootstrap-handoff.json" > bootstrap-handoff.json

./scripts/validate-network-connectivity.sh --print-config bootstrap-handoff.json
```

---

### Option 4: Async Capture with Validation Loop

Wait for handoff to appear, then validate.

```bash
#!/bin/bash
BOOTSTRAP_HOST="192.168.1.20"
BOOTSTRAP_USER="ubuntu"
BOOTSTRAP_KEY="~/.ssh/id_ed25519"
LOCAL_HANDOFF="bootstrap-handoff.json"
MAX_ATTEMPTS=10
ATTEMPT=0

while [[ $ATTEMPT -lt $MAX_ATTEMPTS ]]; do
  ATTEMPT=$((ATTEMPT + 1))
  echo "Attempt $ATTEMPT/$MAX_ATTEMPTS..."
  
  if scp -o ConnectTimeout=5 -i "$BOOTSTRAP_KEY" \
      "$BOOTSTRAP_USER@$BOOTSTRAP_HOST:/var/lib/acephalous-assembler/bootstrap-handoff.json" \
      "$LOCAL_HANDOFF" 2>/dev/null; then
    
    if jq . "$LOCAL_HANDOFF" > /dev/null 2>&1; then
      ./scripts/validate-network-connectivity.sh --print-config "$LOCAL_HANDOFF"
      echo "✓ Ready for Phase 1"
      exit 0
    fi
  fi
  
  sleep 5
done

echo "✗ Failed to retrieve handoff"
exit 1
```

---

### Option 5: Multi-Machine Deployment

Collect handoffs from multiple bootstrapped machines in parallel.

```bash
MACHINES=(
  "192.168.1.20:ubuntu"
  "192.168.1.21:ubuntu"
  "192.168.1.22:ubuntu"
)

# Collect all in parallel
for machine in "${MACHINES[@]}"; do
  IFS=: read -r host user <<< "$machine"
  scp "$user@$host:/var/lib/acephalous-assembler/bootstrap-handoff.json" \
      "./bootstrap-handoff-${host}.json" &
done

wait

# Validate all
for handoff in bootstrap-handoff-*.json; do
  ./scripts/validate-network-connectivity.sh --print-config "$handoff"
done
```

---

## Schema Validation Commands

### Check Schema Version

```bash
jq '.schema_version' bootstrap-handoff.json
# Expected: "2.0"
```

### Verify Build Status

```bash
jq '.build.status' bootstrap-handoff.json
# Expected: "media_and_flash_complete"
```

### Verify Bootstrap Ready for CSA

```bash
jq '.bootstrap.status' bootstrap-handoff.json
# Expected: "not_yet_installed" (CSA will proceed with Phases 1-7)
```

### Check All Required Fields

```bash
jq '.schema_version, .machine.hostname, .bootstrap.ssh_user, .bootstrap.marker_path' \
   bootstrap-handoff.json
# Expected: "2.0", "optiplex-frigate", "ubuntu", "/var/lib/acephalous-assembler/bootstrap-complete"
```

### Full Schema Validation

```bash
jq . bootstrap-handoff.json
# Should return valid JSON with all required fields
```

---

## CSA Regression Tests

After capturing handoff, run CSA's parser regression tests:

```bash
./scripts/test-handoff-parser.sh
```

**Expected output**:

```
Passed: 16
Failed: 0
✓ All tests passed
```

This validates CSA's parser handles static IP, DHCP/null fallback, SSH credentials, and marker paths correctly.

---

## IP Resolution Examples

CSA parser applies this resolution logic:

### Example 1: Static IP

**Handoff**:

```json
{
  "machine": {
    "hostname": "optiplex-frigate",
    "network": {
      "ip_address": "192.168.1.20"
    }
  }
}
```

**CSA parsing**:

```bash
./scripts/validate-network-connectivity.sh --print-config <handoff>
# Output: Target: 192.168.1.20 (from machine.network.ip_address)
```

### Example 2: DHCP/Null IP

**Handoff**:

```json
{
  "machine": {
    "hostname": "optiplex-frigate-dhcp",
    "network": {
      "ip_address": null
    }
  }
}
```

**CSA parsing**:

```bash
./scripts/validate-network-connectivity.sh --print-config <handoff>
# Output: Target: optiplex-frigate-dhcp (from machine.hostname)
```

---

## Troubleshooting

### Issue: "Handoff not found" / "Connection refused"

**Check SSH connectivity**:

```bash
ssh -v ubuntu@192.168.1.20 true
```

**List handoff directory**:

```bash
ssh ubuntu@192.168.1.20 "ls -la /var/lib/acephalous-assembler/"
```

**Read handoff directly**:

```bash
ssh ubuntu@192.168.1.20 "cat /var/lib/acephalous-assembler/bootstrap-handoff.json"
```

### Issue: "JSON parse error"

**Verify JSON syntax**:

```bash
jq . bootstrap-handoff.json
```

**Check file encoding**:

```bash
file bootstrap-handoff.json
# Should output: ASCII text or UTF-8
```

### Issue: "CSA validation failed"

**Run validation with debug output**:

```bash
./scripts/validate-network-connectivity.sh --print-config bootstrap-handoff.json
```

**Check for required fields**:

```bash
jq 'keys' bootstrap-handoff.json
# Should include: schema_version, build, machine, bootstrap, verification
```

**Run parser tests**:

```bash
./scripts/test-handoff-parser.sh
```

---

## Next Steps

Once handoff is validated:

1. **Review handoff**:

   ```bash
   jq . bootstrap-handoff.json
   ```

2. **Execute Phase 1** (Inventory & Assumptions):

   ```bash
   cat docs/01-inventory-assumptions.md
   ```

3. **Proceed with Phases 2-7** (manual runbooks):
   - Phase 2: HA OS Onboarding
   - Phase 3: OptiPlex Linux + Docker
   - Phase 4: MQTT Setup
   - Phase 5: Frigate Compose
   - Phase 6: HA Integration
   - Phase 7: Smoke Tests

---

## AA v2.0 Schema Reference

See [examples/bootstrap-handoff.example.json](../examples/bootstrap-handoff.example.json) for complete schema.

**Key Fields**:

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `schema_version` | string | ✓ | Must be "2.0" |
| `build.variant` | string | ✓ | ubuntu, debian, or haos |
| `build.status` | string | ✓ | media_and_flash_complete |
| `machine.hostname` | string | ✓ | System hostname |
| `machine.os_family` | string | ✓ | debian, rhel, etc. |
| `machine.network.ip_address` | string or null | ✓ | Static IP or null for DHCP |
| `bootstrap.ssh_user` | string | ✓ | ubuntu, debian, or root |
| `bootstrap.ssh_port` | number | ✓ | 22 (standard) |
| `bootstrap.marker_path` | string | ✓ | AA bootstrap marker location |
| `bootstrap.marker_supported` | boolean | ✓ | Whether marker is available |
| `verification.ssh_verified` | boolean | ✓ | false (pre-validation) |
| `verification.first_boot_observed` | boolean | ✓ | false (pre-validation) |

---

## For AA Integration Team

To ensure CSA compatibility, AA should:

1. ✓ Use schema_version = "2.0"
2. ✓ Set build.variant to "ubuntu", "debian", or "haos"
3. ✓ Set build.status = "media_and_flash_complete"
4. ✓ Include machine.network.ip_address (static IP or null)
5. ✓ Use bootstrap.marker_path = "/var/lib/acephalous-assembler/bootstrap-complete"
6. ✓ Set bootstrap.status = "not_yet_installed"
7. ✓ Set all verification.* fields to false (initial state)
8. ✓ Write handoff to /var/lib/acephalous-assembler/bootstrap-handoff.json or provide SCP access

---

**Status**: Coordinated-pilot-ready  
**Last Updated**: April 23, 2026  
**Schema Version**: 2.0
