# Prerequisites: Hardware, Network & Assumptions

## Hardware Inventory Checklist

Before beginning setup, confirm you have the following hardware and access:

### Primary Appliance (Home Assistant OS)

- [ ] **Raspberry Pi 4 Model B (recommended 4GB+ RAM) or Raspberry Pi 5**
  - Alternatively: CM4 or other officially supported SBC
- [ ] **Adequate Power Supply**: Official RP PSU recommended (>=2.5A for RPi4, >=5A for RPi5)
- [ ] **MicroSD Card** (32GB minimum, 64GB+ recommended for future storage)
  - Class 10, U3 or higher recommended (e.g., Sandisk Extreme, Kingston A2)
- [ ] **Cooling Solution** (optional but recommended): Heatsink or official case with integrated cooling
- [ ] **Network Connection**: Ethernet cable (preferred) or WiFi dongle (less stable for long-term)
- [ ] **HDMI Cable** + Monitor/TV (for initial setup only)
- [ ] **USB Keyboard** (for initial setup)

### Analytics Appliance (Frigate / Docker Host)

- [ ] **Dell OptiPlex 3080 (or equivalent x86-64 Linux host)**
  - Similar tier systems supported if architecture is x86-64
- [ ] **Linux OS** (Ubuntu 22.04 LTS or Debian 12 minimum)
  - Should already be installed or ready for clean install
- [ ] **Docker & Docker Compose** (or Podman as alternative)
  - Docker Engine 24.0+ recommended; Docker Compose v2.20+
- [ ] **Network Connection**: Ethernet (highly recommended for Frigate stability)
- [ ] **Adequate Storage**: SSD or HDD for Docker volumes; recommend 500GB+ for Frigate recordings

### Network Infrastructure

- [ ] **Local Network Access**: Both appliances reachable via IPv4 (192.168.x.x or similar private network)
- [ ] **DNS Resolution**: Either Local DNS or mDNS capable (`.local` domains)
- [ ] **No Blocking Firewall Between Appliances**: Can reach each other on port ranges listed in integration docs
- [ ] **Network Stability**: Prefer wired Ethernet for both boxes; WiFi acceptable if stable
- [ ] **Optional**: Network-attached storage (NAS) for backups, but not required for Phase 1

## Network Assumptions

### IP Address Ranges (example, adjust to your network)

| Device       | Network Role      | Example IP   | Hostname           | Notes                                        |
| ------------ | ----------------- | ------------ | ------------------ | -------------------------------------------- |
| Raspberry Pi | Primary appliance | 192.168.1.10 | ha-rpi             | Or use DHCP + mDNS: `ha-rpi.local`           |
| OptiPlex     | Analytics host    | 192.168.1.20 | optiplex-frigate   | Or use DHCP + mDNS: `optiplex-frigate.local` |
| MQTT Broker  | (on Raspberry Pi) | 192.168.1.10 | (same as RPi)      | Port 1883 (internal) or 8883 (SSL)           |
| Frigate API  | (on OptiPlex)     | 192.168.1.20 | (same as OptiPlex) | Port 5000 (HTTP) or 9001 (RTSP proxy)        |

### Ports Used (Phase 1)

| Service           | Appliance | Port | Protocol   | Notes                          |
| ----------------- | --------- | ---- | ---------- | ------------------------------ |
| Home Assistant UI | RPi       | 8123 | HTTP/HTTPS | Primary web interface          |
| MQTT Broker       | RPi       | 1883 | MQTT       | Unencrypted (internal network) |
| Frigate API       | OptiPlex  | 5000 | HTTP       | HA integration uses this       |
| Frigate RTSP      | OptiPlex  | 9001 | RTSP       | Camera feed proxy              |
| Docker Compose    | OptiPlex  | N/A  | (various)  | Controlled via docker CLI      |

### Network Connectivity Assumptions

- **Latency**: <100ms between RPi and OptiPlex (local network only)
- **Bandwidth**: Frigate video streams typically 5-20 Mbps per camera (1080p)
- **Reliability**: Both appliances should restart without losing connectivity
- **Security**: Phase 1 is **internal network only** – no external access yet

## Software & Tools Required

### On Your Development Machine (MacBook or Linux)

- [ ] **Git**: Version control for this repo
- [ ] **Docker** (optional): To pre-test compose files before deploying
- [ ] **SSH Client**: To remote into RPi and OptiPlex
- [ ] **Text Editor**: VS Code, vim, nano, or preferred
- [ ] **Networking Tools**: ping, nslookup/dig, curl (usually pre-installed)

### On Raspberry Pi (HA OS)

- [ ] **Home Assistant OS**: Latest stable (installed during Phase 2)
- [ ] **Terminal Access**: Via SSH (enabled during setup)
- [ ] **Mosquitto Add-on**: (installed during Phase 4)
- [ ] **Home Assistant CLI / Developer Tools**: Built-in

### On OptiPlex (Docker Host)

- [ ] **Linux OS**: Ubuntu 22.04 LTS or Debian 12
- [ ] **Docker Engine**: 24.0+
- [ ] **Docker Compose**: v2.20+ (v1 acceptable but v2 preferred)
- [ ] **SSH Server**: For remote access
- [ ] **curl/wget**: For testing API endpoints
- [ ] **Basic Tools**: sudo, systemctl, journalctl

## Pre-Flight Checks

Before starting Phase 1, run these validation commands:

### Check Network Connectivity (from development machine)

```bash
# Test Raspberry Pi (update IP if your network differs)
ping 192.168.1.10
# or via mDNS if configured
ping ha-rpi.local

# Test OptiPlex
ping 192.168.1.20
# or
ping optiplex-frigate.local
```

### Check Linux / Docker on OptiPlex

```bash
# SSH into OptiPlex
ssh user@192.168.1.20

# Verify Docker installation
docker --version
docker compose version

# Test Docker daemon
docker ps
```

### Check SSH Access to Raspberry Pi

```bash
ssh root@192.168.1.10
# or if using different user/port
ssh -i ~/.ssh/ha-rpi-key user@ha-rpi.local -p 22
```

## Documented Assumptions Template

Before Phase 1, fill out and save this as `network-config.example.env` (see examples/ directory):

```bash
# Your appliance network configuration
HA_RPI_IP=192.168.1.10
HA_RPI_HOSTNAME=ha-rpi
HA_RPI_DOMAIN=local

OPTIPLEX_IP=192.168.1.20
OPTIPLEX_HOSTNAME=optiplex-frigate
OPTIPLEX_DOMAIN=local

MQTT_HOST=192.168.1.10
MQTT_PORT=1883
MQTT_USER=homeassistant
# MQTT_PASS= (keep in secrets file, not this template)

FRIGATE_HOST=192.168.1.20
FRIGATE_API_PORT=5000
FRIGATE_RTSP_PORT=9001

# Timezone
TIMEZONE=America/Chicago  # Update to your timezone

# Network assumptions
NETWORK_CIDR=192.168.1.0/24
DNS_SERVER=192.168.1.1   # Usually router IP
```

## Next Steps

1. Confirm all items in the "Hardware Inventory Checklist" above
2. Test network connectivity using the "Pre-Flight Checks" commands
3. Fill out and save the "Documented Assumptions Template" as `examples/network-config.example.env`
4. Proceed to [01-inventory-assumptions.md](01-inventory-assumptions.md) for Phase 1

---

**Status**: Prerequisites confirmed. Ready to proceed with Phase 1.
