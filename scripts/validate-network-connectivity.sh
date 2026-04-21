#!/bin/bash

# Crooked Sentry Network Connectivity Validator
# 
# This script performs comprehensive network checks to ensure all appliances
# and services are reachable and operational.
#
# Usage:
#   ./scripts/validate-network-connectivity.sh
#
# Configuration:
#   Source examples/network-config.example.env before running, or set environment variables:
#   - HA_RPI_IP (default: 192.168.1.10)
#   - OPTIPLEX_IP (default: 192.168.1.20)
#   - FRIGATE_API_PORT (default: 5000)
#   - MQTT_HOST (default: 192.168.1.10)
#   - MQTT_PORT (default: 1883)

set -euo pipefail

# Colors for output
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
NC="\033[0m"  # No Color

# Configuration defaults (override via environment or .env file)
HA_RPI_IP="${HA_RPI_IP:-192.168.1.10}"
OPTIPLEX_IP="${OPTIPLEX_IP:-192.168.1.20}"
FRIGATE_API_PORT="${FRIGATE_API_PORT:-5000}"
MQTT_HOST="${MQTT_HOST:-192.168.1.10}"
MQTT_PORT="${MQTT_PORT:-1883}"
SSH_TIMEOUT=5

# Test counter
PASS=0
FAIL=0

# Functions
pass_test() {
  echo -e "${GREEN}✓${NC} $1"
  ((PASS++))
}

fail_test() {
  echo -e "${RED}✗${NC} $1"
  ((FAIL++))
}

warn_test() {
  echo -e "${YELLOW}⚠${NC} $1"
}

run_test() {
  local test_name="$1"
  local command="$2"
  
  if eval "$command" > /dev/null 2>&1; then
    pass_test "$test_name"
  else
    fail_test "$test_name"
  fi
}

# Header
echo "=========================================="
echo "Crooked Sentry Network Validation"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  HA RPI IP: $HA_RPI_IP"
echo "  OptiPlex IP: $OPTIPLEX_IP"
echo "  Frigate API: http://$OPTIPLEX_IP:$FRIGATE_API_PORT"
echo "  MQTT: $MQTT_HOST:$MQTT_PORT"
echo ""
echo "Running tests..."
echo ""

# Test 1: Raspberry Pi Reachability
echo "--- Appliance Reachability ---"
run_test "Ping Raspberry Pi ($HA_RPI_IP)" "ping -c 1 -W 2 $HA_RPI_IP"
run_test "Ping OptiPlex ($OPTIPLEX_IP)" "ping -c 1 -W 2 $OPTIPLEX_IP"
echo ""

# Test 2: SSH Connectivity
echo "--- SSH Connectivity ---"
run_test "SSH to HA (port 22)" "timeout $SSH_TIMEOUT ssh -o ConnectTimeout=$SSH_TIMEOUT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$HA_RPI_IP 'echo OK' 2>/dev/null || ssh -o ConnectTimeout=$SSH_TIMEOUT root@$HA_RPI_IP 'echo OK' 2>/dev/null"
run_test "SSH to OptiPlex (port 22)" "timeout $SSH_TIMEOUT ssh -o ConnectTimeout=$SSH_TIMEOUT -o StrictHostKeyChecking=no root@$OPTIPLEX_IP 'docker ps' 2>/dev/null || timeout $SSH_TIMEOUT ssh root@$OPTIPLEX_IP 'docker ps' 2>/dev/null"
echo ""

# Test 3: Service Accessibility
echo "--- Service Accessibility ---"
run_test "HA Web UI (http://$HA_RPI_IP:8123)" "curl -s -f http://$HA_RPI_IP:8123 > /dev/null"
run_test "Frigate API (http://$OPTIPLEX_IP:$FRIGATE_API_PORT)" "curl -s -f http://$OPTIPLEX_IP:$FRIGATE_API_PORT/api/version > /dev/null"
echo ""

# Test 4: MQTT Connectivity
echo "--- MQTT Broker ---"
if command -v nc &> /dev/null; then
  run_test "MQTT Port Reachable ($MQTT_HOST:$MQTT_PORT)" "nc -z -w 2 $MQTT_HOST $MQTT_PORT"
elif command -v nmap &> /dev/null; then
  run_test "MQTT Port Reachable ($MQTT_HOST:$MQTT_PORT)" "nmap -p $MQTT_PORT --open $MQTT_HOST 2>/dev/null | grep -q open"
else
  warn_test "MQTT port check skipped (nc/nmap not installed)"
fi
echo ""

# Test 5: Host Name Resolution
echo "--- DNS/Hostname Resolution ---"
if command -v nslookup &> /dev/null; then
  run_test "Resolve ha-rpi.local" "nslookup ha-rpi.local > /dev/null 2>&1 || true"
  run_test "Resolve optiplex-frigate.local" "nslookup optiplex-frigate.local > /dev/null 2>&1 || true"
elif command -v getent &> /dev/null; then
  run_test "Resolve ha-rpi.local" "getent hosts ha-rpi.local > /dev/null 2>&1 || true"
  run_test "Resolve optiplex-frigate.local" "getent hosts optiplex-frigate.local > /dev/null 2>&1 || true"
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
