#!/bin/bash
#
# Simplified CSA AA Device Integration Test Suite
#

set -u  # Disable errexit to let tests continue

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0

test_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((PASS_COUNT++))
}

test_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    ((FAIL_COUNT++))
}

###############################################################################
# QUICK SANITY CHECKS
###############################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "CSA AA Device Integration Quick Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test 1: Parser script exists and is executable
if [[ -x "$SCRIPT_DIR/aa-handoff-parser.sh" ]]; then
    test_pass "Parser script is executable"
else
    test_fail "Parser script not found or not executable"
fi

# Test 2: Integrator script exists and is executable
if [[ -x "$SCRIPT_DIR/aa-device-integrator.sh" ]]; then
    test_pass "Integrator script is executable"
else
    test_fail "Integrator script not found or not executable"
fi

# Test 3: Real handoff file exists
if [[ -f ".coordination/device-handoff-latest.json" ]]; then
    test_pass "Device handoff artifact exists"
else
    test_fail "Device handoff artifact not found"
fi

# Test 4: Parser handles real handoff
echo ""
echo "TEST: Parser processes real device handoff"
output=$("$SCRIPT_DIR/aa-handoff-parser.sh" ".coordination/device-handoff-latest.json" 2>&1 || true)

if echo "$output" | grep -q "AA Version"; then
    test_pass "Parser reads AA handoff successfully"
else
    test_fail "Parser failed to read handoff"
    echo "$output" | head -20
fi

# Test 5: Parser identifies device statuses
echo ""
echo "TEST: Parser identifies device statuses"

if echo "$output" | grep -q "front_door"; then
    test_pass "Parser found 'front_door' device"
else
    test_fail "Parser did not find 'front_door' device"
fi

if echo "$output" | grep -q "backyard"; then
    test_pass "Parser found 'backyard' device"
else
    test_fail "Parser did not find 'backyard' device"
fi

if echo "$output" | grep -q "BLOCKED\|PARTIAL\|READY"; then
    test_pass "Parser assigned device status"
else
    test_fail "Parser did not assign device status"
fi

# Test 6: Check for eligibility classification
echo ""
echo "TEST: Parser eligibility classification"

if echo "$output" | grep -q "Status"; then
    test_pass "Parser generated status summaries"
else
    test_fail "Parser did not generate status summaries"
fi

# Test 7: Check JSON output parsing
echo ""
echo "TEST: Parser JSON output"

json_output=$("$SCRIPT_DIR/aa-handoff-parser.sh" ".coordination/device-handoff-latest.json" --json 2>/dev/null | grep -A 1000 "^{" || true)

if echo "$json_output" | jq -e '.devices' > /dev/null 2>&1; then
    test_pass "Parser generates valid JSON"
else
    test_fail "Parser JSON output not valid"
    echo "Output was: $(echo "$json_output" | head -5)"
fi

# Test 8: Test with simple scenario
echo ""
echo "TEST: Parser with sample handoff scenarios"

# Create a simple test handoff with one READY device
TEMP_DIR=$(mktemp -d)
cat > "$TEMP_DIR/test-ready.json" << 'EOF'
{
  "schema_version": "1.0",
  "generated_at": "2026-04-28T15:00:00Z",
  "aa_version": "0.4.0",
  "devices": [
    {
      "device_name": "test_camera",
      "desired_hostname": "test.local",
      "ip_address": "192.168.0.200",
      "brand": "test",
      "model": "T100",
      "identity": {"serial": "TEST123"},
      "capabilities": [
        {"protocol": "rtsp", "endpoint": "rtsp://192.168.0.200:554/stream"}
      ],
      "identity_verified": true,
      "verification_message": "Device verified",
      "firmware_operation": {"status": "success"},
      "hostname_operation": {"status": "success"}
    }
  ],
  "handoff_notes": "Test handoff"
}
EOF

sample_output=$("$SCRIPT_DIR/aa-handoff-parser.sh" "$TEMP_DIR/test-ready.json" 2>&1 || true)

if echo "$sample_output" | grep -q "test_camera.*READY"; then
    test_pass "Parser correctly identifies READY device"
else
    test_fail "Parser did not identify READY device"
fi

rm -f "$TEMP_DIR/test-ready.json"

# Final summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "Tests Passed: ${GREEN}$PASS_COUNT${NC} | Tests Failed: ${RED}$FAIL_COUNT${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

exit $FAIL_COUNT
