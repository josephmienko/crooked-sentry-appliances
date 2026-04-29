#!/bin/bash

# CSA Phase 2: MQTT Setup via HA REST API

set -uo pipefail

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
NC="\033[0m"

HA_IP="${1:-192.168.0.13}"
HA_TOKEN="${2}"
FRIGATE_PASSWORD="${4:-$(openssl rand -base64 18)}"
HOMEASSISTANT_PASSWORD="${HOMEASSISTANT_PASSWORD:-$(openssl rand -base64 18)}"

if [[ -z "$HA_TOKEN" ]]; then
  echo -e "${RED}Error: HA_TOKEN required${NC}"
  exit 1
fi

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}CSA Phase 2: MQTT Setup (HA)${NC}"
echo -e "${BLUE}================================${NC}"
echo ""
echo "Configuration:"
echo "  HA IP: $HA_IP"
echo "  MQTT Add-on: community_mosquitto"
echo ""

# Step 1: Verify connectivity
echo -e "${YELLOW}[1/4]${NC} Verifying Home Assistant connectivity..."
if ! curl -s -H "Authorization: Bearer $HA_TOKEN" "http://$HA_IP:8123/api/config" | jq -e '.state == "RUNNING"' >/dev/null 2>&1; then
  echo -e "${RED}Cannot connect to HA${NC}"
  exit 1
fi
echo -e "${GREEN}✓ Connected${NC}"

# Step 2: Check Mosquitto
echo ""
echo -e "${YELLOW}[2/4]${NC} Checking Mosquitto add-on..."
MOSQUITTO_STATUS=$(curl -s -H "Authorization: Bearer $HA_TOKEN" "http://$HA_IP:8123/api/addon/community_mosquitto" | jq -r '.installed // false')

if [[ "$MOSQUITTO_STATUS" != "true" ]]; then
  echo -e "${YELLOW}ℹ Installing Mosquitto...${NC}"
  curl -s -X POST -H "Authorization: Bearer $HA_TOKEN" "http://$HA_IP:8123/api/addon/community_mosquitto/install" >/dev/null 2>&1
  sleep 3
fi
echo -e "${GREEN}✓ Mosquitto ready${NC}"

# Step 3: Configure users
echo ""
echo -e "${YELLOW}[3/4]${NC} Configuring MQTT users..."

cat > /tmp/mqtt_config.json << JSONEOF
{
  "logins": [
    {"username": "homeassistant", "password": "$HOMEASSISTANT_PASSWORD"},
    {"username": "frigate", "password": "$FRIGATE_PASSWORD"}
  ],
  "anonymous": false,
  "allow_external_connections": true
}
JSONEOF

curl -s -X POST \
  -H "Authorization: Bearer $HA_TOKEN" \
  -H "Content-Type: application/json" \
  -d @/tmp/mqtt_config.json \
  "http://$HA_IP:8123/api/addon/community_mosquitto/options" >/dev/null 2>&1

rm /tmp/mqtt_config.json
echo -e "${GREEN}✓ Users configured${NC}"

# Step 4: Start broker
echo ""
echo -e "${YELLOW}[4/4]${NC} Starting Mosquitto broker..."
curl -s -X POST -H "Authorization: Bearer $HA_TOKEN" "http://$HA_IP:8123/api/addon/community_mosquitto/start" >/dev/null 2>&1
sleep 2

# Save credentials
mkdir -p .coordination
cat > .coordination/mqtt-credentials.env << CREDS_EOF
MQTT_BROKER_IP=$HA_IP
MQTT_PORT=1883
MQTT_HA_USER=homeassistant
MQTT_HA_PASSWORD=$HOMEASSISTANT_PASSWORD
MQTT_FRIGATE_USER=frigate
MQTT_FRIGATE_PASSWORD=$FRIGATE_PASSWORD
CREDS_EOF

echo -e "${GREEN}✓ Broker started${NC}"
echo ""
echo -e "${GREEN}✓ Phase 2 complete!${NC}"
echo ""
echo "MQTT Credentials saved to: .coordination/mqtt-credentials.env"
echo ""
echo "Next: Start Frigate with:"
echo "  ssh -i ~/.ssh/id_ed25519 bossbitch@192.168.0.12 'cd ~/frigate-setup && docker compose up -d'"
echo ""
