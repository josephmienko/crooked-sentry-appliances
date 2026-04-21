# Phase 1: Inventory & Assumptions

**Duration**: ~30 minutes  
**Goal**: Confirm hardware, network, and software readiness before beginning appliance setup.

## Checklist: Hardware Verification

Use this to formally confirm all required hardware is present and functional.

### Raspberry Pi (Primary Appliance)

- [ ] **Raspberry Pi**:
  - Model: _________________ (4B, 5, or equiv.)
  - RAM: _________________ (4GB+ required)
  - Storage: _________________ (MicroSD card installed?)

- [ ] **Power Supply**:
  - Official RP PSU rated >=2.5A (4B) or >=5A (5)
  - Tested with actual load (Pi boots cleanly)

- [ ] **MicroSD Card**:
  - Size: _________________ GB (32GB+ minimum)
  - Class: _________________ (Class 10, U3 preferred)
  - Brand: _________________ (Sandisk Extreme, Kingston A2, etc.)
  - Readable on your development machine? (Yes / No)

- [ ] **Cooling**:
  - Heatsink/fan installed? (Yes / No / Not needed yet)
  - Tested under idle load? (Yes / No / N/A)

- [ ] **Network**:
  - Ethernet cable ready? (Yes / No)
  - or WiFi dongle ready? (Yes / No)
  - Router/switch has available port? (Yes / No)

- [ ] **Accessories for Initial Setup**:
  - HDMI cable available? (Yes / No)
  - Monitor/TV available? (Yes / No)
  - USB keyboard available? (Yes / No)

### OptiPlex 3080 (Analytics / Frigate Host)

- [ ] **Dell OptiPlex 3080 or Equivalent**:
  - Model/Variant: _________________
  - CPU: _________________ (Intel/AMD x86-64)
  - RAM: _________________ GB (8GB+ recommended)
  - Storage: _________________ GB (SSD or HDD for Docker)

- [ ] **Linux OS**:
  - Installed? (Yes / No)
  - OS Type: _________________ (Ubuntu 22.04 LTS / Debian 12 / Other)
  - Version: _________________
  - Ready for deployment? (Yes / No / Needs reinstall)

- [ ] **Docker & Compose**:
  - Docker installed? (Yes / No)
  - Docker version: _________________
  - Docker Compose installed? (Yes / No)
  - Docker Compose version: _________________
  - Docker daemon operational? (Test: `docker ps` succeeds) (Yes / No)

- [ ] **Network**:
  - Ethernet cable ready? (Yes / No)
  - or WiFi adapter ready? (Yes / No)
  - Connected to local network? (Yes / No)
  - SSH server enabled? (Yes / No)

- [ ] **Storage**:
  - Available disk space: _________________ GB (500GB+ recommended for Frigate)
  - Volume for Docker: _________________ (Mount point or partition)

### Development Machine (MacBook / Linux)

- [ ] **Git**: Installed? (Yes / No) – `git --version` output: _________________
- [ ] **SSH Client**: Available? (Yes / No)
- [ ] **Docker** (optional): Installed? (Yes / No) – For pre-testing
- [ ] **Network Tools**: ping, curl, nslookup available? (Yes / No)
- [ ] **Text Editor**: VS Code, vim, nano, or preferred: _________________

---

## Checklist: Network & Connectivity

### Document Your Network Configuration

Fill in the actual values you'll use. **Do not commit sensitive values** (passwords, keys) – store those separately in a `secrets.env` file (not tracked in git).

#### Primary Appliance (Raspberry Pi + Home Assistant OS)

```txt
HA_RPI_IP=____________________
HA_RPI_HOSTNAME=____________________
HA_RPI_DOMAIN=____________________
HA_RPI_SSH_PORT=____________________
HA_RPI_SSH_USER=____________________
```

**Test**: From your development machine, run:

```bash
ping <HA_RPI_IP>
# Expected: Replies received
ping <HA_RPI_HOSTNAME>.<HA_RPI_DOMAIN>
# Expected: Replies received (if mDNS available)
```

**Result**: [ ] Pass / [ ] Fail – Troubleshoot network if fail

---

#### Analytics Appliance (OptiPlex 3080 + Docker)

```txt
OPTIPLEX_IP=____________________
OPTIPLEX_HOSTNAME=____________________
OPTIPLEX_DOMAIN=____________________
OPTIPLEX_SSH_PORT=____________________
OPTIPLEX_SSH_USER=____________________
```

**Test**: From your development machine:

```bash
ping <OPTIPLEX_IP>
# Expected: Replies received
ssh <OPTIPLEX_SSH_USER>@<OPTIPLEX_IP> "docker ps"
# Expected: Container list (may be empty), no errors
```

**Result**: [ ] Pass / [ ] Fail – Troubleshoot if fail

---

#### MQTT Broker (on Raspberry Pi, via HA add-on)

```txt
MQTT_HOST=<HA_RPI_IP>
MQTT_PORT=1883
MQTT_USER=homeassistant
MQTT_PASSWORD=____________________ # Store in secrets file
```

**Note**: Will test after Phase 4 when add-on is installed.

---

#### Frigate API (on OptiPlex)

```txt
FRIGATE_HOST=<OPTIPLEX_IP>
FRIGATE_API_PORT=5000
FRIGATE_RTSP_PORT=9001
```

**Note**: Will test after Phase 5 when Frigate is deployed.

---

### Network Topology (Diagram for Reference)

```txt
┌─────────────────────────────────────────────────┐
│  Your Local Network                             │
│  (e.g., 192.168.1.0/24)                         │
│                                                  │
│  ┌──────────────────┐    ┌──────────────────┐  │
│  │  Raspberry Pi 4  │    │  Dell OptiPlex   │  │
│  │  (HA OS)         │    │  (Frigate/Linux) │  │
│  │  .10 / ha-rpi   │    │  .20 / optiplex  │  │
│  │                  │    │                  │  │
│  │  Home Assistant  │    │  Docker          │  │
│  │  Mosquitto MQTT  │    │  Frigate         │  │
│  └──────────────────┘    └──────────────────┘  │
│         │                         │             │
│         └─────────┬───────────────┘             │
│                   │                             │
│               Ethernet (preferred)              │
│               or WiFi                           │
│                   │                             │
│            [Router / Switch]                   │
│                   │                             │
│           [Your Development Machine]           │
│           (MacBook Pro - mgmt only)            │
│                                                  │
└─────────────────────────────────────────────────┘
```

---

### Validation Tests (Phase 1 Final Checks)

Run these from your development machine. Document results:

#### Test 1: Ping Both Appliances

```bash
$ ping -c 4 <HA_RPI_IP>
# Expected: 4 packets transmitted, 4 received, 0% packet loss
Result: [ ] Pass / [ ] Fail

$ ping -c 4 <OPTIPLEX_IP>
# Expected: 4 packets transmitted, 4 received, 0% packet loss
Result: [ ] Pass / [ ] Fail
```

#### Test 2: SSH Access to Raspberry Pi

```bash
$ ssh root@<HA_RPI_IP> "uname -a"
# Expected: Output shows Linux arm64 (or armv7l)
Result: [ ] Pass / [ ] Fail – Note any errors:
```

#### Test 3: SSH & Docker Access to OptiPlex

```bash
$ ssh <OPTIPLEX_SSH_USER>@<OPTIPLEX_IP> "docker ps"
# Expected: Container list (may be empty), no error
Result: [ ] Pass / [ ] Fail – Note any errors:
```

#### Test 4: Docker Compose Installation

```bash
$ ssh <OPTIPLEX_SSH_USER>@<OPTIPLEX_IP> "docker compose version"
# Expected: Docker Compose version X.Y.Z+...
Result: [ ] Pass / [ ] Fail – Version output:
```

#### Test 5: DNS/mDNS Resolution (if using hostnames)

```bash
$ nslookup <HA_RPI_HOSTNAME>
# Expected: IP address resolves or mDNS responds
Result: [ ] Pass / [ ] Fail / [ ] N/A

$ nslookup <OPTIPLEX_HOSTNAME>
# Expected: IP address resolves or mDNS responds
Result: [ ] Pass / [ ] Fail / [ ] N/A
```

---

## Phase 1 Assumptions Document

Save this filled-out checklist as a reference. When ready to use it:

1. Copy `examples/network-config.example.env` to your working area:

   ```bash
   cp examples/network-config.example.env my-network-config.env
   ```

2. Fill in your actual IPs and hostnames (from this checklist)

3. Create a **not-checked-in** secrets file for sensitive values:

   ```bash
   # Never commit this file
   cat > secrets.env << 'EOF'
   MQTT_PASSWORD=your_actual_password_here
   HA_ADMIN_PASSWORD=your_admin_password_here
   EOF
   chmod 600 secrets.env
   ```

4. Source both files when needed (during deployment phases):

   ```bash
   source my-network-config.env
   source secrets.env
   ```

---

## Next Steps

All Phase 1 validation checks passed? ✅

**Proceed to [02-ha-os-install.md](02-ha-os-install.md) to begin HA OS setup on Raspberry Pi.**

---

## Troubleshooting Phase 1

### Cannot ping appliances

- Verify they're powered on and connected to the network
- Check router/switch port and cable connections
- Confirm network CIDR (e.g., 192.168.1.x assumes 192.168.1.0/24)
- Try pinging router gateway first to confirm network works

### SSH fails

- Confirm SSH service is running: `sudo systemctl status ssh` (Linux) or check HA Settings > System > Terminal
- Check firewall rules on both machines
- Verify username/port in SSH command
- Try: `ssh -vvv user@host` for debug output

### Docker not found on OptiPlex

- Confirm Docker installation steps were completed
- Try: `sudo docker ps` (may need sudo)
- Relogin after `usermod -aG docker` to apply group membership

### Hostname resolution fails

- Use IP directly if mDNS unavailable (e.g., 192.168.1.10 instead of ha-rpi.local)
- Confirm router/DNS supports mDNS (.local domains)
- On Linux, ensure `avahi-daemon` is running for mDNS
- On macOS, mDNS is built-in and should work automatically

---

**Status**: Phase 1 complete. Ready for Phase 2.
