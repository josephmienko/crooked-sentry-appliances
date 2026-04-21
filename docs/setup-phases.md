# Setup Phases Roadmap

This document outlines the complete setup journey, with expected outcomes and validation steps for each phase.

## Overview

| Phase | Title                        | Owner  | Duration        | Status    |
| ----- | ---------------------------- | ------ | --------------- | --------- |
| 1     | Inventory & Assumptions      | You    | 30 min          | ✅ Phase 1 |
| 2     | HA OS Install (Raspberry Pi) | You    | 1–2 hours       | 📋 Phase 2 |
| 3     | OptiPlex Linux + Docker      | You    | 1–2 hours       | 📋 Phase 3 |
| 4     | MQTT Setup                   | You    | 30 min – 1 hour | 📋 Phase 4 |
| 5     | Frigate Docker Compose       | You    | 1–2 hours       | 📋 Phase 5 |
| 6     | HA Frigate Integration       | You    | 30 min – 1 hour | 📋 Phase 6 |
| 7     | Smoke Tests & Backups        | You    | 1 hour          | 📋 Phase 7 |
| 8     | HACS / Themes / Branding     | Future | TBD             | 🔮 Future  |
| 9     | Federated Access (Auth)      | Future | TBD             | 🔮 Future  |

## Phase 1: Inventory & Assumptions (30 minutes)

**Goal**: Confirm hardware, network, and software readiness.

**Tasks**:

1. Review [prerequisites.md](prerequisites.md) – Hardware Inventory Checklist
2. Run network pre-flight checks (ping appliances, SSH test)
3. Document your network configuration (IPs, hostnames, DNS)
4. Fill out `examples/network-config.example.env` with your actual values
5. Store sensitive values (MQTT password, etc.) in a **not-checked-in secrets file**

**Validation Checklist**:

- [ ] Both appliances network-reachable and have stable IP/hostnames
- [ ] SSH and basic CLI access confirmed on both systems
- [ ] Docker/Docker Compose installed and functional on OptiPlex
- [ ] Network documentation saved in examples/ (non-secrets values only)

**Next**: Proceed to [02-ha-os-install.md](02-ha-os-install.md)

---

## Phase 2: Home Assistant OS Install (1–2 hours)

**Goal**: Spin up a functional Home Assistant OS instance on the Raspberry Pi with network access.

**Tasks**:

1. Download HA OS image for Raspberry Pi (from home-assistant.io/download)
2. Flash MicroSD card using Raspberry Pi Imager or balena Etcher
3. Insert SD card, cable up Ethernet or WiFi, power on
4. Wait for first boot (5–10 minutes)
5. Access Home Assistant UI via browser (`http://192.168.1.10:8123` or `http://ha-rpi.local:8123`)
6. Complete HA onboarding:
   - Create local owner account (important: **do NOT use SSO yet**)
   - Set location/timezone
   - Set up SSH terminal access (optional but recommended)

**Validation Checklist**:

- [ ] HA UI reachable and onboarding complete
- [ ] Local owner account exists and usable
- [ ] HA version and system health visible in Settings > System
- [ ] Storage has adequate free space (check Settings > System > Storage)
- [ ] Network connectivity stable (check Developer Tools > States > `System > Connected` or similar)

**Next**: Proceed to [03-optiplex-linux-docker.md](03-optiplex-linux-docker.md)

---

## Phase 3: OptiPlex Linux + Docker Baseline (1–2 hours)

**Goal**: Prepare OptiPlex as a stable Docker host for Frigate.

**Tasks**:

1. Confirm Linux OS (Ubuntu 22.04 LTS or Debian 12) on OptiPlex
   - If needed, perform clean install from Ubuntu/Debian media

2. Update system packages:

   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

3. Install Docker & Docker Compose:

   ```bash
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   sudo usermod -aG docker $USER
   newgrp docker
   docker compose version
   ```

4. Test Docker functionality:

   ```bash
   docker run hello-world
   ```

5. Configure Docker daemon (optional but recommended for stability):
   - Create or update `/etc/docker/daemon.json` for resource limits
6. Set system hostname (e.g., `optiplex-frigate`):

   ```bash
   sudo hostnamectl set-hostname optiplex-frigate
   ```

7.  Enable SSH pubkey auth (already done in most Linux installs)

**Validation Checklist**:

- [ ] `uname -a` shows Linux x86-64 architecture
- [ ] `docker --version` and `docker compose version` succeed
- [ ] `docker run hello-world` completes successfully
- [ ] Hostname set correctly (`hostname` command)
- [ ] SSH access from development machine succeeds
- [ ] System is reachable at configured IP/hostname from other appliances

**Next**: Proceed to [04-mqtt-setup.md](04-mqtt-setup.md)

---

## Phase 4: MQTT Setup (30 min – 1 hour)

**Goal**: Deploy a stable MQTT broker for inter-appliance communication.

**Decision**: Use **Mosquitto add-on on HA OS** (simplest for Phase 1).

**Tasks**:

1. Log into HA UI as owner
2. Navigate to Settings > Add-ons > Add-on Store
3. Search for "Mosquitto" (official Home Assistant add-on)
4. Install, then configure:
   - Note the default user credentials (or set custom if needed)
   - Enable "Start on boot"
   - Optionally enable "Auto update"
5. Start the add-on
6. From OptiPlex, test MQTT connectivity:
   ```bash
   sudo apt install -y mosquitto-clients
   mosquitto_pub -h 192.168.1.10 -u homeassistant -P <PASSWORD> -t "test/ping" -m "hello"
   ```
7. In HA, verify MQTT integration appears (should auto-discover)
8. Optional: Configure ACL file for Frigate user (see examples/mosquitto-v4-aclfile.example.txt)

**Validation Checklist**:

- [ ] Mosquitto add-on running and healthy (HA Settings > Add-ons > Mosquitto)
- [ ] MQTT client from OptiPlex can publish/subscribe
- [ ] HA MQTT integration shows "connected" status
- [ ] No SSL/TLS (internal network, Phase 1) – plain MQTT on port 1883

**Next**: Proceed to [05-frigate-compose.md](05-frigate-compose.md)

---

## Phase 5: Frigate Docker Compose (1–2 hours)

**Goal**: Deploy Frigate on OptiPlex via Docker Compose with minimal camera config.

**Tasks**:

1. On OptiPlex, create working directory:
   ```bash
   mkdir -p ~/frigate-setup
   cd ~/frigate-setup
   ```
2. Copy or create `docker-compose.yml` (see compose/optiplex-frigate/docker-compose.yml template)
3. Create `.env` file with your network values (see compose/optiplex-frigate/.env.example):
   ```bash
   FRIGATE_API_HOST=0.0.0.0
   FRIGATE_API_PORT=5000
   FRIGATE_RTSP_PORT=9001
   MQTT_HOST=192.168.1.10
   MQTT_PORT=1883
   MQTT_USER=homeassistant
   MQTT_PASSWORD=<your-password>
   ```
4. Create minimal frigate config:
   ```bash
   mkdir -p ./frigate/config
   cp examples/frigate-config.example.yml ./frigate/config/config.yml
   # Edit config.yml with your actual camera IPs (if adding now) or leave with placeholders
   ```
5. Bring up Frigate:
   ```bash
   docker compose up -d
   docker compose logs frigate
   ```
6. Verify container is running:
   ```bash
   docker ps | grep frigate
   ```

**Validation Checklist**:

- [ ] `docker compose ps` shows all services running
- [ ] Frigate API reachable: `curl http://localhost:5000/api/version`
- [ ] Frigate UI accessible: `http://192.168.1.20:5000` (or OptiPlex IP)
- [ ] MQTT broker reachable from Frigate logs: `docker compose logs frigate | grep -i mqtt`
- [ ] No error loops or container crashes

**Next**: Proceed to [06-ha-frigate-integration.md](06-ha-frigate-integration.md)

---

## Phase 6: HA Frigate Integration (30 min – 1 hour)

**Goal**: Connect Home Assistant to Frigate via the official integration.

**Tasks**:

1. In HA UI, go to Settings > Devices & Services > Integrations
2. Search for "Frigate" and select the official integration (by blakeblackshear)
3. Enter Frigate API URL: `http://192.168.1.20:5000` (or your OptiPlex IP:5000)
4. HA will discover Frigate cameras and entities
5. Configure Frigate card (optional, for UI visibility):
   - Install frigate-card via HACS (or add later in Phase 8)
   - Or use built-in card from Frigate integration
6. Add a lovelace card to your dashboard showing Live view or Recent events
7. Validate integration status in Settings > Devices & Services > Frigate

**Validation Checklist**:

- [ ] Frigate integration shows "Loaded" status
- [ ] Frigate devices appear in Settings > Devices (cameras, detectors, etc.)
- [ ] HA can fetch Frigate camera snapshots (visible in UI)
- [ ] Frigate events appear in HA if cameras configured with events
- [ ] No connection errors in HA logs (Settings > System > Logs)

**Next**: Proceed to [07-smoke-tests.md](07-smoke-tests.md)

---

## Phase 7: Smoke Tests & Backups (1 hour)

**Goal**: Validate full system operability and establish backup/rollback procedures.

**Tasks**:

1. End-to-end connectivity tests (see 07-smoke-tests.md)
2. Verify camera feed accessibility (if cameras configured)
3. Test MQTT message flow between HA and Frigate to OptiPlex and back
4. Verify HA still starts cleanly after restart
5. Verify OptiPlex Frigate survives a restart
6. Create full HA backup (Settings > System > Backups > Create Backup)
7. Export OptiPlex docker-compose and .env for future reference
8. Document any workarounds or custom settings applied

**Validation Checklist**:

- [ ] All appliances reachable after a full restart
- [ ] Home Assistant dashboard fully responsive
- [ ] Frigate API and UI functional post-restart
- [ ] MQTT broker operational and bridging messages
- [ ] At least one HA backup created and verified
- [ ] No missing dependencies or failed add-ons in HA

**Outcome**: System is stable and validated. Ready for production use or further customization.

---

## Phase 8: HACS / Themes / Branding (Future)

**Placeholder for future integration of**:

- `lovelace-m3-core-cards`
- `lovelace-m3-lighting-dashboard`
- `lovelace-frigate-event-feed`
- `ha-material-theme`
- `ha-branding-overrides`

**Not included in Phase 1** – focuses on core appliance setup only.

---

## Phase 9: Federated Access (Future)

**Placeholder for future auth integration**:

- `ha-federated-access` (SSO/OIDC)
- NetBird VPN (if remote access added later)
- AuthentiK or similar (if federated identity enabled)

**Not included in Phase 1** – uses local owner account only.

---

## Support & Troubleshooting

If you encounter issues during any phase:

1. **Check logs**:
   - HA: Settings > System > Logs (filter by integration name)
   - Frigate: `docker compose logs frigate` on OptiPlex
   - MQTT: HA Mosquitto add-on logs

2. **Validate network**:

   ```bash
   ping <other-appliance-ip>
   curl http://<other-appliance>:port/api/endpoint
   ```

3. **Review assumptions**: Confirm IPs, hostnames, and credentials in `examples/network-config.example.env`

4. **Restart systemically**: Start with least-dependent service (Frigate), then MQTT bridge, then HA

5. **Reference official docs**:

   - Home Assistant: https://www.home-assistant.io/
   - Frigate: https://docs.frigate.video/
   - Mosquitto: https://mosquitto.org/

---

**Ready to begin?** → Start with [01-inventory-assumptions.md](01-inventory-assumptions.md)
