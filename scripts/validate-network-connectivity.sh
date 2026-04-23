#!/bin/bash

# Crooked Sentry Network Connectivity Validator
# 
# READ-ONLY validation script. Checks that appliances are reachable and services are accessible.
# Does not modify any system state.
#
# Usage:
#   ./scripts/validate-network-connectivity.sh [--print-config] [path/to/handoff.json]
#   ./scripts/validate-network-connectivity.sh --help
#
# Configuration via environment variables (or from bootstrap handoff JSON):
#   - APPLIANCE_IP (default: from handoff or 192.168.1.20)
#   - APPLIANCE_SSH_USER (default: ubuntu)
#   - APPLIANCE_SSH_PORT (default: 22)
#   - FRIGATE_API_PORT (default: 5000)
#   - FRIGATE_API_HOST (default: from APPLIANCE_IP)
#   - MQTT_HOST (default: from APPLIANCE_IP)
#   - MQTT_PORT (default: 1883)
#   - CURL_TIMEOUT (default: 10 seconds)
#   - SSH_TIMEOUT (default: 5 seconds)
#   - PING_TIMEOUT (default: 2 seconds)
#
# Options:
#   --print-config    Show parsed configuration and exit (no tests run)
#   --help            Show this help message

set -uo pipefail

# Colors for output
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
NC="\033[0m"  # No Color

# Configuration defaults
APPLIANCE_IP="${APPLIANCE_IP:-192.168.1.20}"
APPLIANCE_SSH_USER="${APPLIANCE_SSH_USER:-ubuntu}"
APPLIANCE_SSH_PORT="${APPLIANCE_SSH_PORT:-22}"
FRIGATE_API_PORT="${FRIGATE_API_PORT:-5000}"
FRIGATE_API_HOST="${FRIGATE_API_HOST:-$APPLIANCE_IP}"
MQTT_HOST="${MQTT_HOST:-$APPLIANCE_IP}"
MQTT_PORT="${MQTT_PORT:-1883}"
CURL_TIMEOUT="${CURL_TIMEOUT:-10}"
SSH_TIMEOUT="${SSH_TIMEOUT:-5}"
PING_TIMEOUT="${PING_TIMEOUT:-2}"

# Parse command-line options
HANDOFF_FILE=""
PRINT_CONFIG=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --print-config)
      PRINT_CONFIG=true
      shift
      ;;
    --help)
      grep "^#" "$0" | grep -v "^#!/" | sed 's/^# *//'
      exit 0
      ;;
    *)
      if [[ -f "$1" ]]; then
        HANDOFF_FILE="$1"
      fi
      shift
      ;;
  esac
done

# Load from bootstrap handoff JSON if provided (AA v2.0 schema)
HANDOFF_SOURCE=""
BOOTSTRAP_MARKER_PATH=""
BOOTSTRAP_MARKER_SUPPORTED=false
TARGET_SOURCE=""  # Track whether target came from IP, hostname, or default
if [[ -n "$HANDOFF_FILE" ]] && [[ -f "$HANDOFF_FILE" ]]; then
  if command -v jq &> /dev/null; then
    # AA v2.0 schema parsing
    MACHINE_IP=$(jq -r '.machine.network.ip_address // empty' "$HANDOFF_FILE")
    MACHINE_HOSTNAME=$(jq -r '.machine.hostname // empty' "$HANDOFF_FILE")
    
    # Resolve target: IP if non-empty, else hostname, else configured default
    if [[ -n "$MACHINE_IP" ]] && [[ "$MACHINE_IP" != "null" ]]; then
      APPLIANCE_IP="$MACHINE_IP"
      TARGET_SOURCE="(from machine.network.ip_address)"
    elif [[ -n "$MACHINE_HOSTNAME" ]] && [[ "$MACHINE_HOSTNAME" != "null" ]]; then
      APPLIANCE_IP="$MACHINE_HOSTNAME"
      TARGET_SOURCE="(from machine.hostname)"
    else
      TARGET_SOURCE="(default)"
    fi
    
    APPLIANCE_SSH_USER=$(jq -r '.bootstrap.ssh_user // "'"$APPLIANCE_SSH_USER"'"' "$HANDOFF_FILE")
    APPLIANCE_SSH_PORT=$(jq -r '.bootstrap.ssh_port // "'"$APPLIANCE_SSH_PORT"'"' "$HANDOFF_FILE")
    BOOTSTRAP_MARKER_PATH=$(jq -r '.bootstrap.marker_path // empty' "$HANDOFF_FILE")
    BOOTSTRAP_MARKER_SUPPORTED=$(jq -r '.bootstrap.marker_supported // false' "$HANDOFF_FILE")
    
    # Apply same target resolution to FRIGATE_API_HOST and MQTT_HOST (unless env vars override)
    if [[ "${FRIGATE_API_HOST:-}" == "192.168.1.20" ]]; then
      FRIGATE_API_HOST="$APPLIANCE_IP"
    fi
    if [[ "${MQTT_HOST:-}" == "192.168.1.20" ]]; then
      MQTT_HOST="$APPLIANCE_IP"
    fi
    
    HANDOFF_SOURCE=" (from AA v2.0 handoff)"
  else
    echo -e "${YELLOW}⚠${NC} jq not found; skipping bootstrap handoff JSON parsing"
  fi
fi

# If --print-config was specified, show configuration and exit
if [[ "$PRINT_CONFIG" == "true" ]]; then
  echo "=========================================="
  echo "Configuration (AA v2.0 Handoff Parser)"
  echo "=========================================="
  echo "Appliance$HANDOFF_SOURCE:"
  echo "  Target: $APPLIANCE_IP $TARGET_SOURCE"
  echo "  SSH user: $APPLIANCE_SSH_USER"
  echo "  SSH port: $APPLIANCE_SSH_PORT"
  if [[ -n "$BOOTSTRAP_MARKER_PATH" ]]; then
    echo "  Bootstrap marker: $BOOTSTRAP_MARKER_PATH (supported: $BOOTSTRAP_MARKER_SUPPORTED)"
  fi
  echo ""
  echo "Frigate API:"
  echo "  http://$FRIGATE_API_HOST:$FRIGATE_API_PORT"
  echo ""
  echo "MQTT:"
  echo "  $MQTT_HOST:$MQTT_PORT"
  echo ""
  echo "Timeouts:"
  echo "  curl: ${CURL_TIMEOUT}s"
  echo "  ssh: ${SSH_TIMEOUT}s"
  echo "  ping: ${PING_TIMEOUT}s"
  echo "=========================================="
  exit 0
fi

# Test counter - use explicit counting to avoid arithmetic errors with set -e
PASS=0
FAIL=0

# Functions
pass_test() {
  echo -e "${GREEN}✓${NC} $1"
  PASS=$((PASS + 1))
}

fail_test() {
  echo -e "${RED}✗${NC} $1"
  FAIL=$((FAIL + 1))
}

warn_test() {
  echo -e "${YELLOW}⚠${NC} $1"
}

run_test() {
  local test_name="$1"
  local command="$2"
  
  if eval "$command" > /dev/null 2>&1; then
    pass_test "$test_name"
    return 0
  else
    fail_test "$test_name"
    return 0  # Don't exit on test failure
  fi
}

# Header
echo "=========================================="
echo "Crooked Sentry Network Validation"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  Appliance: $APPLIANCE_IP (user: $APPLIANCE_SSH_USER, port: $APPLIANCE_SSH_PORT)"
echo "  Frigate API: http://$FRIGATE_API_HOST:$FRIGATE_API_PORT"
echo "  MQTT: $MQTT_HOST:$MQTT_PORT"
echo ""
echo "Running tests (read-only validation, no system changes)..."
echo ""

# Helper: cross-platform timeout (fallback for macOS)
timeout_cmd() {
  if command -v timeout &> /dev/null; then
    timeout "$@"
  else
    # macOS fallback: use perl for timeout
    perl -e 'alarm shift; exec @ARGV' "$@"
  fi
}

# Test 1: Appliance Reachability
echo "--- Appliance Reachability ---"
# Use -c 1 for Linux/macOS, -W 2 for timeout
if [[ "$OSTYPE" == "darwin"* ]]; then
  run_test "Ping appliance ($APPLIANCE_IP)" "timeout_cmd $PING_TIMEOUT ping -c 1 $APPLIANCE_IP"
else
  run_test "Ping appliance ($APPLIANCE_IP)" "ping -c 1 -W $PING_TIMEOUT $APPLIANCE_IP"
fi
echo ""

# Test 2: SSH Connectivity (with explicit timeout)
echo "--- SSH Connectivity ---"
run_test "SSH to appliance ($APPLIANCE_SSH_USER@$APPLIANCE_IP:$APPLIANCE_SSH_PORT)" "timeout_cmd $SSH_TIMEOUT ssh -o ConnectTimeout=$SSH_TIMEOUT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p $APPLIANCE_SSH_PORT $APPLIANCE_SSH_USER@$APPLIANCE_IP 'true' 2>/dev/null"
echo ""

# Test 2b: Bootstrap Marker Check (if marker supported and SSH is accessible)
if [[ -n "$BOOTSTRAP_MARKER_PATH" ]] && [[ "$BOOTSTRAP_MARKER_SUPPORTED" == "true" ]]; then
  echo "--- Bootstrap Marker Verification ---"
  if timeout_cmd $SSH_TIMEOUT ssh -o ConnectTimeout=$SSH_TIMEOUT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p $APPLIANCE_SSH_PORT $APPLIANCE_SSH_USER@$APPLIANCE_IP "test -f $BOOTSTRAP_MARKER_PATH" 2>/dev/null; then
    pass_test "Bootstrap marker found ($BOOTSTRAP_MARKER_PATH)"
  else
    fail_test "Bootstrap marker missing ($BOOTSTRAP_MARKER_PATH) - bootstrap may not have completed"
  fi
  echo ""
elif [[ -n "$BOOTSTRAP_MARKER_PATH" ]] && [[ "$BOOTSTRAP_MARKER_SUPPORTED" == "false" ]]; then
  echo "--- Bootstrap Marker Verification ---"
  warn_test "Bootstrap marker not supported on this system (path: $BOOTSTRAP_MARKER_PATH)"
  echo ""
fi

# Test 3: Service Accessibility (with explicit curl timeout)
echo "--- Service Accessibility ---"
run_test "Frigate API (http://$FRIGATE_API_HOST:$FRIGATE_API_PORT/api/version)" "timeout_cmd $CURL_TIMEOUT curl --max-time $CURL_TIMEOUT -s -f http://$FRIGATE_API_HOST:$FRIGATE_API_PORT/api/version > /dev/null"
echo ""

# Test 4: MQTT Connectivity
echo "--- MQTT Broker ---"
if command -v nc &> /dev/null; then
  run_test "MQTT Port Reachable ($MQTT_HOST:$MQTT_PORT)" "timeout_cmd 3 nc -z -w 2 $MQTT_HOST $MQTT_PORT"
elif command -v nmap &> /dev/null; then
  run_test "MQTT Port Reachable ($MQTT_HOST:$MQTT_PORT)" "timeout_cmd 3 nmap -p $MQTT_PORT --open $MQTT_HOST 2>/dev/null | grep -q open"
else
  warn_test "MQTT port check skipped (nc/nmap not installed)"
fi
echo ""

# Test 5: Host Name Resolution
echo "--- Hostname Resolution (Informational) ---"
# NOTE: mDNS resolution (.local domains) may not work on all networks
if command -v nslookup &> /dev/null; then
  if timeout_cmd 3 nslookup "$APPLIANCE_IP" > /dev/null 2>&1; then
    pass_test "Reverse DNS lookup successful"
  else
    warn_test "Reverse DNS lookup unavailable (not required)"
  fi
elif command -v getent &> /dev/null; then
  if timeout_cmd 3 getent hosts "$APPLIANCE_IP" > /dev/null 2>&1; then
    pass_test "Reverse DNS lookup successful"
  else
    warn_test "Reverse DNS lookup unavailable (not required)"
  fi
else
  warn_test "DNS resolution checks skipped (nslookup/getent not installed)"
fi
echo ""

# Summary
echo "=========================================="
echo "Results:"
echo -e "  ${GREEN}Passed: $PASS${NC}"
echo -e "  ${RED}Failed: $FAIL${NC}"
echo "=========================================="

if [ $FAIL -gt 0 ]; then
  echo ""
  echo "Troubleshooting tips:"
  echo "  1. Verify both appliances are powered on and connected"
  echo "  2. Check router/firewall allows required ports"
  echo "  3. Confirm SSH access and credentials"
  echo "  4. Review network configuration in examples/network-config.example.env"
  echo ""
  exit 1
else
  echo ""
  echo -e "${GREEN}All tests passed! Your appliances are healthy.${NC}"
  echo ""
  exit 0
fi
