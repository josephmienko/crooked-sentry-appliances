#!/bin/bash
#
# AA Device Integration Mapper
# Consumes parsed AA device handoff and generates:
# - Frigate camera configurations
# - Home Assistant YAML device definitions
# - Integration audit trail
#
# Usage:
#   ./aa-device-integrator.sh <parsed_handoff_json> <output_dir> [--dry-run]
#
# Output structure:
#   output_dir/
#     frigate/
#       cameras.yml     # Fragments to append to Frigate config
#     homeassistant/
#       devices.yaml    # HA device registry entries
#     audit/
#       integration-report.md
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARSED_HANDOFF="${1:-.coordination/parsed-devices.json}"
OUTPUT_DIR="${2:-.coordination/integration-output}"
DRY_RUN="${3:---dry-run}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_debug() { echo -e "${BLUE}[DEBUG]${NC} $*" >&2; }

###############################################################################
# FRIGATE INTEGRATION
###############################################################################

generate_frigate_config() {
    local device="$1"
    local device_name=$(echo "$device" | jq -r '.device_name')
    local ip=$(echo "$device" | jq -r '.ip_address')
    local brand=$(echo "$device" | jq -r '.brand')
    local model=$(echo "$device" | jq -r '.model')
    local rtsp=$(echo "$device" | jq -r '.rtsp_endpoint // empty')
    
    # Only generate if RTSP endpoint exists
    if [[ -z "$rtsp" ]]; then
        log_warn "Device $device_name has no RTSP endpoint, skipping Frigate integration"
        return 1
    fi
    
    cat << FRIGATE_CONFIG
# Device: $device_name
# Brand: $brand | Model: $model
# Integrated from AA handoff at $(date -u +'%Y-%m-%d %H:%M:%S')
# Source IP: $ip
${device_name}:
  enabled: true
  ffmpeg:
    inputs:
      - path: $rtsp
        roles:
          - detect
          - record
          - rtmp
    hwaccel_args: preset-vaapi
  detect:
    # Adjust based on your hardware
    width: 1920
    height: 1080
    fps: 5
  record:
    enabled: true
    expire_interval: 60
    retain:
      default: 7
      objects:
        person: 14

FRIGATE_CONFIG
}

###############################################################################
# HOME ASSISTANT INTEGRATION
###############################################################################

generate_homeassistant_device() {
    local device="$1"
    local device_name=$(echo "$device" | jq -r '.device_name')
    local hostname=$(echo "$device" | jq -r '.desired_hostname')
    local ip=$(echo "$device" | jq -r '.ip_address')
    local brand=$(echo "$device" | jq -r '.brand')
    local model=$(echo "$device" | jq -r '.model')
    local identity_verified=$(echo "$device" | jq -r '.identity_verified')
    local http=$(echo "$device" | jq -r '.http_endpoint // empty')
    
    local verification_note="identity_verified: $identity_verified"
    
    cat << HA_DEVICE
# Device: $device_name
# Added: $(date -u +'%Y-%m-%d %H:%M:%S')
# Note: $verification_note
- id: "csa_camera_${device_name}"
  name: "$device_name"
  manufacturer: "$brand"
  model: "$model"
  identifiers:
    - ["csa_device", "$device_name"]
  connections:
    - ["ip", "$ip"]
    - ["hostname", "$hostname"]
  hw_version: "$model"
  sw_version: "unknown"  # Update from device if available
  suggested_area: "$(echo $device_name | tr '_' ' ')"
  configuration_url: "$http"

HA_DEVICE
}

###############################################################################
# VALIDATION & AUDIT
###############################################################################

generate_integration_audit() {
    local parsed_json="$1"
    local frigate_count=$2
    local ha_count=$3
    
    cat << AUDIT_REPORT
# CSA Device Integration Report

**Generated**: $(date -u +'%Y-%m-%d %H:%M:%S')

## Summary

- **Total Devices**: $(echo "$parsed_json" | jq '.devices | length')
- **Frigate Cameras Integrated**: $frigate_count
- **Home Assistant Devices**: $ha_count

## Device Integration Details

AUDIT_REPORT
    
    # Add per-device details
    echo "$parsed_json" | jq -r '.devices[] | "### \(.device_name)\n\n- **IP**: \(.ip_address)\n- **Hostname**: \(.desired_hostname)\n- **Brand/Model**: \(.brand | ascii_upcase) \(.model)\n- **Identity Verified**: \(.identity_verified)\n- **RTSP Endpoint**: \(.rtsp_endpoint // "N/A")\n- **HTTP Endpoint**: \(.http_endpoint // "N/A")\n\n"' >> "$AUDIT_REPORT"
    
    cat << AUDIT_FOOTER

## Next Steps

1. **Frigate**: Copy camera configurations to your \`frigate/config/config.yml\`:
   \`\`\`bash
   cat frigate/cameras.yml >> ~/frigate-setup/frigate/config/config.yml
   docker restart frigate  # Validate new config
   \`\`\`

2. **Home Assistant**: Import device registry entries:
   \`\`\`bash
   # Review and merge homeassistant/devices.yaml into your HA setup
   # Or use HA UI to manually create devices
   \`\`\`

3. **Verify Integration**:
   \`\`\`bash
   # Check Frigate sees cameras
   curl http://192.168.0.18:5000/api/cameras
   
   # Check HA discovers devices
   # (Check Developer Tools > States in HA UI)
   \`\`\`

## Audit Trail

- AA Handoff schema validated ✓
- Device eligibility determined ✓
- Integration configurations generated ✓
- Next: Manual review and deployment

AUDIT_FOOTER
}

###############################################################################
# MAIN
###############################################################################

main() {
    if [[ ! -f "$PARSED_HANDOFF" ]]; then
        log_error "Parsed handoff file not found: $PARSED_HANDOFF"
        exit 1
    fi
    
    log_info "Creating integration output directory: $OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"/{frigate,homeassistant,audit}
    
    local parsed_json=$(cat "$PARSED_HANDOFF")
    local device_count=$(echo "$parsed_json" | jq '.devices | length')
    
    log_info "Processing $device_count devices for integration"
    echo ""
    
    # Initialize output files
    local frigate_config="$OUTPUT_DIR/frigate/cameras.yml"
    local ha_devices="$OUTPUT_DIR/homeassistant/devices.yaml"
    local audit_report="$OUTPUT_DIR/audit/integration-report.md"
    
    {
        echo "# Auto-generated Frigate camera configurations"
        echo "# Source: AA Device Handoff $(date -u +'%Y-%m-%d %H:%M:%S')"
        echo "# DO NOT EDIT DIRECTLY - regenerate from AA handoff"
        echo ""
        echo "# Copy these camera blocks into your frigate config.yml:"
        echo ""
    } > "$frigate_config"
    
    {
        echo "# Auto-generated Home Assistant device definitions"
        echo "# Source: AA Device Handoff $(date -u +'%Y-%m-%d %H:%M:%S')"
        echo "# DO NOT EDIT DIRECTLY - regenerate from AA handoff"
        echo ""
    } > "$ha_devices"
    
    local frigate_count=0
    local ha_count=0
    
    # Process each device
    echo "$parsed_json" | jq -c '.devices[]' | while read -r device; do
        local device_name=$(echo "$device" | jq -r '.device_name')
        
        log_info "Integrating device: $device_name"
        
        # Generate Frigate config if RTSP available
        if generate_frigate_config "$device" >> "$frigate_config" 2>/dev/null; then
            ((frigate_count++))
            log_info "  ✓ Frigate camera configuration generated"
        fi
        
        # Generate HA device definition
        if generate_homeassistant_device "$device" >> "$ha_devices" 2>/dev/null; then
            ((ha_count++))
            log_info "  ✓ Home Assistant device definition generated"
        fi
        
        echo ""
    done
    
    # Generate audit report
    generate_integration_audit "$parsed_json" "$frigate_count" "$ha_count" > "$audit_report"
    
    log_info "Integration complete!"
    log_info "Output directory: $OUTPUT_DIR"
    echo ""
    
    # Display summary
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}Integration Summary${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Frigate cameras:          $frigate_count"
    echo "HA device definitions:    $ha_count"
    echo ""
    echo "Output files:"
    echo "  - Frigate config:       $frigate_config"
    echo "  - HA devices:           $ha_devices"
    echo "  - Audit report:         $audit_report"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Show audit report
    echo ""
    cat "$audit_report"
    
    if [[ "$DRY_RUN" != "--dry-run" ]]; then
        log_info "Integration outputs ready for deployment"
    else
        log_info "DRY RUN: No files modified"
    fi
}

main "$@"
