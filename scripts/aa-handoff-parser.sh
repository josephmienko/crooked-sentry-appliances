#!/bin/bash
#
# AA Device Handoff Parser
# Consumes acephalous-assembler (AA) device attestation handoff artifacts
# and validates them for CSA integration eligibility.
#
# Usage:
#   ./aa-handoff-parser.sh <handoff_json> [--audit-only] [--verbose]
#
# Output:
#   - Parsed device records with integration eligibility
#   - Audit trail (STDOUT)
#   - Integration blockers (STDERR if --verbose)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HANDOFF_FILE="${1:-.coordination/device-handoff-latest.json}"
OUTPUT_MODE="${2:---audit}"  # --audit, --json, --both
VERBOSE="${3:---verbose}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

###############################################################################
# VALIDATION RULES
###############################################################################

# Device is READY if:
# 1. identity_verified == true (AA confirmed device identity)
# 2. At least one capability is present (protocol endpoints available)
# 3. No blocking failures in firmware_operation or hostname_operation

# Device is PARTIAL if:
# 1. Device is reachable but identity NOT verified
# 2. Has capabilities but unconfirmed identity (integration allowed with caveats)

# Device is BLOCKED if:
# 1. Device unreachable (verification_message contains "not reachable")
# 2. firmware_operation has failed state and is blocking
# 3. Critical capability missing (no RTSP for cameras)

###############################################################################
# HELPER FUNCTIONS
###############################################################################

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Validate handoff schema
validate_handoff_schema() {
    local handoff="$1"
    
    # Check required top-level fields
    if ! jq -e '.schema_version' "$handoff" > /dev/null 2>&1; then
        log_error "Handoff missing schema_version"
        return 1
    fi
    
    if ! jq -e '.devices' "$handoff" > /dev/null 2>&1; then
        log_error "Handoff missing devices array"
        return 1
    fi
    
    # Validate each device has required fields
    local device_count=$(jq '.devices | length' "$handoff")
    for ((i=0; i<device_count; i++)); do
        local device=$(jq ".devices[$i]" "$handoff")
        
        local device_name=$(echo "$device" | jq -r '.device_name // empty')
        if [[ -z "$device_name" ]]; then
            log_error "Device at index $i missing device_name"
            return 1
        fi
        
        # Check required fields for each device
        for field in ip_address brand model identity_verified capabilities; do
            if ! echo "$device" | jq -e ".$field" > /dev/null 2>&1; then
                log_warn "Device '$device_name' missing field: $field"
            fi
        done
    done
    
    return 0
}

# Determine integration eligibility for a device
determine_eligibility() {
    local device="$1"
    local device_name=$(echo "$device" | jq -r '.device_name')
    local identity_verified=$(echo "$device" | jq -r '.identity_verified')
    local verification_msg=$(echo "$device" | jq -r '.verification_message')
    local capabilities=$(echo "$device" | jq -r '.capabilities | length')
    local firmware_op=$(echo "$device" | jq -r '.firmware_operation // "null"')
    local hostname_op=$(echo "$device" | jq -r '.hostname_operation // "null"')
    
    local status="BLOCKED"
    local reason=""
    local blockers=()
    
    # Check if device is reachable
    if [[ "$verification_msg" == *"not reachable"* ]]; then
        status="BLOCKED"
        blockers+=("Device not reachable: $verification_msg")
    elif [[ "$identity_verified" == "true" ]]; then
        if [[ $capabilities -gt 0 ]]; then
            status="READY"
            reason="Device verified with capabilities"
        else
            status="PARTIAL"
            reason="Device verified but no capabilities reported"
            blockers+=("No integration endpoints available")
        fi
    else
        # Device reachable but not verified
        if [[ $capabilities -gt 0 ]]; then
            status="PARTIAL"
            reason="Device reachable with capabilities, identity unconfirmed"
            blockers+=("Identity not verified by AA")
        else
            status="BLOCKED"
            reason="Device reachable but unreachable and no capabilities"
            blockers+=("No integration endpoints available")
            blockers+=("Identity not verified")
        fi
    fi
    
    # Check firmware/hostname operations for blocking failures
    if [[ "$firmware_op" == *"failed"* ]] || [[ "$firmware_op" == *"error"* ]]; then
        blockers+=("Firmware operation failed: $firmware_op")
        status="BLOCKED"
    fi
    
    if [[ "$hostname_op" == *"failed"* ]] || [[ "$hostname_op" == *"error"* ]]; then
        blockers+=("Hostname operation failed: $hostname_op")
        # Don't block on hostname alone, but note it
        if [[ "$status" != "BLOCKED" ]]; then
            status="PARTIAL"
        fi
    fi
    
    # Output structured result
    jq -n \
        --arg device_name "$device_name" \
        --arg status "$status" \
        --arg reason "$reason" \
        --argjson blockers "$(printf '%s\n' "${blockers[@]}" | jq -Rs '.' | jq -s '.')" \
        '{device_name: $device_name, status: $status, reason: $reason, blockers: $blockers}'
}

# Extract integration-ready device facts
extract_device_facts() {
    local device="$1"
    
    jq '{
        device_name: .device_name,
        desired_hostname: .desired_hostname,
        ip_address: .ip_address,
        brand: .brand,
        model: .model,
        identity_verified: .identity_verified,
        verification_message: .verification_message,
        capabilities: .capabilities,
        firmware_operation: .firmware_operation,
        hostname_operation: .hostname_operation,
        rtsp_endpoint: (.capabilities[] | select(.protocol == "rtsp") | .endpoint),
        http_endpoint: (.capabilities[] | select(.protocol == "http") | .endpoint)
    }' <<< "$device"
}

###############################################################################
# MAIN LOGIC
###############################################################################

main() {
    if [[ ! -f "$HANDOFF_FILE" ]]; then
        log_error "Handoff file not found: $HANDOFF_FILE"
        exit 1
    fi
    
    log_info "Parsing AA device handoff: $HANDOFF_FILE"
    
    # Validate schema
    if ! validate_handoff_schema "$HANDOFF_FILE"; then
        log_error "Handoff schema validation failed"
        exit 1
    fi
    
    # Parse AA metadata
    local schema_version=$(jq -r '.schema_version' "$HANDOFF_FILE")
    local aa_version=$(jq -r '.aa_version' "$HANDOFF_FILE")
    local generated_at=$(jq -r '.generated_at' "$HANDOFF_FILE")
    local handoff_notes=$(jq -r '.handoff_notes' "$HANDOFF_FILE")
    
    log_info "AA Version: $aa_version (Schema: $schema_version)"
    log_info "Generated: $generated_at"
    log_info "Notes: $handoff_notes"
    echo ""
    
    # Process each device
    local device_count=$(jq '.devices | length' "$HANDOFF_FILE")
    local ready_count=0
    local partial_count=0
    local blocked_count=0
    
    local audit_report=$(mktemp)
    local integration_output=$(mktemp)
    
    {
        echo "# CSA Device Integration Audit Report"
        echo "Generated: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
        echo "AA Handoff: $HANDOFF_FILE"
        echo ""
        echo "## Summary"
        echo ""
    } > "$audit_report"
    
    {
        echo "{"
        echo '  "schema_version": "1.0",'
        echo '  "audit_timestamp": "'$(date -u +'%Y-%m-%dT%H:%M:%SZ')'",'
        echo '  "devices": ['
    } > "$integration_output"
    
    local first_device=true
    
    # Use mapfile to avoid subshell issues with while loop
    mapfile -t devices < <(jq -c '.devices[]' "$HANDOFF_FILE")
    
    for device_str in "${devices[@]}"; do
        local device="$device_str"
        local device_name=$(echo "$device" | jq -r '.device_name')
        
        # Determine eligibility
        local eligibility=$(determine_eligibility "$device")
        local status=$(echo "$eligibility" | jq -r '.status')
        local reason=$(echo "$eligibility" | jq -r '.reason')
        local blockers=$(echo "$eligibility" | jq -r '.blockers[]' 2>/dev/null || echo "")
        
        # Track counts
        case "$status" in
            READY) ((ready_count++)) ;;
            PARTIAL) ((partial_count++)) ;;
            BLOCKED) ((blocked_count++)) ;;
        esac
        
        # Log to audit report
        {
            echo "### Device: $device_name"
            echo "- Status: **$status**"
            echo "- Reason: $reason"
            if [[ -n "$blockers" ]]; then
                echo "- Blockers:"
                echo "$blockers" | while read -r blocker; do
                    echo "  - $blocker"
                done
            fi
            echo ""
        } >> "$audit_report"
        
        # If READY or PARTIAL, add to integration output
        if [[ "$status" != "BLOCKED" ]]; then
            if [[ "$first_device" == false ]]; then
                echo "," >> "$integration_output"
            fi
            
            extract_device_facts "$device" >> "$integration_output"
            first_device=false
        fi
        
        # Verbose output
        if [[ "$VERBOSE" == "--verbose" ]]; then
            echo "Device: $device_name"
            echo "  Status: $status"
            echo "  Reason: $reason"
            echo ""
        fi
    done
    
    {
        echo "  ]"
        echo "}"
    } >> "$integration_output"
    
    # Audit summary
    {
        echo "| Status | Count |"
        echo "|--------|-------|"
        echo "| READY | $ready_count |"
        echo "| PARTIAL | $partial_count |"
        echo "| BLOCKED | $blocked_count |"
        echo ""
        echo "**Total Devices**: $device_count"
        echo "**Integrable**: $((ready_count + partial_count))"
        echo ""
    } >> "$audit_report"
    
    # Output results
    if [[ "$OUTPUT_MODE" == "--audit" ]] || [[ "$OUTPUT_MODE" == "--both" ]]; then
        cat "$audit_report"
        echo ""
    fi
    
    # Output integration-ready devices as JSON
    if [[ "$OUTPUT_MODE" == "--json" ]] || [[ "$OUTPUT_MODE" == "--both" ]]; then
        cat "$integration_output"
        echo ""
    fi
    
    log_info "Audit report written"
    log_info "Integration-ready devices: $((ready_count + partial_count)) / $device_count"
    
    # Cleanup
    rm -f "$audit_report" "$integration_output"
    
    # Exit with status based on results
    if [[ $ready_count -eq 0 ]] && [[ $partial_count -eq 0 ]]; then
        log_warn "No devices ready for integration"
        exit 1
    fi
    
    exit 0
}

main "$@"
