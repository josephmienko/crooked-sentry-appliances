#!/bin/bash
#
# CSA AA Device Integration Test Suite
# Validates handoff parser and integrator against realistic scenarios
#
# Usage:
#   ./test-aa-integration.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="${SCRIPT_DIR}/../.test/aa-integration"
TEMP_DIR=$(mktemp -d)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
    rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

test_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((PASS_COUNT++))
}

test_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    ((FAIL_COUNT++))
}

###############################################################################
# TEST FIXTURES
###############################################################################

# Scenario 1: Fully verified devices with RTSP endpoints (ideal case)
create_handoff_all_verified() {
    cat > "$TEMP_DIR/handoff-verified.json" << 'EOF'
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
EOF
}

# Scenario 2: Partially verified (reachable, capabilities, but identity unconfirmed)
create_handoff_partial() {
    cat > "$TEMP_DIR/handoff-partial.json" << 'EOF'
{
  "schema_version": "1.0",
  "generated_at": "2026-04-28T15:32:06.256413+00:00",
  "aa_version": "0.4.0",
  "devices": [
    {
      "device_name": "garage",
      "desired_hostname": "garage.local",
      "ip_address": "192.168.0.152",
      "brand": "anke",
      "model": "I51DL",
      "identity": null,
      "capabilities": [
        {
          "protocol": "rtsp",
          "endpoint": "rtsp://192.168.0.152:554/stream",
          "description": "RTSP stream endpoint"
        }
      ],
      "identity_verified": false,
      "verification_message": "Device reachable but identity confirmation pending",
      "firmware_operation": null,
      "hostname_operation": null
    }
  ],
  "handoff_notes": "Device reachable with capabilities but identity not yet confirmed."
}
EOF
}

# Scenario 3: Blocked devices (unreachable, missing capabilities)
create_handoff_blocked() {
    cat > "$TEMP_DIR/handoff-blocked.json" << 'EOF'
{
  "schema_version": "1.0",
  "generated_at": "2026-04-28T15:32:06.256413+00:00",
  "aa_version": "0.4.0",
  "devices": [
    {
      "device_name": "backyard",
      "desired_hostname": "backyard.local",
      "ip_address": "192.168.0.151",
      "brand": "anke",
      "model": "I51DL",
      "identity": null,
      "capabilities": [],
      "identity_verified": false,
      "verification_message": "Device at 192.168.0.151 not reachable",
      "firmware_operation": null,
      "hostname_operation": null
    }
  ],
  "handoff_notes": "Device unreachable."
}
EOF
}

# Scenario 4: Mixed devices
create_handoff_mixed() {
    cat > "$TEMP_DIR/handoff-mixed.json" << 'EOF'
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
      "identity": {"serial": "ABC123"},
      "capabilities": [
        {"protocol": "rtsp", "endpoint": "rtsp://192.168.0.150:554/stream", "description": "RTSP"}
      ],
      "identity_verified": true,
      "verification_message": "Device verified",
      "firmware_operation": {"status": "success", "version": "2.0.1"},
      "hostname_operation": {"status": "success", "hostname": "front-door.local"}
    },
    {
      "device_name": "garage",
      "desired_hostname": "garage.local",
      "ip_address": "192.168.0.152",
      "brand": "anke",
      "model": "I51DL",
      "identity": null,
      "capabilities": [
        {"protocol": "rtsp", "endpoint": "rtsp://192.168.0.152:554/stream", "description": "RTSP"}
      ],
      "identity_verified": false,
      "verification_message": "Reachable but unverified",
      "firmware_operation": null,
      "hostname_operation": null
    },
    {
      "device_name": "backyard",
      "desired_hostname": "backyard.local",
      "ip_address": "192.168.0.151",
      "brand": "anke",
      "model": "I51DL",
      "identity": null,
      "capabilities": [],
      "identity_verified": false,
      "verification_message": "Device not reachable",
      "firmware_operation": null,
      "hostname_operation": null
    }
  ],
  "handoff_notes": "Mixed device states."
}
EOF
}

###############################################################################
# TESTS
###############################################################################

test_parser_validates_schema() {
    echo ""
    echo "TEST: Parser validates AA schema"
    
    create_handoff_all_verified
    
    bash "$SCRIPT_DIR/aa-handoff-parser.sh" "$TEMP_DIR/handoff-verified.json" > "$TEMP_DIR/parser-output.txt" 2>&1 || true
    
    if grep -q "AA Version" "$TEMP_DIR/parser-output.txt"; then
        test_pass "Parser accepts valid schema"
    else
        test_fail "Parser rejected valid schema"
        cat "$TEMP_DIR/parser-output.txt"
    fi
}

test_parser_identifies_ready_devices() {
    echo ""
    echo "TEST: Parser identifies READY devices"
    
    create_handoff_all_verified
    output=$(bash "$SCRIPT_DIR/aa-handoff-parser.sh" "$TEMP_DIR/handoff-verified.json" 2>&1 || true)
    
    if echo "$output" | grep -q 'front_door.*READY'; then
        test_pass "Parser marks verified device as READY"
    else
        test_fail "Parser did not identify READY device"
    fi
}

test_parser_identifies_partial_devices() {
    echo ""
    echo "TEST: Parser identifies PARTIAL devices"
    
    create_handoff_partial
    output=$(bash "$SCRIPT_DIR/aa-handoff-parser.sh" "$TEMP_DIR/handoff-partial.json" 2>&1 || true)
    
    if echo "$output" | grep -q 'garage.*PARTIAL'; then
        test_pass "Parser marks reachable/unverified device as PARTIAL"
    else
        test_fail "Parser did not identify PARTIAL device correctly"
    fi
}

test_parser_identifies_blocked_devices() {
    echo ""
    echo "TEST: Parser identifies BLOCKED devices"
    
    create_handoff_blocked
    output=$(bash "$SCRIPT_DIR/aa-handoff-parser.sh" "$TEMP_DIR/handoff-blocked.json" 2>&1 || true)
    
    if echo "$output" | grep -q 'backyard.*BLOCKED'; then
        test_pass "Parser marks unreachable device as BLOCKED"
    else
        test_fail "Parser did not identify BLOCKED device"
    fi
}

test_parser_extracts_rtsp_endpoints() {
    echo ""
    echo "TEST: Parser extracts RTSP endpoints"
    
    create_handoff_all_verified
    output=$(bash "$SCRIPT_DIR/aa-handoff-parser.sh" "$TEMP_DIR/handoff-verified.json" 2>&1 || true)
    
    if echo "$output" | grep -q 'rtsp://192.168.0.150:554/stream'; then
        test_pass "Parser correctly extracts RTSP endpoints"
    else
        test_fail "Parser did not extract RTSP endpoint"
    fi
}

test_integrator_generates_frigate_config() {
    echo ""
    echo "TEST: Integrator generates Frigate configurations"
    
    create_handoff_all_verified
    
    # Parse handoff to get integration-ready devices
    bash "$SCRIPT_DIR/aa-handoff-parser.sh" "$TEMP_DIR/handoff-verified.json" > "$TEMP_DIR/parsed.json" 2>/dev/null || true
    
    # Run integrator
    if bash "$SCRIPT_DIR/aa-device-integrator.sh" "$TEMP_DIR/parsed.json" "$TEMP_DIR/integration-output" 2>/dev/null; then
        if [[ -f "$TEMP_DIR/integration-output/frigate/cameras.yml" ]]; then
            if grep -q "front_door:" "$TEMP_DIR/integration-output/frigate/cameras.yml"; then
                test_pass "Integrator generates valid Frigate camera config"
            else
                test_fail "Frigate config missing camera definition"
            fi
        else
            test_fail "Integrator did not create frigate/cameras.yml"
        fi
    else
        test_fail "Integrator failed to run"
    fi
}

test_integrator_generates_ha_devices() {
    echo ""
    echo "TEST: Integrator generates Home Assistant device definitions"
    
    create_handoff_all_verified
    bash "$SCRIPT_DIR/aa-handoff-parser.sh" "$TEMP_DIR/handoff-verified.json" > "$TEMP_DIR/parsed.json" 2>/dev/null || true
    bash "$SCRIPT_DIR/aa-device-integrator.sh" "$TEMP_DIR/parsed.json" "$TEMP_DIR/integration-output" 2>/dev/null || true
    
    if [[ -f "$TEMP_DIR/integration-output/homeassistant/devices.yaml" ]]; then
        if grep -q "front_door" "$TEMP_DIR/integration-output/homeassistant/devices.yaml"; then
            test_pass "Integrator generates HA device definitions"
        else
            test_fail "HA device definition missing"
        fi
    else
        test_fail "Integrator did not create homeassistant/devices.yaml"
    fi
}

test_integrator_generates_audit_report() {
    echo ""
    echo "TEST: Integrator generates audit trail"
    
    create_handoff_mixed
    bash "$SCRIPT_DIR/aa-handoff-parser.sh" "$TEMP_DIR/handoff-mixed.json" > "$TEMP_DIR/parsed.json" 2>/dev/null || true
    bash "$SCRIPT_DIR/aa-device-integrator.sh" "$TEMP_DIR/parsed.json" "$TEMP_DIR/integration-output" 2>/dev/null || true
    
    if [[ -f "$TEMP_DIR/integration-output/audit/integration-report.md" ]]; then
        if grep -q "Frigate Cameras Integrated" "$TEMP_DIR/integration-output/audit/integration-report.md"; then
            test_pass "Integrator generates audit report with summary"
        else
            test_fail "Audit report missing summary"
        fi
    else
        test_fail "Integrator did not create audit report"
    fi
}

test_mixed_scenario() {
    echo ""
    echo "TEST: Mixed scenario (verified, partial, blocked)"
    
    create_handoff_mixed
    output=$(bash "$SCRIPT_DIR/aa-handoff-parser.sh" "$TEMP_DIR/handoff-mixed.json" 2>&1 || true)
    
    local has_ready=false
    local has_partial=false
    local has_blocked=false
    
    echo "$output" | grep -q "front_door.*READY" && has_ready=true
    echo "$output" | grep -q "garage.*PARTIAL" && has_partial=true
    echo "$output" | grep -q "backyard.*BLOCKED" && has_blocked=true
    
    if [[ "$has_ready" == true && "$has_partial" == true && "$has_blocked" == true ]]; then
        test_pass "Parser correctly handles mixed device states"
    else
        test_fail "Parser did not correctly identify all device states"
        echo "  Ready: $has_ready, Partial: $has_partial, Blocked: $has_blocked"
    fi
}

###############################################################################
# MAIN
###############################################################################

main() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "CSA AA Device Integration Test Suite"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    test_parser_validates_schema
    test_parser_identifies_ready_devices
    test_parser_identifies_partial_devices
    test_parser_identifies_blocked_devices
    test_parser_extracts_rtsp_endpoints
    test_integrator_generates_frigate_config
    test_integrator_generates_ha_devices
    test_integrator_generates_audit_report
    test_mixed_scenario
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}Tests Passed: $PASS_COUNT${NC} | ${RED}Tests Failed: $FAIL_COUNT${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [[ $FAIL_COUNT -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

main "$@"
