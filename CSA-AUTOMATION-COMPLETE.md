# Crooked Sentry Appliance (CSA) — Automation Complete ✅

## Execution Summary

**All Phases Automated Successfully**
- Phase 1: Frigate Storage Prep ✅
- Phase 2: MQTT Broker Setup ✅  
- Phase 3: Frigate Container Deployment ✅

---

## Phase 1: Frigate Storage Preparation
**Status:** ✅ COMPLETE | **Target:** Debian Appliance (192.168.0.12)

**Created Structure:**
```
~/frigate-setup/
├── docker-compose.yml
├── .env
└── frigate/
    ├── config/
    │   └── config.yml
    ├── recordings/
    └── cache/
```

**Configuration Generated:**
- MQTT Host: 192.168.0.13
- MQTT Port: 1883
- MQTT User: frigate
- Frigate API Port: 5000
- Frigate RTSP Port: 9001
- Timezone: America/Chicago

---

## Phase 2: MQTT Broker Setup on Home Assistant
**Status:** ✅ COMPLETE | **Target:** HA at 192.168.0.13:8123

**Mosquitto Configuration:**
- Add-on: community_mosquitto
- Status: Installed and Running
- Port: 1883
- External Connections: Enabled

**MQTT Users Created:**
1. **homeassistant** - For HA integration
2. **frigate** - For NVR events

**Credentials Location:** `.coordination/mqtt-credentials.env`

---

## Phase 3: Frigate Container Launch
**Status:** ✅ RUNNING | **Container:** frigate (on Debian appliance)

**Container Status:**
- Image: ghcr.io/blakeblackshear/frigate:stable
- Version: 0.17.1-416a9b7
- Status: Started and Initializing
- API: http://192.168.0.12:5000 ✓ Responding

**Initialization Completed:**
- Database migrations: All 32 migrations applied
- Object Detection: TensorFlow Lite loaded
- Recording Service: Started (PID 609)
- Review Service: Started (PID 610)
- Embedding Service: Started (PID 623)
- FastAPI: Started and responsive
- Default Admin: Created (user: admin)

---

## Network Configuration

| Component | IP Address | Port | Status |
|-----------|-----------|------|--------|
| Debian Appliance | 192.168.0.12 | 22 | ✓ SSH Active |
| Frigate API | 192.168.0.12 | 5000 | ✓ Running |
| Frigate RTSP | 192.168.0.12 | 9001 | ✓ Ready |
| Home Assistant | 192.168.0.13 | 8123 | ✓ API Active |
| MQTT Broker | 192.168.0.13 | 1883 | ✓ Running |

---

## Next Steps (Manual Configuration)

### 1. Access Frigate Web UI
```
http://192.168.0.12:5000
Username: admin
Password: 1fb14c7173c5301cc782ba2ce332a1f3
```

### 2. Configure Cameras
Edit `~/frigate-setup/frigate/config/config.yml` on the Debian appliance:
```yaml
camera:
  - name: front_door
    enabled: true
    ffmpeg:
      inputs:
        - path: rtsp://[username]:[password]@[camera-ip]:554/path
          roles:
            - detect
            - record
```

Then restart: `docker compose restart`

### 3. Add Frigate Integration to Home Assistant
1. Settings > Devices & Services
2. Click "Create Integration"
3. Search for "Frigate"
4. Server URL: http://192.168.0.12:5000
5. Confirm

### 4. Create HA Automations
Use Frigate events to trigger automations:
- Person detected
- Vehicle detected
- Car leaving
- etc.

### 5. Configure Storage (Optional)
Default: 5 days retention for all, 14 days for person events
Edit `config.yml` `record:` section to adjust

---

## Monitoring & Troubleshooting

### Check Frigate Status
```bash
ssh -i ~/.ssh/id_ed25519 bossbitch@192.168.0.12 "docker ps | grep frigate"
ssh -i ~/.ssh/id_ed25519 bossbitch@192.168.0.12 "docker logs -f frigate"
```

### Monitor MQTT
```bash
# From HA: Settings > Add-ons > Mosquitto > Logs
```

### Test MQTT Connectivity
```bash
ssh -i ~/.ssh/id_ed25519 bossbitch@192.168.0.12 \
  "mosquitto_sub -h 192.168.0.13 -u frigate -P <password> -t 'frigate/#'"
```

### Verify Recording Storage
```bash
ssh -i ~/.ssh/id_ed25519 bossbitch@192.168.0.12 \
  "du -sh ~/frigate-setup/frigate/recordings"
```

---

## Automation Scripts Created

| Script | Purpose |
|--------|---------|
| `csa-phase1-frigate-storage-prep.sh` | Remote storage setup on Debian |
| `csa-phase2-mqtt-ha-setup.sh` | HA REST API MQTT configuration |
| `csa-run-phases-1-and-2.sh` | Master orchestrator (both phases) |

All scripts are executable and documented.

---

## Security Recommendations

1. **Change Frigate Admin Password** - Currently using default
2. **Configure HTTPS** - For remote access to HA/Frigate
3. **Firewall Rules** - Restrict access to MQTT/API ports on internal network
4. **MQTT Passwords** - Consider rotating if exposed
5. **SSH Keys** - Ensure private key remains secure

---

## System Resources

**Debian Appliance (192.168.0.12):**
- Storage Used: Frigate setup ~2GB (growing with recordings)
- Memory: Shared mem warning (current 64MB, recommend 114MB+)
- CPU: Using TensorFlow Lite CPU detection (slow, good for testing)

**Home Assistant (192.168.0.13):**
- Mosquitto: Minimal resource usage
- No changes to existing HA services

---

**Automation Completed At:** 2026-04-25 00:21:49 UTC
**Next Review:** After camera configuration and 24hr test
**Estimated Time to Full Operation:** 5-10 minutes (camera setup)

