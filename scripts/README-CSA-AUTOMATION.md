# CSA Phase 1 & 2 Automation Scripts

This directory contains scripts that automate CSA (Crooked Sentry Appliances) Phase 1 and Phase 2 setup. These phases handle:

- **Phase 1**: Frigate NVR storage preparation on Debian appliance
- **Phase 2**: MQTT broker installation and configuration on Home Assistant (via REST API)

## Quick Start

### Prerequisites

- SSH key-based auth configured for Debian appliance (`~/.ssh/id_ed25519`)
- Home Assistant running with REST API accessible
- `jq` installed locally (`brew install jq` on macOS)
- HA long-lived access token (generate at http://HA_IP:8123/profile)

### One-Command Setup (Recommended)

```bash
# Get your HA token first (http://HA_IP:8123/profile → Long-Lived Access Tokens)

export HA_TOKEN="eyJhbGciOiJIUzI1NiIs..."

./scripts/csa-run-phases-1-and-2.sh \
  --appliance-ip 192.168.0.12 \
  --appliance-user bossbitch \
  --ha-ip 192.168.0.13 \
  --frigate-mqtt-password "your_secure_password"
```

The master script will:

1. Validate all prerequisites
2. Run Phase 1 (Frigate storage on Debian)
3. Run Phase 2 (MQTT on HA)
4. Save credentials to `.coordination/mqtt-credentials.env`

---

## Individual Scripts

### 1. `csa-phase1-frigate-storage-prep.sh`

Prepares Frigate NVR storage and configuration on the Debian appliance.

**What it does:**

- Creates `~/frigate-setup/frigate/{config,recordings,cache}` directories
- Creates `docker-compose.yml` with Frigate service definition
- Creates `.env` file with MQTT and API configuration
- Creates minimal Frigate config at `frigate/config/config.yml`
- Sets proper directory permissions

**Usage:**

```bash
./scripts/csa-phase1-frigate-storage-prep.sh \
  [APPLIANCE_IP] \
  [SSH_USER] \
  [SSH_PORT] \
  [MQTT_HOST] \
  [MQTT_USER] \
  [MQTT_PASSWORD]
```

**Example:**

```bash
./scripts/csa-phase1-frigate-storage-prep.sh \
  192.168.0.12 \
  bossbitch \
  22 \
  192.168.0.13 \
  frigate \
  "secure_password_here"
```

**Environment variables** (alternative to positional args):

```bash
export APPLIANCE_IP=192.168.0.12
export APPLIANCE_SSH_USER=bossbitch
export APPLIANCE_SSH_PORT=22
export MQTT_HOST=192.168.0.13
export MQTT_USER=frigate
export MQTT_PASSWORD="secure_password"
export SSH_KEY=$HOME/.ssh/id_ed25519

./scripts/csa-phase1-frigate-storage-prep.sh
```

**Output:**

- All configuration files created on Debian appliance
- Ready for `docker compose up -d` to start Frigate
- Next: Run Phase 2 to set up MQTT

---

### 2. `csa-phase2-mqtt-ha-setup.sh`

Installs and configures Mosquitto MQTT broker on Home Assistant via REST API.

**What it does:**

- Verifies HA API connectivity
- Installs Community Mosquitto add-on (if not present)
- Configures two MQTT users:
  - `homeassistant` (for HA integration)
  - `frigate` (for Frigate NVR)
- Starts the add-on
- Generates and saves credentials to `.coordination/mqtt-credentials.env`

**Usage:**

```bash
./scripts/csa-phase2-mqtt-ha-setup.sh \
  [HA_IP] \
  [HA_TOKEN] \
  [HA_USER_PASSWORD] \
  [FRIGATE_PASSWORD]
```

**Example:**

```bash
./scripts/csa-phase2-mqtt-ha-setup.sh \
  192.168.0.13 \
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  "" \
  "secure_frigate_pass"
```

**Environment variables** (alternative):

```bash
export HA_IP=192.168.0.13
export HA_TOKEN="eyJhbGciOiJIUzI1NiIs..."
export FRIGATE_PASSWORD="secure_password"

./scripts/csa-phase2-mqtt-ha-setup.sh
```

**Output:**

- Mosquitto add-on installed and running on HA
- Two MQTT users created with passwords
- Credentials saved to `.coordination/mqtt-credentials.env`
- Ready for Frigate to connect via MQTT

---

### 3. `csa-run-phases-1-and-2.sh`

Master orchestration script that runs both Phase 1 and Phase 2 in sequence.

**What it does:**

- Validates all prerequisites (SSH key, jq, HA token)
- Generates secure passwords if not provided
- Runs Phase 1 on Debian appliance
- Prompts before Phase 2
- Runs Phase 2 on Home Assistant
- Displays summary of credentials and next steps

**Usage:**

```bash
./scripts/csa-run-phases-1-and-2.sh [OPTIONS]
```

**Options:**

```
--appliance-ip IP               Debian appliance IP (default: 192.168.0.12)
--appliance-user USER           SSH user (default: bossbitch)
--appliance-port PORT           SSH port (default: 22)
--ha-ip IP                      Home Assistant IP (default: 192.168.0.13)
--ha-token TOKEN                HA long-lived access token (required)
--ssh-key PATH                  SSH private key path (default: ~/.ssh/id_ed25519)
--frigate-mqtt-password PASS    Frigate MQTT password (auto-generated if not set)
--ha-mqtt-password PASS         HA MQTT password (auto-generated if not set)
--help                          Show full help
```

**Example 1: Full options**

```bash
./scripts/csa-run-phases-1-and-2.sh \
  --appliance-ip 192.168.0.12 \
  --appliance-user bossbitch \
  --ha-ip 192.168.0.13 \
  --ha-token "eyJhbGciOiJIUzI1NiIs..." \
  --frigate-mqtt-password "my_secure_pass"
```

**Example 2: Using environment variables**

```bash
export HA_TOKEN="eyJhbGciOiJIUzI1NiIs..."
export APPLIANCE_IP=192.168.0.12
export HA_IP=192.168.0.13
export FRIGATE_MQTT_PASSWORD="secure_pass"

./scripts/csa-run-phases-1-and-2.sh
```

**Output:**

- Interactive prompts at each phase
- Real-time progress indicators
- Summary of configuration
- Credentials file location
- Next steps to start Frigate

---

## Obtaining the HA Token

1. **Go to**: http://YOUR_HA_IP:8123/profile
2. **Scroll to bottom**: Find "Long-Lived Access Tokens"
3. **Click**: "Create Token"
4. **Name**: e.g., "CSA Setup"
5. **Copy**: The long token starting with `eyJ...`
6. **Use**: As `--ha-token` or `HA_TOKEN` environment variable

The token stays valid indefinitely until revoked. You can create/revoke tokens at any time from the same profile page.

---

## Generated Credentials

After Phase 2 completes, credentials are saved to:

```
.coordination/mqtt-credentials.env
```

This file contains:

```bash
MQTT_BROKER_IP=192.168.0.13
MQTT_PORT=1883
MQTT_HA_USER=homeassistant
MQTT_HA_PASSWORD=<auto-generated>
MQTT_FRIGATE_USER=frigate
MQTT_FRIGATE_PASSWORD=<your-password>
HA_IP=192.168.0.13
DEBIAN_APPLIANCE_IP=192.168.0.12
```

**⚠️ Security**: Add `.coordination/mqtt-credentials.env` to `.gitignore` (never commit passwords)

---

## Next Steps After Setup

### 1. Start Frigate on Debian Appliance

```bash
ssh -i ~/.ssh/id_ed25519 bossbitch@192.168.0.12
cd ~/frigate-setup
docker compose up -d

# Monitor logs
docker logs -f frigate
```

### 2. Verify Frigate is Running

```bash
# Via HTTP API
curl http://192.168.0.12:5000/api/version

# Or visit web UI
# http://192.168.0.12:5000
```

### 3. Verify MQTT is Working

```bash
# From Debian appliance, test publish
mosquitto_pub -h 192.168.0.13 -u frigate -P '<password>' \
  -t 'test/topic' -m 'hello'

# Or subscribe to check
mosquitto_sub -h 192.168.0.13 -u frigate -P '<password>' \
  -t 'frigate/#' &
```

### 4. Add Frigate to Home Assistant

1. Go to: Settings > Devices & Services
2. Click: "Create Integration"
3. Search: "Frigate"
4. Enter: `http://192.168.0.12:5000`
5. Click: Submit
6. Should show entities for cameras, detectors, etc.

### 5. Configure Cameras (Phase 3)

Edit `/frigate-setup/frigate/config/config.yml` on Debian:

```yaml
camera:
  - name: front_door
    ffmpeg:
      inputs:
        - path: rtsp://username:password@camera_ip:554/path
          roles:
            - detect
            - record
```

Restart Frigate: `docker compose restart`

---

## Troubleshooting

### SSH Connection Fails

- Check SSH key: `ls -la ~/.ssh/id_ed25519`
- Test directly: `ssh -i ~/.ssh/id_ed25519 bossbitch@192.168.0.12`
- Verify IP is correct (may have changed from DHCP)

### HA API Fails

- Verify token: Copy from http://HA_IP:8123/profile
- Check token format: Should start with `eyJ`
- Verify HA is running: Visit http://HA_IP:8123 in browser

### MQTT Users Not Created

- Check HA logs: Settings > System > Logs
- Verify add-on installed: Settings > Add-ons > Community Mosquitto
- Try manual config: Settings > Add-ons > Mosquitto > Configuration

### Frigate Won't Connect to MQTT

- Verify MQTT running: `curl http://192.168.0.13:8123/api/addon/community_mosquitto/info`
- Check Frigate logs: `docker logs frigate | grep -i mqtt`
- Test manually: `mosquitto_pub -h 192.168.0.13 -u frigate -P 'password' -t test -m hello`

### Docker Compose Fails

- SSH to appliance: `ssh bossbitch@192.168.0.12`
- Check Docker: `docker ps`
- Check logs: `docker logs frigate` or `docker compose logs`
- Rebuild: `docker compose down && docker compose pull && docker compose up -d`

---

## Security Notes

1. **Never commit credentials**: Add to `.gitignore`
2. **Use strong passwords**: Scripts auto-generate 24-char passwords
3. **Rotate tokens**: Revoke old HA tokens if compromised
4. **Network segmentation**: Keep appliances on isolated VLAN if possible
5. **Update images**: Regularly pull latest Frigate/Mosquitto images

---

## Files Modified/Created

**Local (not committed):**

- `.coordination/mqtt-credentials.env` (credentials after Phase 2)

**Debian appliance:**

- `~/frigate-setup/` (created by Phase 1)
  - `docker-compose.yml`
  - `.env`
  - `frigate/config/config.yml`
  - `frigate/recordings/` (for video)
  - `frigate/cache/` (for detection cache)

**Home Assistant:**

- Community Mosquitto add-on (installed by Phase 2)
- Configuration stored in HA database

---

## Support

For issues:

1. Check logs: `docker logs frigate` or HA system logs
2. Verify network: `ping 192.168.0.12` and `ping 192.168.0.13`
3. Test MQTT: Use `mosquitto_pub`/`mosquitto_sub`
4. Check docs: [Frigate docs](https://docs.frigate.video), [Mosquitto docs](https://mosquitto.org)

---
