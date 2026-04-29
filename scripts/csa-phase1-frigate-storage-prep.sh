#!/bin/bash

# Crooked Sentry Appliance (CSA) — Phase 1: Frigate Storage Preparation
#
# Automates Frigate directory structure, docker-compose, and .env setup on Debian appliance.
#
# Usage:
#   ./scripts/csa-phase1-frigate-storage-prep.sh [APPLIANCE_IP] [SSH_USER] [SSH_PORT] [MQTT_HOST] [MQTT_USER] [MQTT_PASSWORD]

set -uo pipefail

# Colors
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
NC="\033[0m"

# Configuration
APPLIANCE_IP="${1:-${APPLIANCE_IP:-192.168.0.12}}"
APPLIANCE_SSH_USER="${2:-${APPLIANCE_SSH_USER:-bossbitch}}"
APPLIANCE_SSH_PORT="${3:-${APPLIANCE_SSH_PORT:-22}}"
MQTT_HOST="${4:-${MQTT_HOST:-192.168.0.13}}"
MQTT_USER="${5:-${MQTT_USER:-frigate}}"
MQTT_PASSWORD="${6:-${MQTT_PASSWORD:-}}"
TIMEZONE="${TIMEZONE:-America/Chicago}"
FRIGATE_API_PORT="${FRIGATE_API_PORT:-5000}"
FRIGATE_RTSP_PORT="${FRIGATE_RTSP_PORT:-9001}"
FRIGATE_RTSP_PASSWORD="${FRIGATE_RTSP_PASSWORD:-rtsppassword}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519}"
MQTT_PORT="${MQTT_PORT:-1883}"

# Validation
if [[ -z "$MQTT_PASSWORD" ]]; then
  echo -e "${RED}✗ Error: MQTT_PASSWORD not provided${NC}"
  exit 1
fi

if [[ ! -f "$SSH_KEY" ]]; then
  echo -e "${RED}✗ Error: SSH key not found at $SSH_KEY${NC}"
  exit 1
fi

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}CSA Phase 1: Frigate Storage${NC}"
echo -e "${BLUE}================================${NC}"
echo ""
echo "Configuration:"
echo "  Appliance IP:    $APPLIANCE_IP"
echo "  SSH User:        $APPLIANCE_SSH_USER"
echo "  SSH Port:        $APPLIANCE_SSH_PORT"
echo "  MQTT Host:       $MQTT_HOST"
echo "  MQTT User:       $MQTT_USER"
echo ""

# Step 1: Verify connectivity
echo -e "${YELLOW}[1/5]${NC} Verifying SSH connectivity..."
if ! ssh -i "$SSH_KEY" -o ConnectTimeout=10 "${APPLIANCE_SSH_USER}@${APPLIANCE_IP}" "echo ✓ Connected" >/dev/null 2>&1; then
  echo -e "${RED}✗ Cannot connect to ${APPLIANCE_SSH_USER}@${APPLIANCE_IP}:${APPLIANCE_SSH_PORT}${NC}"
  exit 1
fi
echo -e "${GREEN}✓ SSH connection successful${NC}"

# Step 2: Create directory structure
echo ""
echo -e "${YELLOW}[2/5]${NC} Creating Frigate directory structure..."
ssh -i "$SSH_KEY" -o ConnectTimeout=10 "${APPLIANCE_SSH_USER}@${APPLIANCE_IP}" bash -s << 'REMOTE_EOF'
mkdir -p ~/frigate-setup/frigate/{config,recordings,cache}
mkdir -p ~/frigate-setup/mosquitto/{config,data}
chmod 755 ~/frigate-setup
chmod 755 ~/frigate-setup/frigate
chmod 755 ~/frigate-setup/frigate/config
chmod 755 ~/frigate-setup/frigate/recordings
chmod 755 ~/frigate-setup/frigate/cache
chmod 755 ~/frigate-setup/mosquitto
echo "✓ Directories created and permissions set"
REMOTE_EOF

# Step 3: Create docker-compose.yml
echo -e "${YELLOW}[3/5]${NC} Creating docker-compose.yml..."
ssh -i "$SSH_KEY" -o ConnectTimeout=10 "${APPLIANCE_SSH_USER}@${APPLIANCE_IP}" bash -s << 'REMOTE_EOF'
cat > ~/frigate-setup/docker-compose.yml << 'COMPOSE_FILE'
version: "3.8"

services:
  frigate:
    image: ghcr.io/blakeblackshear/frigate:stable
    container_name: frigate
    restart: unless-stopped
    privileged: true
    
    environment:
      FRIGATE_RTSP_PASSWORD: ${FRIGATE_RTSP_PASSWORD}
      MQTT_HOST: ${MQTT_HOST}
      MQTT_PORT: ${MQTT_PORT:-1883}
      MQTT_USER: ${MQTT_USER}
      MQTT_PASSWORD: ${MQTT_PASSWORD}
      TZ: ${TIMEZONE:-America/Chicago}
    
    volumes:
      - ./frigate/config:/config:rw
      - ./frigate/recordings:/media/frigate/recordings:rw
      - ./frigate/cache:/tmp/cache:rw
      - /etc/localtime:/etc/localtime:ro
    
    ports:
      - "${FRIGATE_API_PORT:-5000}:5000"
      - "${FRIGATE_RTSP_PORT:-9001}:8554"
      - "8555:8555/tcp"
      - "8555:8555/udp"
      - "8556:8556/tcp"
      - "8556:8556/udp"
    
    networks:
      - frigate-net

networks:
  frigate-net:
    driver: bridge

volumes:
  frigate-config:
  frigate-recordings:
  frigate-cache:
COMPOSE_FILE
echo "✓ docker-compose.yml created"
REMOTE_EOF

# Step 4: Create .env file
echo -e "${YELLOW}[4/5]${NC} Creating .env file..."
ssh -i "$SSH_KEY" -o ConnectTimeout=10 "${APPLIANCE_SSH_USER}@${APPLIANCE_IP}" bash << EOF
cat > ~/frigate-setup/.env << 'ENV_FILE'
# Network & MQTT Configuration
MQTT_HOST=$MQTT_HOST
MQTT_PORT=1883
MQTT_USER=$MQTT_USER
MQTT_PASSWORD=$MQTT_PASSWORD
TIMEZONE=$TIMEZONE

# Frigate API Settings
FRIGATE_API_PORT=$FRIGATE_API_PORT
FRIGATE_RTSP_PORT=$FRIGATE_RTSP_PORT
FRIGATE_RTSP_PASSWORD=$FRIGATE_RTSP_PASSWORD
ENV_FILE
echo "✓ .env file created"
EOF

# Step 5: Create minimal Frigate config
echo -e "${YELLOW}[5/5]${NC} Creating Frigate base configuration..."
ssh -i "$SSH_KEY" -o ConnectTimeout=10 "${APPLIANCE_SSH_USER}@${APPLIANCE_IP}" bash << EOF
cat > ~/frigate-setup/frigate/config/config.yml << 'CONFIG_FILE'
logger:
  default: info
  logs:
    frigate.record: debug

database:
  path: /config/frigate.db

mqtt:
  host: $MQTT_HOST
  port: 1883
  user: $MQTT_USER
  password: $MQTT_PASSWORD
  topic_prefix: frigate

camera:
  - name: placeholder_camera
    enabled: false
    ffmpeg:
      inputs:
        - path: rtsp://placeholder:password@192.168.1.100:554/path
          roles:
            - detect
            - record
    detect:
      width: 1280
      height: 720
      fps: 5
    objects:
      track:
        - person
        - car
        - dog
        - cat

# Record all cameras (minimum 5 days)
record:
  enabled: true
  sync_recordings: true
  retention:
    default: 5
    objects:
      person: 14

# Detection configuration
detect:
  enabled: true
  width: 1280
  height: 720
CONFIG_FILE
echo "✓ config.yml created"
EOF

echo ""
echo -e "${GREEN}✓ All Phase 1 tasks complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Verify directory structure: ssh -i $SSH_KEY ${APPLIANCE_SSH_USER}@${APPLIANCE_IP} 'ls -la ~/frigate-setup/'"
echo "  2. Start Frigate: ssh -i $SSH_KEY ${APPLIANCE_SSH_USER}@${APPLIANCE_IP} 'cd ~/frigate-setup && docker compose up -d'"
echo "  3. Check logs: ssh -i $SSH_KEY ${APPLIANCE_SSH_USER}@${APPLIANCE_IP} 'docker logs -f frigate'"
echo "  4. Verify API: curl http://${APPLIANCE_IP}:${FRIGATE_API_PORT}/api/version"
echo ""
echo "Frigate will be available at: http://${APPLIANCE_IP}:${FRIGATE_API_PORT}"
echo ""
