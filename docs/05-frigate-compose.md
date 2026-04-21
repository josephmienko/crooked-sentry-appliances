# Phase 5: Frigate Docker Compose Setup

**Duration**: ~1–2 hours
**Goal**: Deploy Frigate NVR on OptiPlex via Docker Compose with basic configuration and validation.

## Overview

Frigate is a realtime object detection NVR that uses YOLO models to detect objects in video streams. Phase 5 deploys the core service; camera setup happens when you add cameras.

**Prerequisites**:

- Phase 3 (OptiPlex Linux + Docker) complete
- Phase 4 (MQTT setup) complete
- Docker Compose working on OptiPlex

---

## Step 1: Prepare Frigate Directory Structure

On OptiPlex:

```bash
# Already created in Phase 3, verify:
cd ~/frigate-setup
ls -la frigate/
# Expected: config/, recordings/, cache/ directories

# Ensure proper permissions:
chmod 755 ~/frigate-setup
chmod 755 ~/frigate-setup/frigate/config
chmod 755 ~/frigate-setup/frigate/recordings
```

**Result**: [ ] Directories ready with correct permissions

---

## Step 2: Create Docker Compose File

Create `docker-compose.yml` in `~/frigate-setup/`:

```bash
cd ~/frigate-setup
cat > docker-compose.yml << 'EOF'
version: "3.8"

services:
  frigate:
    image: ghcr.io/blakeblackshear/frigate:stable
    container_name: frigate
    restart: unless-stopped
    privileged: true
    
    environment:
      FRIGATE_RTSP_PASSWORD: ${FRIGATE_RTSP_PASSWORD:-password}
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
    
    labels:
      - "com.example.description=Frigate NVR"

  mqtt-bridge:
    image: eclipse-mosquitto:2
    container_name: frigate-mqtt-bridge
    restart: unless-stopped
    
    ports:
      - "1883:1883"
    
    volumes:
      - ./mosquitto/config:/mosquitto/config:ro
      - ./mosquitto/data:/mosquitto/data:rw
    
    networks:
      - frigate-net
    
    profiles: ["test"]  # Only run if explicitly enabled
    labels:
      - "com.example.description=MQTT test bridge (optional)"

networks:
  frigate-net:
    driver: bridge

volumes:
  frigate-config:
  frigate-recordings:
  frigate-cache:
EOF
```

**Result**: [ ] docker-compose.yml created

---

## Step 3: Create .env File

```bash
cat > .env << 'EOF'
# Network & Connection
MQTT_HOST=192.168.1.10
MQTT_PORT=1883
MQTT_USER=frigate
MQTT_PASSWORD=your_frigate_mqtt_password
TIMEZONE=America/Chicago

# Frigate API Settings
FRIGATE_API_PORT=5000
FRIGATE_RTSP_PORT=9001
FRIGATE_RTSP_PASSWORD=rtsppassword
EOF
```

**Change values to match your setup** (from Phase 1 network config and Phase 4 MQTT setup).

**Result**: [ ] .env file created with values

---

## Step 4: Create Minimal Frigate Config

```bash
cat > frigate/config/config.yml << 'EOF'
logger:
  default: info
  logs:
    frigate.record: debug

database:
  path: /config/frigate.db

mqtt:
  host: 192.168.1.10
  port: 1883
  user: frigate
  password: ${MQTT_PASSWORD}
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
EOF
```

**Note**: Camera settings are placeholders. You'll configure actual cameras later.

**Result**: [ ] config.yml created with base configuration

---

## Step 5: Bring Up Frigate

```bash
cd ~/frigate-setup

# Start Frigate (and download image if needed)
docker compose up -d

# Watch startup logs (Ctrl+C to exit)
docker compose logs -f frigate

# Expected: Model download, startup messages, no critical errors
```

Wait 2–3 minutes for full startup (model downloads may take time based on connection speed).

**Result**: [ ] Docker Compose started

---

## Step 6: Verify Frigate Container Status

```bash
docker compose ps
# Expected: frigate container "Up" and "healthy"

docker ps | grep frigate
# Alternative: shows frigate-* containers running
```

**Result**: [ ] Container running

---

## Step 7: Test Frigate API

From your development machine or the OptiPlex:

```bash
curl -s http://192.168.1.20:5000/api/version | jq .
# Expected: JSON with version info

# Or without jq:
curl http://192.168.1.20:5000/api/version
```

**Result**: [ ] API reachable and responding

---

## Step 8: Access Frigate Web UI

Open browser to:

```text
http://192.168.1.20:5000
```

Expected:

- Frigate dashboard loads
- Shows "No cameras" or placeholder camera (disabled)
- UI responsive and functional

**Result**: [ ] Web UI accessible

---

## Step 9: Verify MQTT Connection

Check Frigate logs for MQTT connection:

```bash
docker compose logs frigate | grep -i mqtt
# Expected: Messages like "Connected to MQTT"
```

Or use MQTT tools to test pub/sub (like Phase 4):

```bash
mosquitto_sub -h 192.168.1.10 -u frigate -P <frigate-password> -t "frigate/#" -v
# Leave running; should see discovery messages
```

**Result**: [ ] MQTT connectivity confirmed in logs

---

## Phase 5 Validation Checklist

- [ ] Frigate directories created and initialized
- [ ] docker-compose.yml created and valid
- [ ] .env file created with correct MQTT values
- [ ] config.yml created with placeholder configuration
- [ ] `docker compose up -d` successful
- [ ] `docker compose ps` shows frigate container running
- [ ] Frigate API responds: `curl http://192.168.1.20:5000/api/version`
- [ ] Frigate Web UI accessible: [192.168.1.20:5000](http://192.168.1.20:5000)
- [ ] MQTT connection established (logs show "Connected" message)
- [ ] No container restart loops or errors

---

## Troubleshooting Phase 5

### Container fails to start

- Check logs: `docker compose logs frigate`
- Verify .env values (MQTT_HOST, passwords, etc.)
- Disk space: `df -h` (need >5 GB free for models and recordings)

### API not responding

- Verify port mapping: `docker compose ps` (should show 5000:5000)
- Check Docker network: `docker network ls`
- Firewall: `sudo ufw status` (port 5000 allowed or disabled)

### Model download stuck

- First startup downloads ~1 GB of YOLO models
- Patience! Allow 10–15 minutes on first run
- Check internet speed/connection

### MQTT not connecting

- Verify Mosquitto running on HA: `ha addon info community_mosquitto`
- Check credentials: username "frigate" and password from Phase 4
- Verify IP/port in config.yml matches MQTT broker

---

## Next Steps

Phase 5 validation complete? ✅

**Proceed to [06-ha-frigate-integration.md](06-ha-frigate-integration.md) to connect HA to Frigate.**

---

**Status**: Phase 5 complete. Frigate running and ready for HA integration.
