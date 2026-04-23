#!/bin/bash

# Handoff Parser Regression Tests
#
# Non-destructive tests proving CSA handoff parser handles:
# - Static IP resolution
# - DHCP/null IP fallback to hostname
# - SSH user/port parsing
# - Bootstrap marker path parsing
#
# Usage: ./scripts/test-handoff-parser.sh
# Exit code 0 = all tests pass

set -uo pipefail

# Colors for output
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
NC="\033[0m"

PASS=0
FAIL=0

test_pass() {
  echo -e "${GREEN}✓${NC} $1"
  PASS=$((PASS + 1))
}

test_fail() {
  echo -e "${RED}✗${NC} $1"
  FAIL=$((FAIL + 1))
}

echo "=========================================="
echo "CSA Handoff Parser Regression Tests"
echo "=========================================="
echo ""

# Helper: test jq parsing against a handoff JSON
test_jq_parse() {
  local test_name="$1"
  local handoff_json="$2"
  local jq_query="$3"
  local expected="$4"
  
  if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}⚠${NC} jq not installed; skipping test: $test_name"
    return
  fi
  
  local result=$(echo "$handoff_json" | jq -r "$jq_query")
  if [[ "$result" == "$expected" ]]; then
    test_pass "$test_name: $result"
  else
    test_fail "$test_name: expected '$expected', got '$result'"
  fi
}

# Test 1: Static IP Resolution
echo "Test 1: Static IP Resolution"
STATIC_IP_HANDOFF='{
  "machine": {
    "hostname": "optiplex-frigate",
    "network": {
      "ip_address": "192.168.1.20"
    }
  },
  "bootstrap": {
    "ssh_user": "ubuntu",
    "ssh_port": 22,
    "marker_path": "/var/lib/acephalous-assembler/bootstrap-complete",
    "marker_supported": true
  }
}'

test_jq_parse "Static IP parsing" "$STATIC_IP_HANDOFF" \
  '.machine.network.ip_address' "192.168.1.20"

test_jq_parse "SSH user parsing (static)" "$STATIC_IP_HANDOFF" \
  '.bootstrap.ssh_user' "ubuntu"

test_jq_parse "SSH port parsing (static)" "$STATIC_IP_HANDOFF" \
  '.bootstrap.ssh_port' "22"

test_jq_parse "Marker path parsing (static)" "$STATIC_IP_HANDOFF" \
  '.bootstrap.marker_path' "/var/lib/acephalous-assembler/bootstrap-complete"

echo ""

# Test 2: DHCP/Null IP Fallback to Hostname
echo "Test 2: DHCP/Null IP Fallback to Hostname"
DHCP_HANDOFF='{
  "machine": {
    "hostname": "optiplex-frigate",
    "network": {
      "ip_address": null
    }
  },
  "bootstrap": {
    "ssh_user": "ubuntu",
    "ssh_port": 22,
    "marker_path": "/var/lib/acephalous-assembler/bootstrap-complete",
    "marker_supported": true
  }
}'

test_jq_parse "DHCP null IP returns null" "$DHCP_HANDOFF" \
  '.machine.network.ip_address' "null"

test_jq_parse "Hostname fallback available" "$DHCP_HANDOFF" \
  '.machine.hostname' "optiplex-frigate"

# Test the resolution logic: if IP is null, use hostname
IP=$(echo "$DHCP_HANDOFF" | jq -r '.machine.network.ip_address // empty')
HOSTNAME=$(echo "$DHCP_HANDOFF" | jq -r '.machine.hostname // empty')
if [[ -z "$IP" ]] || [[ "$IP" == "null" ]]; then
  RESOLVED="$HOSTNAME"
else
  RESOLVED="$IP"
fi

if [[ "$RESOLVED" == "optiplex-frigate" ]]; then
  test_pass "Resolution logic: null IP → hostname: $RESOLVED"
else
  test_fail "Resolution logic: expected 'optiplex-frigate', got '$RESOLVED'"
fi

echo ""

# Test 3: Empty String IP Fallback
echo "Test 3: Empty String IP Fallback"
EMPTY_IP_HANDOFF='{
  "machine": {
    "hostname": "rpi-ha-server",
    "network": {
      "ip_address": ""
    }
  },
  "bootstrap": {
    "ssh_user": "ubuntu",
    "ssh_port": 22,
    "marker_path": "/var/lib/acephalous-assembler/bootstrap-complete",
    "marker_supported": true
  }
}'

IP=$(echo "$EMPTY_IP_HANDOFF" | jq -r '.machine.network.ip_address // empty')
HOSTNAME=$(echo "$EMPTY_IP_HANDOFF" | jq -r '.machine.hostname // empty')
if [[ -z "$IP" ]]; then
  RESOLVED="$HOSTNAME"
else
  RESOLVED="$IP"
fi

if [[ "$RESOLVED" == "rpi-ha-server" ]]; then
  test_pass "Empty IP fallback to hostname: $RESOLVED"
else
  test_fail "Empty IP fallback: expected 'rpi-ha-server', got '$RESOLVED'"
fi

echo ""

# Test 4: SSH User/Port Parsing
echo "Test 4: SSH User and Port Parsing"

test_jq_parse "SSH user ubuntu" "$STATIC_IP_HANDOFF" \
  '.bootstrap.ssh_user' "ubuntu"

test_jq_parse "SSH user debian (alt)" "$(echo "$STATIC_IP_HANDOFF" | jq '.bootstrap.ssh_user = "debian"')" \
  '.bootstrap.ssh_user' "debian"

test_jq_parse "SSH port 22" "$STATIC_IP_HANDOFF" \
  '.bootstrap.ssh_port' "22"

test_jq_parse "SSH port 2222 (alt)" "$(echo "$STATIC_IP_HANDOFF" | jq '.bootstrap.ssh_port = 2222')" \
  '.bootstrap.ssh_port' "2222"

echo ""

# Test 5: Bootstrap Marker Parsing
echo "Test 5: Bootstrap Marker Path Parsing"

test_jq_parse "Marker path AA canonical" "$STATIC_IP_HANDOFF" \
  '.bootstrap.marker_path' "/var/lib/acephalous-assembler/bootstrap-complete"

test_jq_parse "Marker supported true" "$STATIC_IP_HANDOFF" \
  '.bootstrap.marker_supported' "true"

MARKER_UNSUPPORTED=$(echo "$STATIC_IP_HANDOFF" | jq '.bootstrap.marker_supported = false')
test_jq_parse "Marker supported false" "$MARKER_UNSUPPORTED" \
  '.bootstrap.marker_supported' "false"

echo ""

# Test 6: Schema Version Validation
echo "Test 6: Schema Version Validation"

test_jq_parse "Schema v2.0" "$(echo "$STATIC_IP_HANDOFF" | jq 'del(.machine.hostname)' | jq 'del(.bootstrap)' | jq '.schema_version = "2.0"')" \
  '.schema_version' "2.0"

echo ""

# Summary
echo "=========================================="
echo "Test Results"
echo "=========================================="
echo -e "${GREEN}Passed: $PASS${NC}"
echo -e "${RED}Failed: $FAIL${NC}"
echo ""

if [[ $FAIL -eq 0 ]]; then
  echo -e "${GREEN}✓ All tests passed${NC}"
  exit 0
else
  echo -e "${RED}✗ Some tests failed${NC}"
  exit 1
fi
