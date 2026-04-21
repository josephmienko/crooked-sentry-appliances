# Frigate Docker Compose Configuration

This directory contains the Docker Compose and configuration files for running Frigate NVR on the OptiPlex.

## Files

- **docker-compose.yml** – Main Compose file defining Frigate service and networking
- **.env.example** – Environment variables template (copy to `.env` and fill in values)
- **README.md** – This file

## Directory Structure

Expected layout after Phase 5 setup:

```bash
optiplex-frigate/
├── docker-compose.yml
├── .env                          # Your actual env file (generated from .env.example)
├── frigate/
│   ├── config/
│   │   ├── config.yml           # Frigate configuration
│   │   └── frigate.db           # Auto-created database
│   ├── recordings/              # Camera recordings (grows over time)
│   └── cache/                   # YOLO models and cache
└── README.md                    # This file
```

## Quick Start

### 1. Prepare Environment

```bash
cd compose/optiplex-frigate

# Copy and fill in your network configuration
cp .env.example .env   # Use your Phase 1 network values

# Verify variables
cat .env
```

### 2. Initialize Directories

```bash
# If not already created in Phase 3
mkdir -p frigate/config frigate/recordings frigate/cache

# Set permissions
chmod 755 frigate/*
```

### 3. Add Frigate Configuration

```bash
# Copy starter config
cp ../../examples/frigate-config.example.yml frigate/config/config.yml

# Edit to add cameras when ready
nano frigate/config/config.yml
```

### 4. Start Frigate

```bash
# Start in background
docker compose up -d

# Watch logs
docker compose logs -f frigate

# Check status
docker compose ps
```

### 5. Verify API

```bash
curl http://localhost:5000/api/version
# Should return JSON with Frigate version
```

## Configuration

### Frigate Config (frigate/config/config.yml)

The main Frigate configuration file. Key sections:

- **logger** – Log verbosity
- **mqtt** – Connection to Mosquitto broker
- **detect** – Object detection settings (YOLO models)
- **camera** – Camera definitions (add yours here)
- **record** – Recording retention policies
- **snapshots** – Snapshot capture settings

See example and Frigate documentation: [docs.frigate.video](https://docs.frigate.video/)

### Environment Variables (.env)

| Variable | Purpose | Example |
| --- | --- | --- |
| MQTT_HOST | MQTT broker IP | 192.168.1.10 |
| MQTT_PORT | MQTT port | 1883 |
| MQTT_USER | MQTT username | frigate |
| MQTT_PASSWORD | MQTT password | securepass |
| FRIGATE_API_PORT | API port | 5000 |
| FRIGATE_RTSP_PORT | RTSP stream proxy port | 9001 |
| TIMEZONE | System timezone | America/Chicago |

## Operations

### Start/Stop Frigate

```bash
# Start
docker compose up -d

# Stop
docker compose stop

# Restart
docker compose restart
```

### View Logs

```bash
# All services
docker compose logs

# Frigate only, follow output
docker compose logs -f frigate

# Last 50 lines
docker compose logs -n 50 frigate
```

### Backup Configuration

```bash
# Backup Frigate config
tar czf ~/frigate-config-backup-$(date +%Y%m%d).tar.gz frigate/config/
```

### Reset (Destructive)

⚠️ **WARNING**: This deletes all data. Use sparingly.

```bash
# Stop
docker compose down

# Remove volumes
docker volume rm optiplex-frigate_frigate-config \
  optiplex-frigate_frigate-recordings \
  optiplex-frigate_frigate-cache

# Or delete directories
rm -rf frigate/config/* frigate/recordings/* frigate/cache/*

# Restart fresh
docker compose up -d
```

## Adding Cameras

When you have cameras to add:

1. Edit `frigate/config/config.yml`
2. Add camera section with RTSP URL:

   ```yaml
   camera:
     - name: front_door
       enabled: true
       ffmpeg:
         inputs:
           - path: rtsp://user:pass@192.168.1.100:554/stream
   ```

3. Restart Frigate: `docker compose restart frigate`
4. Verify in Frigate UI: `http://192.168.1.20:5000`

## Troubleshooting

### Container won't start

```bash
docker compose logs frigate | head -50
# Check for volume mount errors, permission issues, or config syntax errors
```

### API not responding

```bash
# Check if port is exposed
docker compose ps | grep frigate

# Test from OptiPlex:
curl http://localhost:5000/api/version

# Test firewall
sudo ufw status | grep 5000
```

### MQTT connection errors

```bash
# Check Mosquitto broker on HA
ssh root@192.168.1.10 "ha addon info community_mosquitto"

# Verify credentials in .env match Phase 4 setup
# Test MQTT pub/sub manually:
mosquitto_pub -h 192.168.1.10 -u frigate -P <password> -t test/ping -m "test"
```

### Model downloads stuck

- First startup downloads ~1 GB of YOLO models
- Allow 10–15 minutes on first run
- Check internet and disk space

## Performance Tuning

For constrained systems (limited CPU/RAM):

```yaml
# In docker-compose.yml, adjust:
deploy:
  resources:
    limits:
      cpus: "1"          # Reduce if CPU-bound
      memory: 1G         # Reduce if memory-constrained
```

For systems with GPU support, enable in YOLO detection config and docker-compose environment.

## Next Steps

After Frigate is running:

1. Connect via HA integration (Phase 6)
2. Add cameras and configure detection
3. Set up HA automations based on Frigate events
4. Monitor and tune detection settings

---

**Status**: Frigate service ready for cameras and HA integration.
