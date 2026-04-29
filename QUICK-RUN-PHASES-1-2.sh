#!/usr/bin/env bash
# CSA Phase 1 & 2 Execution Quick Reference
# 
# Copy & run commands from this file to execute Phase 1 & 2 setup
# 
# Prerequisites:
#   - SSH key at ~/.ssh/id_ed25519 (set SSH_KEY if different)
#   - HA token from http://192.168.0.13:8123/profile
#   - jq installed (brew install jq)

# ============================================================================
# STEP 1: GET YOUR HA TOKEN
# ============================================================================
# 1. Open: http://192.168.0.13:8123/profile (replace IP with your HA IP)
# 2. Scroll to bottom: "Long-Lived Access Tokens"
# 3. Click "Create Token" → Name: "CSA Setup" → Copy the token
# 4. Replace "YOUR_TOKEN_HERE" in the command below

export HA_TOKEN="YOUR_TOKEN_HERE"


# ============================================================================
# STEP 2: EXECUTE PHASES 1 & 2 (RECOMMENDED - ONE COMMAND)
# ============================================================================

cd /Users/mienko/crooked-sentry-appliances

./scripts/csa-run-phases-1-and-2.sh \
  --appliance-ip 192.168.0.12 \
  --appliance-user bossbitch \
  --ha-ip 192.168.0.13 \
  --ha-token "$HA_TOKEN" \
  --frigate-mqtt-password "generate_secure_password_or_leave_blank"


# ============================================================================
# STEP 3: OPTIONAL - INDIVIDUAL PHASES (if needed)
# ============================================================================

# Phase 1 only (Frigate storage on Debian):
./scripts/csa-phase1-frigate-storage-prep.sh \
  192.168.0.12 \
  bossbitch \
  22 \
  192.168.0.13 \
  frigate \
  "your_mqtt_password"

# Phase 2 only (MQTT on HA):
./scripts/csa-phase2-mqtt-ha-setup.sh \
  192.168.0.13 \
  "$HA_TOKEN" \
  "" \
  "your_mqtt_password"


# ============================================================================
# STEP 4: VERIFY & NEXT STEPS
# ============================================================================

# After scripts complete, verify setup:

# 1. Check Frigate directory on Debian:
ssh -i ~/.ssh/id_ed25519 bossbitch@192.168.0.12 'ls -la ~/frigate-setup/'

# 2. Start Frigate:
ssh -i ~/.ssh/id_ed25519 bossbitch@192.168.0.12 \
  'cd ~/frigate-setup && docker compose up -d'

# 3. Check Frigate logs:
ssh -i ~/.ssh/id_ed25519 bossbitch@192.168.0.12 \
  'docker logs -f frigate'

# 4. Test Frigate API:
curl http://192.168.0.12:5000/api/version

# 5. Test MQTT connectivity:
ssh -i ~/.ssh/id_ed25519 bossbitch@192.168.0.12 \
  'mosquitto_pub -h 192.168.0.13 -u frigate -P "password" -t test -m hello'

# 6. Access Frigate web UI:
#    Open: http://192.168.0.12:5000 in browser

# 7. Add Frigate to Home Assistant:
#    Settings > Devices & Services > Create Integration > Search "Frigate"
#    Enter URL: http://192.168.0.12:5000


# ============================================================================
# ENVIRONMENT VARIABLES (ALTERNATIVE TO OPTIONS)
# ============================================================================

# Instead of using --options, you can export environment variables:

export APPLIANCE_IP=192.168.0.12
export APPLIANCE_SSH_USER=bossbitch
export APPLIANCE_SSH_PORT=22
export HA_IP=192.168.0.13
export HA_TOKEN="your_token_here"
export FRIGATE_MQTT_PASSWORD="secure_password"
export SSH_KEY=$HOME/.ssh/id_ed25519

# Then just run:
./scripts/csa-run-phases-1-and-2.sh


# ============================================================================
# TROUBLESHOOTING
# ============================================================================

# SSH Connection Issues:
ssh -i ~/.ssh/id_ed25519 -v bossbitch@192.168.0.12 'echo test'

# Check Docker on appliance:
ssh -i ~/.ssh/id_ed25519 bossbitch@192.168.0.12 'docker ps'

# Check HA token is valid:
curl -H "Authorization: Bearer $HA_TOKEN" \
  http://192.168.0.13:8123/api/config

# Check MQTT running on HA:
curl -H "Authorization: Bearer $HA_TOKEN" \
  http://192.168.0.13:8123/api/addon/community_mosquitto/info | jq '.data.state'


# ============================================================================
# CREDENTIALS SAVED
# ============================================================================

# After Phase 2, credentials are saved to:
cat .coordination/mqtt-credentials.env

# Use these credentials for:
# - Frigate MQTT connection
# - Home Assistant MQTT integration
# - Any other MQTT clients


# ============================================================================
# NEXT PHASES
# ============================================================================

# Phase 3: Add cameras to Frigate config
#   Edit: ~/frigate-setup/frigate/config/config.yml
#   Add camera entries with RTSP stream URLs
#   Restart: docker compose restart

# Phase 4: Configure HA integrations
#   Add Frigate integration via HA UI
#   Create automations with Frigate events

# Phase 5+: Advanced configuration
#   See: docs/01-inventory-assumptions.md
#   See: docs/05-frigate-compose.md
#   See: docs/06-ha-frigate-integration.md
