#!/bin/bash
#
# Parse AA Device Handoff - CSA Integration
# Simpler parser for AA device attestation handoff
#
# Usage:
#   ./parse-aa-handoff.sh <handoff.json> [output-dir]
#

set -euo pipefail

HANDOFF="${1:-.coordination/device-handoff-latest.json}"
OUTPUT_DIR="${2:-.coordination/parsed-output}"

mkdir -p "$OUTPUT_DIR"

if [[ ! -f "$HANDOFF" ]]; then
    echo "Error: Handoff file not found: $HANDOFF"
    exit 1
fi

echo "Parsing AA device handoff: $HANDOFF"
echo ""

# Validate JSON
if ! jq -e '.devices' "$HANDOFF" > /dev/null 2>&1; then
    echo "Error: Invalid JSON or missing devices array"
    exit 1
fi

# Extract AA metadata
aa_version=$(jq -r '.aa_version // "unknown"' "$HANDOFF")
generated_at=$(jq -r '.generated_at // "unknown"' "$HANDOFF")

echo "AA Version: $aa_version"
echo "Generated: $generated_at"
echo ""

# Process devices and collect results
device_count=0
ready_count=0
partial_count=0
blocked_count=0

# Audit report
{
    echo "# AA Device Handoff Analysis"
    echo "Generated: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    echo "Handoff: $HANDOFF"
    echo ""
    echo "## Device Summary"
    echo ""
} > "$OUTPUT_DIR/audit.md"

# JSON output
{
    echo "{"
    echo '  "devices": ['
} > "$OUTPUT_DIR/devices.json"

first=true

# Process each device
mapfile -t devices < <(jq -c '.devices[]' "$HANDOFF")

for device in "${devices[@]}"; do
    ((device_count++))
    
    name=$(echo "$device" | jq -r '.device_name // "unknown"')
    ip=$(echo "$device" | jq -r '.ip_address // "unknown"')
    brand=$(echo "$device" | jq -r '.brand // "unknown"')
    model=$(echo "$device" | jq -r '.model // "unknown"')
    verified=$(echo "$device" | jq -r '.identity_verified // false')
    reachable=$(echo "$device" | jq -r '.verification_message // ""' | grep -q "not reachable" && echo false || echo true)
    capabilities_count=$(echo "$device" | jq '.capabilities | length')
    rtsp=$(echo "$device" | jq -r '.capabilities[] | select(.protocol == "rtsp") | .endpoint' | head -1 || echo "")
    
    # Determine status
    status="BLOCKED"
    reason=""
    
    if [[ "$reachable" == "false" ]]; then
        status="BLOCKED"
        reason="Device not reachable"
    elif [[ "$verified" == "true" && $capabilities_count -gt 0 ]]; then
        status="READY"
        reason="Device verified with capabilities"
    elif [[ "$reachable" == "true" && $capabilities_count -gt 0 ]]; then
        status="PARTIAL"
        reason="Device reachable, identity unconfirmed"
    elif [[ $capabilities_count -eq 0 ]]; then
        status="BLOCKED"
        reason="No integration endpoints available"
    fi
    
    # Count statuses
    case "$status" in
        READY) ((ready_count++)) ;;
        PARTIAL) ((partial_count++)) ;;
        BLOCKED) ((blocked_count++)) ;;
    esac
    
    # Add to audit
    {
        echo "### $name"
        echo "- **Status**: $status"
        echo "- **Reason**: $reason"
        echo "- **IP**: $ip"
        echo "- **Brand/Model**: $brand / $model"
        echo "- **Identity Verified**: $verified"
        echo "- **Endpoints**: $capabilities_count"
        if [[ -n "$rtsp" ]]; then
            echo "  - RTSP: $rtsp"
        fi
        echo ""
    } >> "$OUTPUT_DIR/audit.md"
    
    # Add to JSON if not blocked
    if [[ "$status" != "BLOCKED" ]]; then
        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo "," >> "$OUTPUT_DIR/devices.json"
        fi
        
        echo "$device" | jq '{
            device_name: .device_name,
            desired_hostname: .desired_hostname,
            ip_address: .ip_address,
            brand: .brand,
            model: .model,
            identity_verified: .identity_verified,
            rtsp_endpoint: (.capabilities[] | select(.protocol == "rtsp") | .endpoint),
            http_endpoint: (.capabilities[] | select(.protocol == "http") | .endpoint)
        }' | sed '$ s/.$//' >> "$OUTPUT_DIR/devices.json"
    fi
    
    echo "$name [$status] - $reason"
done

# Finish JSON
{
    echo ""
    echo "  ]"
    echo "}"
} >> "$OUTPUT_DIR/devices.json"

# Finish audit
{
    echo ""
    echo "## Summary"
    echo ""
    echo "| Status | Count |"
    echo "|--------|-------|"
    echo "| READY | $ready_count |"
    echo "| PARTIAL | $partial_count |"
    echo "| BLOCKED | $blocked_count |"
    echo ""
    echo "**Total Devices**: $device_count"
    echo "**Integrable**: $((ready_count + partial_count))"
} >> "$OUTPUT_DIR/audit.md"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary:"
echo "  READY:    $ready_count"
echo "  PARTIAL:  $partial_count"
echo "  BLOCKED:  $blocked_count"
echo "  TOTAL:    $device_count"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Output:"
echo "  Audit:  $OUTPUT_DIR/audit.md"
echo "  JSON:   $OUTPUT_DIR/devices.json"
