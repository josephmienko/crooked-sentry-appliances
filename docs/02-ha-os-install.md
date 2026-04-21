# Phase 2: Home Assistant OS Install (Raspberry Pi)

**Duration**: ~1–2 hours  
**Goal**: Spin up a functional Home Assistant OS instance on the Raspberry Pi with network access and initial configuration.

## Overview

Home Assistant OS is a purpose-built appliance image that runs on Raspberry Pi (and other supported boards). It includes Docker, Home Assistant Core, and a supervisor for add-on management.

**Prerequisites**:

- Phase 1 (Inventory & Assumptions) completed
- MicroSD card inserted into development machine (USB reader)
- Raspberry Pi offline and powered down

---

## Step 1: Download Home Assistant OS Image

1. **Visit** [home-assistant.io/download](https://www.home-assistant.io/download/) and select **Raspberry Pi**
2. Choose your board version:
   - **Raspberry Pi 4** (64-bit) – ARM v8/aarch64
   - **Raspberry Pi 5** (64-bit) – ARM v8/aarch64
   - Other: CM4, Zero 2 W (choose accordingly)
3. Click **Download** – saves `ha-rpi-x.y.img.gz` (~900 MB)
4. Verify checksum if provided (optional but recommended):

   ```bash
   sha256sum ha-rpi-x.y.img.gz
   # Compare against published checksum on download page
   ```

**Result**: [ ] Image file downloaded and checksum verified (if applicable)

---

## Step 2: Flash MicroSD Card

You'll write the HA OS image to your MicroSD card using one of these tools:

### Option A: Raspberry Pi Imager (Recommended)

**macOS / Linux / Windows**: [raspberrypi.com/software](https://www.raspberrypi.com/software/)

1. Install **Raspberry Pi Imager**
2. Insert MicroSD card into USB reader
3. Open Imager and:
   - **Choose Device**: Select your Raspberry Pi model
   - **Choose OS**: "Other general-purpose OS" → "Home Assistant" → Select your image file
   - **Choose Storage**: Select MicroSD card (double-check you have the right drive!)
   - Click **Next** and confirm you're writing to the SD card
4. Wait for write and verify to complete (~10–15 minutes)
5. Eject the card when done

**Result**: [ ] MicroSD card successfully flashed

### Option B: balena Etcher (Alternative)

1. Download from [balena.io/etcher](https://www.balena.io/etcher/)
2. Install and open
3. **Flash from file**: Select `ha-rpi-x.y.img.gz`
4. **Select target**: Choose your MicroSD card
5. **Flash**: Click and wait for verification
6. Eject when done

**Result**: [ ] MicroSD card successfully flashed

---

## Step 3: Prepare Raspberry Pi

1. **Remove MicroSD card** from development machine
2. **Eject properly**:
   - macOS: Drag to Trash or use `umount` command
   - Linux: `umount /media/<your-cards>` or use file manager
3. **Insert MicroSD card** into Raspberry Pi (small slot, usually on bottom)
4. **Connect network**:
   - Preferred: Ethernet cable directly to router or switch
   - Alternative: Ensure WiFi adapter (USB dongle) is plugged in
5. **Connect power**: Use official RP PSU (2.5A for Pi4, 5A for Pi5)
   - **Do not use generic USB chargers** – can cause stability issues
6. **Allow first boot** – wait 5–10 minutes while system initializes

**During first boot, the Pi will**:

- Resize filesystem
- Initialize container runtime
- Set up network
- Start Home Assistant
- Generate logs and configs

**Status**: [ ] Powered on and waiting for first boot (~10 min)

---

## Step 4: Access Home Assistant UI

The Raspberry Pi will obtain an IP via DHCP (your router manages this).

### Option A: Via Hostname (Preferred if mDNS Available)

```bash
open http://homeassistant.local:8123
# or if using custom hostname from Phase 1:
open http://ha-rpi.local:8123
```

### Option B: Via Direct IP

If hostname doesn't resolve, find the Pi's IP:

```bash
# From your router admin page, or:
arp-scan -l  # Linux/macOS (requires arp-scan utility)
# or check your router's connected devices list

# Or ping to discover:
nmap -sn 192.168.1.0/24 | grep -A 5 "Raspberry"
```

Once you have the IP (e.g., 192.168.1.10):

```bash
open http://192.168.1.10:8123
```

### Expected First Boot UI

You should see:

- Home Assistant loading screen
- After ~2-3 min: "Getting things ready" onboarding prompt
- After ~5 min: Onboarding form appears

**Status**: [ ] HA UI reachable and onboarding form visible

---

## Step 5: Complete Home Assistant Onboarding

### 5.1 Create Local Owner Account

⚠️ **IMPORTANT**: Use a **local account only** for Phase 1. Do NOT use SSO/Google/GitHub login yet (that's Phase 9).

1. **Name**: Pick a display name (e.g., "Home Admin")
2. **Username**: Create a username (e.g., `homeadmin` or your name)
3. **Password**: Set a strong password
   - Save this securely in your secrets.env file
   - This is your fallback account – **keep it local**
4. Click **Create Account**

**Result**: [ ] Local owner account created and confirmed

### 5.2 Set Location & Timezone

1. **Name** (optional): Your home or location name
2. **Location**: Lat/Long (used for sun position, weather integrations)
   - Easy way: Search for "my coordinates" on Google Maps, copy Lat/Long
   - Or enter city name and select from suggestions
3. **Timezone**: Select from dropdown (e.g., America/Chicago)
4. Click **Next**

**Result**: [ ] Location and timezone configured

### 5.3 Share Diagnostics (Optional)

Home Assistant prompts you to share analytics. Choose:

- **Share**: Helps HA developers improve the system
- **Don't share**: Opt out

**Result**: [ ] Choice made (either way is fine)

### 5.4 Select Add-ons (Skip for Now)

You'll be offered quick add-ons (MariaDB, ESPHome, etc.). **Skip** these – we'll add them as needed in later phases.

**Result**: [ ] Skipped add-ons or added only what you need

### 5.5 Create Your First Automation (Optional)

HA may offer a quick tour. Skip or complete – both fine for Phase 2.

**Result**: [ ] Onboarding completed

---

## Step 6: Verify HA Health

After onboarding, you should see the Home Assistant dashboard. Validate:

1. **Settings > System > Storage**:
   - Verify adequate free space (>1 GB free minimum)
   - If low, HA may not function correctly
   - Result: [ ] Storage healthy

2. **Settings > System > System Health**:
   - Should show "OK" status
   - Look for network connectivity, database status, etc.
   - Result: [ ] System Health = OK

3. **Back up log** for reference:
   - Settings > System > Logs tab
   - Screenshot or copy to note
   - Should not show errors during onboarding
   - Result: [ ] Logs reviewed (no critical errors)

4. **Test restart** (optional but recommended):
   - Settings > System > Restart Home Assistant
   - Wait ~2 minutes
   - Reload browser
   - Should reconnect successfully
   - Result: [ ] Restart successful

---

## Step 7: Enable SSH Access (Optional but Recommended)

SSH access allows you to manage HA from the command line later (useful for debugging).

### 7.1 Via Settings

1. Go to Settings > System > Terminal & SSH
2. Click **Enable SSH**
3. Choose SSH port (default 22 is fine)
4. Click **Start**

### 7.2 Test SSH Access

From your development machine:

```bash
ssh root@192.168.1.10
# or
ssh root@ha-rpi.local
```

You may be prompted for a password (HA generates one initially). Once logged in, test:

```bash
ha core logs   # Show HA logs from CLI
docker ps      # List running containers
df -h          # Show disk usage
```

**Result**: [ ] SSH access functional (optional)

---

## Step 8: Document Your Setup

Create a file `deployment-notes-phase2.txt` or similar:

```text
=== PHASE 2 COMPLETION ===
Date: YYYY-MM-DD
HA Version: [from Settings > System > About]
Board: [Raspberry Pi 4 / 5 / other]
SD Card: [Brand, size]
Hostname: ha-rpi
IP Address: 192.168.1.10
Username: [your username]
Timezone: [your timezone]
Location: [coordinates or city]
Storage Status: [OK / warning]

Notes/Issues:
[Any problems encountered during onboarding]
[Custom firewall rules if applicable]
[Anything else relevant for future reference]
```

**Store this with Phase 1 documentation.**

---

## Phase 2 Validation Checklist

- [ ] HA OS flashed and Raspberry Pi powered on
- [ ] HA UI reachable via hostname or IP
- [ ] Onboarding completed with local owner account created
- [ ] Location and timezone set
- [ ] System Health shows "OK" status
- [ ] Storage has adequate free space (>1 GB)
- [ ] Logs reviewed for critical errors
- [ ] SSH access functional (optional)
- [ ] Restart successful (if tested)

---

## Troubleshooting Phase 2

### HA UI Not Reachable

**Check 1**: Is the Raspberry Pi powered on?

- Look for green LED activity
- Wait full 10 minutes on first boot

**Check 2**: Network connectivity

```bash
ping 192.168.1.10
# If no response, Raspberry Pi may not have network
```

**Check 3**: Is the SD card properly flashed?

- Eject and reinsert to reseat
- Try re-flashing if errors persist

**Check 4**: Try hostname vs. IP

```bash
ping homeassistant.local vs. ping 192.168.1.10
# One may work while other doesn't (mDNS availability)
```

### Onboarding Hangs or Errors

- Refresh browser (Ctrl+Shift+R or Cmd+Shift+R)
- Wait another 5 minutes for system initialization
- Check HA logs for errors (Settings > System > Logs)

### Cannot SSH After Enabling

- Verify SSH is enabled (Settings > System > Terminal & SSH shows "Active")
- Confirm firewall allows port 22 (or custom SSH port)
- Try: `ssh -vvv root@192.168.1.10` for debug output

### Storage Warning

- HA needs at least 1 GB free
- Some tasks (like backups) may fail with low storage
- Consider upgrading SD card if < 500 MB free
- Delete old logs: Settings > System > Logs > (options menu)

### Restart Loop or Crashes

- Check System > System Health for errors
- View logs for crash messages
- Allow 2–3 minutes before concluding HA is crashed
- Power cycle Raspberry Pi if stuck:

  ```bash
  ssh root@ha-rpi.local
  sudo systemctl reboot
  ```

---

## Next Steps

Phase 2 validation complete? ✅

**Proceed to [03-optiplex-linux-docker.md](03-optiplex-linux-docker.md) to prepare the OptiPlex as a Docker host.**

---

**Status**: Phase 2 complete. HA OS running and reachable.
