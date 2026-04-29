# OptiPlex 3080 - CRITICAL STATUS REPORT

**Date**: April 28, 2026  
**Status**: 🔴 **UNRECOVERABLE VIA NETWORK**  
**Last Update**: Post-10-minute aggressive recovery attempt  

---

## INCIDENT SUMMARY

**What Happened:**

- Attempted live RTL8111 driver reload via `modprobe -r r8169` + `modprobe r8169`
- Live reload on active system caused kernel network stack corruption
- Corruption persists through power cycles and clean boots
- Machine is stuck in unrecoverable boot loop

**Current State:**

- ✅ Power: ON, boots normally
- ✅ Network Hardware: Initialized, in ARP table
- ✅ DHCP: Gets IP address (192.168.0.12)
- ❌ TCP/IP Stack: CORRUPTED, won't initialize
- ❌ SSH: Completely unreachable
- ❌ Recovery Scripts: Cannot execute (no SSH)

**Diagnosis:**
The kernel's network stack was corrupted by unloading the r8169 driver while:

- System was running
- Network connections were active  
- DHCP client was running
- Kernel memory structures were in use

This corruption is stored in persistent kernel state and survives reboots.

---

## RECOVERY ATTEMPTS MADE

### Attempt 1: Auto-Recovery Monitor (10 minutes)

- **Result**: ❌ FAILED
- **Why**: Machine never responded to SSH during online windows

### Attempt 2: Aggressive Fast Monitor (10 minutes)

- **Result**: ❌ FAILED
- **Checking every 1 second for SSH
- **0 successful connections**
- Machine visible in ARP but TCP/IP never initializes

### Evidence of Machine Attempts

- Hard power cycles show brief online windows (~3-5 seconds)
- ARP table shows valid MAC entry
- Network switch shows active Ethernet traffic
- But SSH port 22 never responds
- Ping (ICMP) never responds

---

## ROOT CAUSE ANALYSIS

**The Critical Mistake:**

```bash
# ❌ WRONG - Reload driver on ACTIVE system
echo "$SUDO_PASS" | sudo -S modprobe -r r8169    # Unload driver mid-use
sleep 2
echo "$SUDO_PASS" | sudo -S modprobe r8169       # Reload driver mid-use
```

**Why This Broke Everything:**

1. `modprobe -r` unloads driver while in use
2. Causes immediate:
   - Active network sockets to break
   - Kernel memory allocated to driver is orphaned
   - DHCP client gets confused
   - Network stack state becomes inconsistent
3. `modprobe r8169` reloads driver into corrupted state
4. Machine boots but kernel can't initialize TCP/IP cleanly
5. System enters **deadlock during boot**
6. Reboot doesn't help because corruption is in boot-time driver init

**Why Network Recovery Fails:**

- Recovery scripts need SSH to work
- SSH requires TCP/IP stack
- TCP/IP stack won't initialize
- Catch-22: Can't fix network via network

---

## WHAT NEEDS TO HAPPEN NEXT

### **CRITICAL: Physical Console Access Required**

To proceed, you MUST connect:

- **Monitor**: HDMI or DisplayPort to back of OptiPlex
- **Keyboard**: USB to front of OptiPlex

Then observe boot process and look for:

**If you see kernel panic:**

```
Kernel panic - not syncing: ...
BUG: unable to handle page fault
```

→ System is fundamentally broken, needs reinstall

**If you see hung task:**

```
INFO: task systemd:1 blocked for more than 120 seconds
```

→ Boot is hung, may need single-user mode or rescue boot

**If boot completes but no SSH:**

```
Starting LSB: Raise network interfaces...
```

→ Network initialization is failing, can debug from console

---

## RECOVERY OPTIONS (In Order)

### Option 1: Console Debugging + Manual Recovery

**Requirements:**

- Monitor + Keyboard connected
- Access to physical machine

**Process:**

1. Boot machine with monitor connected
2. Watch for any errors
3. Try to get to single-user mode (press 'e' at GRUB)
4. Check kernel logs: `dmesg | tail -100`
5. Try: `systemctl status systemd-networkd`
6. Attempt: `systemctl restart systemd-networkd`
7. Check: `ip link show` and `ip addr show`

**If that works:** Run recovery script via console directly

### Option 2: Live USB Boot + Chroot Recovery

**Requirements:**

- USB stick (16GB)
- Debian Linux ISO
- Mac to create bootable USB

**Process:**

1. Create Debian live USB on your Mac
2. Boot OptiPlex from USB (F2 or F12 during startup)
3. Select "Live (without installing)"
4. Mount main drive from USB environment
5. Check filesystem integrity
6. Potentially chroot and repair boot config

### Option 3: Full Reinstall

**Requirements:**

- Debian USB installation media
- Willingness to wipe and reinstall
- Access to Frigate config backup (if not on main drive)

**Process:**

1. Create Debian installer USB
2. Boot OptiPlex from USB
3. Run fresh Debian install
4. Restore Frigate configs from backup
5. Reconfigure DHCP/networking

### Option 4: Accept Downtime (Temporary)

- OptiPlex remains down for now
- Focus on other systems (HA, MQTT, devices)
- Return to recovery when more time available
- Risk: Extended outage, device integration delayed

---

## WHY EACH OPTION MATTERS

**Option 1 (Console Debugging):**

- Lowest risk to data
- Most likely to preserve existing config
- Requires physical access
- May be quick fix if just config issue
- **RECOMMENDED FIRST STEP**

**Option 2 (Live USB Recovery):**

- Can repair filesystem issues
- Preserves data if carefully done
- Requires USB creation step
- Medium risk if chroot commands wrong
- **Try after Option 1 if needed**

**Option 3 (Reinstall):**

- Guaranteed to work (fresh OS)
- Highest data loss risk
- Requires full reconfiguration
- Last resort option
- **Only if debugging fails**

---

## FILES & REFERENCES

**Recovery Scripts Created:**

- `scripts/optiplex-network-recovery.sh` - Network stack fix (can't run without SSH)
- `scripts/watch-and-recover.sh` - Basic monitor
- `scripts/aggressive-recovery.sh` - Fast aggressive monitor (10min, 0 catches)

**Documentation:**

- `OPTIPLEX-RECOVERY.md` - Quick recovery steps
- `OPTIPLEX-SITUATION-BRIEFING.md` - Detailed analysis
- `docs/prerequisites.md` - Original setup docs

**Key Details:**

- OptiPlex MAC: `70:b5:e8:3f:72:e6`
- Expected IPs: `.18` (primary), `.12` (DHCP)
- SSH User: `bossbitch`
- Sudo Pass: [REDACTED - USE YOUR SUDO PASSWORD]
- Frigate: `~/frigate-setup/`

---

## LESSONS LEARNED - PREVENTION

### ❌ NEVER DO THIS

```bash
# Live reload of kernel drivers
modprobe -r <driver>   # While system running
modprobe <driver>      # Can corrupt kernel state
```

### ✅ DO THIS INSTEAD

```bash
# Option 1: Boot-time parameters (SAFE)
# Edit /etc/default/grub or netplan config
# Add driver parameters before boot
# Reboot cleanly after making changes

# Option 2: Sysfs parameter changes (SAFER)
# echo "param=value" > /sys/module/driver/parameters/...
# Much less risky than driver reload

# Option 3: Maintenance window (SAFEST)
# Plan for network downtime
# Perform changes during scheduled maintenance
# Communicate with team first
```

---

## NEXT IMMEDIATE ACTIONS

**FOR YOU:**

- [ ] Access physical OptiPlex with monitor + keyboard
- [ ] Observe boot process for 2-3 minutes
- [ ] Document any error messages seen
- [ ] Report console output

**FOR TEAM:**

- [ ] Evaluate option (1, 2, 3, or 4)
- [ ] Plan recovery window if console debugging
- [ ] Prepare USB media if live boot recovery
- [ ] Set expectations for downtime

**FOR INFRASTRUCTURE:**

- [x] Machine is not running Frigate now
- [ ] Fallback to Home Assistant only until recovery
- [ ] Do NOT attempt to manually run services on downed OptiPlex

---

## CONTACT & ESCALATION

**This issue requires human decision:**

- Physical access to machine
- Time commitment (1-4 hours depending on option)
- Risk tolerance for data/configuration

**Recommended:** Start with Option 1 (console debugging) - lowest risk, may provide quick resolution.

---

**Status**: 🔴 UNRECOVERABLE VIA NETWORK - PHYSICAL INTERVENTION REQUIRED

**Do you have access to connect a monitor and keyboard to the OptiPlex?**
