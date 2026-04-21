# Phase 3: OptiPlex Linux + Docker Baseline

**Duration**: ~1–2 hours  
**Goal**: Prepare the Dell OptiPlex as a stable, containerized Docker host for Frigate and related services.

## Overview

The OptiPlex will run Frigate (NVR) and supporting services via Docker Compose. This phase ensures the OS is updated, Docker is installed, and the system is ready for container workloads.

**Prerequisites**:

- Phase 1 (Inventory & Assumptions) completed
- OptiPlex has Linux OS (Ubuntu 22.04 LTS or Debian 12 preferred)
- Network connectivity confirmed from Phase 1

---

## Step 1: Verify Linux OS

SSH into the OptiPlex and confirm the OS:

```bash
ssh user@192.168.1.20
# or
ssh user@optiplex-frigate.local
```

Check the system:

```bash
uname -a
# Expected: Linux optiplex-frigate x86-64

cat /etc/os-release
# Expected: Ubuntu 22.04 or Debian 12, or similar
```

**Result**: [ ] OS confirmed (Ubuntu 22.04 LTS or Debian 12)

### If OS is not Linux or is outdated

**Option A**: Clean install from USB media

- Download Ubuntu 22.04 LTS ISO from [releases.ubuntu.com](https://releases.ubuntu.com/)
- Flash to USB using Etcher or similar
- Boot OptiPlex from USB and follow installer
- After install, SSH and verify with commands above

**Option B**: Upgrade existing OS (if already Linux)

```bash
sudo apt update
sudo apt dist-upgrade -y
sudo reboot
```

**Result**: [ ] Operating system ready

---

## Step 2: Update System Packages

Ensure all system packages are current:

```bash
sudo apt update
sudo apt upgrade -y
```

This may take 5–10 minutes. Allow to complete.

**Result**: [ ] System packages updated

---

## Step 3: Install Docker Engine

Follow the official Docker installation for your OS:

### Ubuntu 22.04 LTS (Recommended)

```bash
# Remove old Docker versions (if any)
sudo apt remove docker docker.io containerd runc

# Set up Docker repository
sudo apt install -y ca-certificates curl gnupg lsb-release
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### Debian 12 (Alternative)

```bash
# Similar steps; use Debian repo instead:
# See: https://docs.docker.com/engine/install/debian/
```

**Result**: [ ] Docker packages installed

---

## Step 4: Verify Docker Installation

```bash
docker --version
# Expected: Docker version 24.0 or later

docker compose version
# Expected: Docker Compose version 2.20 or later
```

If `docker compose` fails, try:

```bash
docker-compose --version
# Older v1 syntax; upgrade recommended but Phase 5 will adjust
```

**Result**: [ ] Docker and Docker Compose verified

---

## Step 5: Add User to Docker Group (Optional but Recommended)

Allows non-root users to run Docker commands (improves convenience):

```bash
sudo usermod -aG docker $USER
newgrp docker
```

Test without `sudo`:

```bash
docker ps
# Expected: Empty container list or existing containers, no permission error
```

**Result**: [ ] User added to docker group (or accepting sudo requirement)

---

## Step 6: Test Docker Functionality

Run the Hello World container:

```bash
docker run hello-world
# Expected: Hello message confirming Docker is working
```

**Result**: [ ] Docker daemon functional

---

## Step 7: Configure Docker Daemon (Optional but Recommended)

Create or update `/etc/docker/daemon.json` for better stability:

```bash
sudo tee /etc/docker/daemon.json > /dev/null << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "live-restore": true,
  "metrics-addr": "127.0.0.1:9323",
  "experimental": false
}
EOF
```

Restart Docker to apply:

```bash
sudo systemctl restart docker
docker ps
# Should still work after restart
```

**Result**: [ ] Docker daemon configured for stability

---

## Step 8: Set System Hostname

Ensures easy network identification:

```bash
hostnamectl status
# Current hostname shown

sudo hostnamectl set-hostname optiplex-frigate
# May need to reload shell for change to take effect:
exec bash
```

Verify:

```bash
hostname
# Expected: optiplex-frigate
```

**Result**: [ ] Hostname configured

---

## Step 9: Enable SSH and Verify Access

SSH should be pre-installed on most Linux systems. Verify:

```bash
sudo systemctl status ssh
# Expected: active (running)
```

If not running:

```bash
sudo systemctl enable ssh
sudo systemctl start ssh
```

Test SSH from your development machine:

```bash
ssh user@192.168.1.20 "echo 'SSH working'"
# Expected: "SSH working" output
```

**Result**: [ ] SSH access confirmed

---

## Step 10: Create Docker Volumes and Directories

Prepare directory structure for Frigate:

```bash
mkdir -p ~/frigate-setup
mkdir -p ~/frigate-setup/frigate/config
mkdir -p ~/frigate-setup/frigate/recordings
mkdir -p ~/frigate-setup/frigate/cache

cd ~/frigate-setup
ls -la
# Expected: Three directories visible
```

**Result**: [ ] Frigate directories created

---

## Step 11: Optional – Enable UFW Firewall

If using Ubuntu's Uncomplicated Firewall:

```bash
# Check status
sudo ufw status

# If inactive and you want to enable:
sudo ufw allow ssh
sudo ufw allow 5000/tcp    # Frigate API
sudo ufw allow 9001/tcp    # Frigate RTSP proxy
sudo ufw allow 8883/tcp    # MQTT SSL (optional for later)
sudo ufw enable
```

Then verify:

```bash
curl http://localhost:5000/api/version
# Will fail at this point (Frigate not running yet), but shows port is reachable
```

**Result**: [ ] Firewall configured (optional) or skipped

---

## Phase 3 Validation Checklist

- [ ] Linux OS is Ubuntu 22.04 LTS or Debian 12 (x86-64)
- [ ] System packages updated
- [ ] Docker Engine 24.0+ installed
- [ ] Docker Compose v2.20+ installed
- [ ] `docker ps` works without errors
- [ ] Hello World container ran successfully
- [ ] Docker daemon configured for resource limits and logging
- [ ] Hostname set to "optiplex-frigate"
- [ ] SSH access functional from development machine
- [ ] Frigate directories created at ~/frigate-setup

---

## Troubleshooting Phase 3

### Docker Command Not Found

- Verify installation: `apt list --installed | grep docker`
- Retry installation following steps above
- Reboot and try again: `sudo reboot`

### Permission Denied Running Docker (after usermod)

- Log out and log back in to activate group membership
- Or: `newgrp docker` to activate in current shell
- Or use `sudo docker` if not adding user to group

### Docker Daemon Crashes on Startup

- Check logs: `sudo journalctl -u docker -n 50`
- Verify daemon.json syntax: `sudo jsonlint /etc/docker/daemon.json`
- Revert daemon.json if syntax error, restart Docker

### Cannot Resolve Hostname

- Use IP directly if DNS unavailable
- For mDNS (.local), ensure system is on same subnet and mDNS is available
- Hostname will be used internally by Docker Compose; IP works fine too

---

## Next Steps

Phase 3 validation complete? ✅

**Proceed to [04-mqtt-setup.md](04-mqtt-setup.md) to set up the MQTT broker.**

---

**Status**: Phase 3 complete. OptiPlex ready for Docker workloads.
