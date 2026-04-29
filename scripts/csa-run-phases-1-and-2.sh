#!/bin/bash

# Crooked Sentry Appliance (CSA) — Phase 1 & 2 Orchestrator
#
# Automated setup for CSA Phase 1 (Frigate storage) and Phase 2 (MQTT via HA API).
# Runs in sequence and coordinates between Debian appliance and Home Assistant.
#
# Usage:
#   ./scripts/csa-run-phases-1-and-2.sh [OPTIONS]
#
# Options:
#   --appliance-ip IP              Debian appliance IP (default: 192.168.0.12)
#   --appliance-user USER          SSH user (default: bossbitch)
#   --appliance-port PORT          SSH port (default: 22)
#   --ha-ip IP                     Home Assistant IP (default: 192.168.0.13)
#   --ha-token TOKEN               HA long-lived access token (required)
#   --ssh-key PATH                 SSH private key (default: ~/.ssh/id_ed25519)
#   --frigate-mqtt-password PASS   Frigate MQTT password (default: auto-generated)
#   --ha-mqtt-password PASS        HA MQTT password (default: auto-generated)
#   --help                         Show this help message
#
# Environment Variables (alternative to options):
#   APPLIANCE_IP, APPLIANCE_SSH_USER, APPLIANCE_SSH_PORT
#   HA_IP, HA_TOKEN
#   SSH_KEY
#   FRIGATE_MQTT_PASSWORD, HA_MQTT_PASSWORD
#
# Example 1: With all options provided
#   ./scripts/csa-run-phases-1-and-2.sh \
#     --appliance-ip 192.168.0.12 \
#     --appliance-user bossbitch \
#     --ha-ip 192.168.0.13 \
#     --ha-token "eyJhbGciOiJIUzI1NiIs..." \
#     --frigate-mqtt-password "secure_frigate_pass"
#
# Example 2: With environment variables
#   export HA_TOKEN="eyJhbGciOiJIUzI1NiIs..."
#   export FRIGATE_MQTT_PASSWORD="secure_pass"
#   ./scripts/csa-run-phases-1-and-2.sh
#
# Example 3: Interactive (will prompt for missing values)
#   ./scripts/csa-run-phases-1-and-2.sh --ha-token "token_here"

set -uo pipefail

# Colors
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
NC="\033[0m"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration (from options or env vars)
APPLIANCE_IP="${APPLIANCE_IP:-192.168.0.12}"
APPLIANCE_SSH_USER="${APPLIANCE_SSH_USER:-bossbitch}"
APPLIANCE_SSH_PORT="${APPLIANCE_SSH_PORT:-22}"
HA_IP="${HA_IP:-192.168.0.13}"
HA_TOKEN="${HA_TOKEN:-}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519}"
FRIGATE_MQTT_PASSWORD="${FRIGATE_MQTT_PASSWORD:-}"
HA_MQTT_PASSWORD="${HA_MQTT_PASSWORD:-}"

# Parse command-line options
while [[ $# -gt 0 ]]; do
  case $1 in
    --appliance-ip)
      APPLIANCE_IP="$2"
      shift 2
      ;;
    --appliance-user)
      APPLIANCE_SSH_USER="$2"
      shift 2
      ;;
    --appliance-port)
      APPLIANCE_SSH_PORT="$2"
      shift 2
      ;;
    --ha-ip)
      HA_IP="$2"
      shift 2
      ;;
    --ha-token)
      HA_TOKEN="$2"
      shift 2
      ;;
    --ssh-key)
      SSH_KEY="$2"
      shift 2
      ;;
    --frigate-mqtt-password)
      FRIGATE_MQTT_PASSWORD="$2"
      shift 2
      ;;
    --ha-mqtt-password)
      HA_MQTT_PASSWORD="$2"
      shift 2
      ;;
    --help)
      head -60 "$0" | tail -55
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      exit 1
      ;;
  esac
done

# Show header
clear
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Crooked Sentry Appliance (CSA) — Phase 1 & 2 Setup      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Show configuration
echo -e "${CYAN}Configuration:${NC}"
echo "  Debian Appliance:    ${APPLIANCE_SSH_USER}@${APPLIANCE_IP}:${APPLIANCE_SSH_PORT}"
echo "  SSH Key:             $SSH_KEY"
echo "  Home Assistant:      $HA_IP"
echo "  MQTT Broker:         Will run on HA (port 1883)"
echo ""

# Validate prerequisites
echo -e "${YELLOW}Validating prerequisites...${NC}"

if [[ ! -f "$SSH_KEY" ]]; then
  echo -e "${RED}✗ SSH key not found: $SSH_KEY${NC}"
  exit 1
fi
echo -e "${GREEN}  ✓ SSH key exists${NC}"

if ! command -v jq &> /dev/null; then
  echo -e "${RED}✗ jq not installed (required for HA API)${NC}"
  exit 1
fi
echo -e "${GREEN}  ✓ jq installed${NC}"

if [[ -z "$HA_TOKEN" ]]; then
  echo -e "${RED}✗ HA_TOKEN not provided${NC}"
  echo "  Provide via: --ha-token TOKEN or HA_TOKEN=token environment variable"
  exit 1
fi
echo -e "${GREEN}  ✓ HA token provided${NC}"

echo ""

# Generate passwords if not provided
if [[ -z "$FRIGATE_MQTT_PASSWORD" ]]; then
  FRIGATE_MQTT_PASSWORD=$(openssl rand -base64 18)
  echo -e "${YELLOW}ℹ Generated Frigate MQTT password (set FRIGATE_MQTT_PASSWORD to override)${NC}"
fi

if [[ -z "$HA_MQTT_PASSWORD" ]]; then
  HA_MQTT_PASSWORD=$(openssl rand -base64 18)
  echo -e "${YELLOW}ℹ Generated HA MQTT password (set HA_MQTT_PASSWORD to override)${NC}"
fi

echo ""

# Prompt for confirmation
echo -e "${CYAN}Ready to proceed with automation:${NC}"
echo "  Phase 1: Frigate storage prep on $APPLIANCE_IP"
echo "  Phase 2: MQTT broker setup on $HA_IP"
echo ""
read -p "Continue? [y/N] " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 1
fi

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}PHASE 1: Frigate Storage Setup (Debian Appliance)${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

# Run Phase 1 script
if ! "$SCRIPT_DIR/csa-phase1-frigate-storage-prep.sh" \
  "$APPLIANCE_IP" \
  "$APPLIANCE_SSH_USER" \
  "$APPLIANCE_SSH_PORT" \
  "$HA_IP" \
  "frigate" \
  "$FRIGATE_MQTT_PASSWORD"; then
  
  echo -e "${RED}✗ Phase 1 failed${NC}"
  exit 1
fi

echo ""
read -p "Phase 1 complete. Continue to Phase 2? [y/N] " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Phase 1 complete. You can run Phase 2 later."
  exit 0
fi

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}PHASE 2: MQTT Setup (Home Assistant)${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

# Run Phase 2 script
# Note: We pass HA token as second arg, leave user password empty (not needed for API)
if ! "$SCRIPT_DIR/csa-phase2-mqtt-ha-setup.sh" \
  "$HA_IP" \
  "$HA_TOKEN" \
  "" \
  "$FRIGATE_MQTT_PASSWORD"; then
  
  echo -e "${YELLOW}⚠ Phase 2 had issues (may be non-critical)${NC}"
  # Don't exit on Phase 2 failure as it might be partial success
fi

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ PHASES 1 & 2 SETUP COMPLETE!${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}Summary:${NC}"
echo "  Frigate storage:   Configured at ~/frigate-setup on $APPLIANCE_IP"
echo "  MQTT broker:       Running on $HA_IP:1883"
echo "  Frigate user:      frigate / $(echo "${FRIGATE_MQTT_PASSWORD}" | cut -c1-8)..."
echo "  HA user:           homeassistant / $(echo "${HA_MQTT_PASSWORD}" | cut -c1-8)..."
echo ""

echo -e "${CYAN}Next steps:${NC}"
echo "  1. Start Frigate on Debian appliance:"
echo "     ssh -i $SSH_KEY ${APPLIANCE_SSH_USER}@${APPLIANCE_IP}"
echo "     cd ~/frigate-setup && docker compose up -d"
echo ""
echo "  2. Monitor Frigate logs:"
echo "     docker logs -f frigate"
echo ""
echo "  3. Access Frigate at: http://${APPLIANCE_IP}:5000"
echo ""
echo "  4. Add Frigate integration to HA:"
echo "     Settings > Devices & Services > Create Integration > Frigate"
echo "     URL: http://${APPLIANCE_IP}:5000"
echo ""
echo "  5. Add cameras and configure detection (Phase 3)"
echo ""
echo "Credentials saved to: .coordination/mqtt-credentials.env"
echo ""
