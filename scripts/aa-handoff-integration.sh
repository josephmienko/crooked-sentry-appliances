#!/bin/bash

# AA v2.0 → CSA v2.0 Handoff Integration Commands
#
# This file documents how to capture and validate bootstrap handoff from acephalous-assembler (AA).
#
# Workflow:
#   1. AA completes OS bootstrap
#   2. AA generates bootstrap-handoff.json in canonical v2.0 format
#   3. CSA reads handoff and validates machine readiness
#   4. CSA proceeds with Phases 1-7
#
# See: examples/bootstrap-handoff.example.json for schema reference

# ============================================================================
# OPTION 1: AA Emits Handoff to Standard Location (Recommended)
# ============================================================================
#
# AA bootstrap process writes final handoff to:
#   /var/lib/acephalous-assembler/bootstrap-handoff.json
#
# CSA validates from that location:

HANDOFF_PATH="/var/lib/acephalous-assembler/bootstrap-handoff.json"

# On CSA coordinator machine (after AA bootstrap):
./scripts/validate-network-connectivity.sh --print-config "$HANDOFF_PATH"

# If validation passes:
#   • Target: [IP or hostname] ✓
#   • SSH user: ubuntu ✓
#   • SSH port: 22 ✓
#   • Bootstrap marker: /var/lib/acephalous-assembler/bootstrap-complete ✓
#   Proceed to Phase 1

# ============================================================================
# OPTION 2: Retrieve Handoff via SCP from Bootstrapped Machine
# ============================================================================
#
# AA writes handoff to machine; coordinator pulls it:

# Variables (customize for your environment)
BOOTSTRAP_HOST="192.168.1.20"        # IP or hostname of bootstrapped machine
BOOTSTRAP_USER="ubuntu"              # SSH user from handoff (or infer from AA)
BOOTSTRAP_KEY="~/.ssh/id_ed25519"    # SSH private key

REMOTE_HANDOFF="/var/lib/acephalous-assembler/bootstrap-handoff.json"
LOCAL_HANDOFF="./bootstrap-handoff-live.json"

# Retrieve handoff from bootstrapped machine
scp -i "$BOOTSTRAP_KEY" \
    "$BOOTSTRAP_USER@$BOOTSTRAP_HOST:$REMOTE_HANDOFF" \
    "$LOCAL_HANDOFF"

# Validate retrieved handoff
./scripts/validate-network-connectivity.sh --print-config "$LOCAL_HANDOFF"

# ============================================================================
# OPTION 3: Direct SSH Command to Extract Handoff
# ============================================================================
#
# In case SCP is unavailable, use SSH with output redirection:

ssh -i "$BOOTSTRAP_KEY" \
    "$BOOTSTRAP_USER@$BOOTSTRAP_HOST" \
    "cat $REMOTE_HANDOFF" > "$LOCAL_HANDOFF"

./scripts/validate-network-connectivity.sh --print-config "$LOCAL_HANDOFF"

# ============================================================================
# OPTION 4: Validate AA v2.0 Schema Format (Before Integration)
# ============================================================================
#
# Verify AA's generated handoff matches expected schema:

# Check required fields exist
jq '.schema_version, .machine.hostname, .bootstrap.ssh_user, .bootstrap.marker_path' \
   "$LOCAL_HANDOFF"

# Expected output:
#   "2.0"
#   "optiplex-frigate"
#   "ubuntu"
#   "/var/lib/acephalous-assembler/bootstrap-complete"

# Verify schema_version is 2.0
jq -e '.schema_version == "2.0"' "$LOCAL_HANDOFF" && echo "✓ Schema v2.0" || echo "✗ Wrong schema"

# Verify build status is media_and_flash_complete
jq -e '.build.status == "media_and_flash_complete"' "$LOCAL_HANDOFF" && echo "✓ Build complete" || echo "✗ Build incomplete"

# Verify bootstrap.status is not_yet_installed (CSA will proceed)
jq -e '.bootstrap.status == "not_yet_installed"' "$LOCAL_HANDOFF" && echo "✓ CSA ready" || echo "✗ CSA not ready"

# ============================================================================
# OPTION 5: Run Full Parser Regression Tests
# ============================================================================
#
# Ensure CSA parser handles the exact handoff correctly:

./scripts/test-handoff-parser.sh

# Expected: 16 tests passed, 0 failed
# This validates parser logic against static IP, DHCP, SSH user/port, markers

# ============================================================================
# OPTION 6: Continuous Monitoring (Watch for Handoff)
# ============================================================================
#
# If AA produces handoff asynchronously, wait and validate:

HANDOFF_PATH="/var/lib/acephalous-assembler/bootstrap-handoff.json"
TIMEOUT=300  # 5 minutes

# Wait for handoff to appear
for i in $(seq 1 $TIMEOUT); do
  if [[ -f "$HANDOFF_PATH" ]]; then
    echo "✓ Handoff found at $(date)"
    jq . "$HANDOFF_PATH" > /dev/null 2>&1 && {
      echo "✓ Valid JSON"
      ./scripts/validate-network-connectivity.sh --print-config "$HANDOFF_PATH"
      break
    } || {
      echo "✗ JSON parse error, retrying..."
      sleep 5
    }
  else
    if [[ $((i % 30)) -eq 0 ]]; then
      echo "Waiting for handoff... ($i / $TIMEOUT seconds)"
    fi
    sleep 1
  fi
done

# ============================================================================
# OPTION 7: Handoff Capture with Validation Loop
# ============================================================================
#
# Comprehensive capture + validate with retry logic:

#!/bin/bash
set -uo pipefail

BOOTSTRAP_HOST="${1:-192.168.1.20}"
BOOTSTRAP_USER="${2:-ubuntu}"
BOOTSTRAP_KEY="${3:-~/.ssh/id_ed25519}"
LOCAL_HANDOFF="bootstrap-handoff-live.json"
MAX_ATTEMPTS=10
ATTEMPT=0

echo "Capturing handoff from $BOOTSTRAP_USER@$BOOTSTRAP_HOST..."

while [[ $ATTEMPT -lt $MAX_ATTEMPTS ]]; do
  ATTEMPT=$((ATTEMPT + 1))
  echo "Attempt $ATTEMPT/$MAX_ATTEMPTS..."
  
  if scp -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
      -i "$BOOTSTRAP_KEY" \
      "$BOOTSTRAP_USER@$BOOTSTRAP_HOST:/var/lib/acephalous-assembler/bootstrap-handoff.json" \
      "$LOCAL_HANDOFF" 2>/dev/null; then
    
    echo "✓ Handoff retrieved"
    
    # Validate JSON
    if jq . "$LOCAL_HANDOFF" > /dev/null 2>&1; then
      echo "✓ Valid JSON"
      
      # Run CSA validation
      if ./scripts/validate-network-connectivity.sh --print-config "$LOCAL_HANDOFF"; then
        echo ""
        echo "✓ Handoff validated successfully"
        echo "✓ Ready for Phase 1"
        exit 0
      else
        echo "✗ CSA validation failed"
        exit 1
      fi
    else
      echo "✗ JSON invalid, retrying..."
    fi
  else
    if [[ $ATTEMPT -lt $MAX_ATTEMPTS ]]; then
      echo "Not yet available, retrying in 5 seconds..."
      sleep 5
    fi
  fi
done

echo "✗ Failed to retrieve/validate handoff after $MAX_ATTEMPTS attempts"
exit 1

# ============================================================================
# OPTION 8: Parallel Handoff Collection (Multi-Machine Deployment)
# ============================================================================
#
# If deploying to multiple machines simultaneously, collect all handoffs:

MACHINES=(
  "192.168.1.20:ubuntu:~/.ssh/id_ed25519"
  "192.168.1.21:ubuntu:~/.ssh/id_ed25519"
  "192.168.1.22:ubuntu:~/.ssh/id_ed25519"
)

for machine in "${MACHINES[@]}"; do
  IFS=: read -r host user key <<< "$machine"
  local_file="bootstrap-handoff-${host}.json"
  
  echo "Collecting from $host..."
  scp -i "$key" "$user@$host:/var/lib/acephalous-assembler/bootstrap-handoff.json" "$local_file" &
done

wait

# Validate all collected handoffs
for handoff in bootstrap-handoff-*.json; do
  echo "Validating $handoff..."
  ./scripts/validate-network-connectivity.sh --print-config "$handoff"
  echo ""
done

# ============================================================================
# AA V2.0 SCHEMA REFERENCE
# ============================================================================
#
# CSA expects AA to emit:
#
# {
#   "schema_version": "2.0",
#   "build": {
#     "variant": "ubuntu|debian|haos",
#     "status": "media_and_flash_complete",
#     "timestamp": "ISO8601"
#   },
#   "machine": {
#     "hostname": "hostname",
#     "os_family": "debian|rhel|...",
#     "os_version": "22.04|12|8|...",
#     "arch": "x86_64|aarch64|...",
#     "network": {
#       "mode": "static|dhcp",
#       "ip_address": "192.168.1.20|null",
#       "hostname_fqdn": "hostname.local"
#     }
#   },
#   "bootstrap": {
#     "ssh_user": "ubuntu|debian|root",
#     "ssh_port": 22,
#     "ssh_key_path": "/path/to/authorized_keys",
#     "status": "not_yet_installed",
#     "marker_supported": true|false,
#     "marker_path": "/var/lib/acephalous-assembler/bootstrap-complete"
#   },
#   "verification": {
#     "ssh_verified": false,
#     "first_boot_observed": false,
#     "network_accessible": false,
#     "ntp_synchronized": false
#   }
# }
#
# Field Notes:
#   - schema_version: Must be "2.0"
#   - build.status: AA reached end of bootstrap ("media_and_flash_complete")
#   - bootstrap.status: "not_yet_installed" indicates CSA is next agent
#   - machine.network.ip_address: null or empty string triggers hostname fallback
#   - bootstrap.marker_path: AA's bootstrap marker location
#   - verification.*: Initial state (CSA validates all during Phase 1)

# ============================================================================
# TROUBLESHOOTING
# ============================================================================
#
# Problem: "Handoff not found" / "Connection refused"
# Solution:
#   - Verify AA bootstrap completed successfully
#   - Check SSH connectivity: ssh -v "$BOOTSTRAP_USER@$BOOTSTRAP_HOST" true
#   - Verify handoff path: ssh ... "ls -l /var/lib/acephalous-assembler/"
#   - Check permissions: ssh ... "cat /var/lib/acephalous-assembler/bootstrap-handoff.json"
#
# Problem: "JSON parse error"
# Solution:
#   - Verify handoff is valid JSON: jq . bootstrap-handoff.json
#   - Check for encoding issues: file bootstrap-handoff.json
#   - Verify AA emitted schema v2.0: jq '.schema_version' bootstrap-handoff.json
#
# Problem: "CSA validation failed"
# Solution:
#   - Run: ./scripts/validate-network-connectivity.sh --print-config bootstrap-handoff.json
#   - Check --print-config output for parsing issues
#   - Verify all required fields present: jq 'keys' bootstrap-handoff.json
#   - Run parser tests: ./scripts/test-handoff-parser.sh
#
# Problem: "SSH connectivity timeout"
# Solution:
#   - Increase SSH timeout: ssh -o ConnectTimeout=30
#   - Check network reachability: ping $BOOTSTRAP_HOST
#   - Verify firewall: ssh ... "sudo ufw status"
#   - Check SSH service: ssh ... "sudo systemctl status ssh"

# ============================================================================
# NEXT: Phase 1 Execution
# ============================================================================
#
# After handoff validation:
#   1. Review handoff: jq . bootstrap-handoff.json
#   2. Execute Phase 1: ./docs/01-inventory-assumptions.md
#   3. Document results
#   4. Proceed to Phase 2
#
# See: ./docs/01-inventory-assumptions.md (Phase 1 runbook)
