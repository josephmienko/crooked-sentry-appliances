# OptiPlex Network Recovery - Situation Briefing for Monitor Agent

**Date**: April 28, 2026  
**Status**: CRITICAL - Machine Deadlocked  
**Last Update**: 2026-04-28 [Current Time]

---

## Executive Summary

The OptiPlex 3080 (Frigate NVR host) is **partially offline** - network interface is active and responding at ARP level, but the OS kernel is completely unresponsive to SSH, ping, or ICMP. This occurred after attempting a live `modprobe -r r8169` / `modprobe r8169` driver reload on an active system.

**Critical Finding**: The NIC is UP and actively communicating (confirmed by network switch flashing lights), but the Linux kernel network stack is **frozen/deadlocked**.

---

## Timeline of Events

### 2026-04-28 [Prior Time]

- ✅ Frigate NVR stable at 192.168.0.18
- ✅ RTL8111 network adapter showing high RX errors (71,058 rx_missed_errors)
- 📝 Decision: Apply driver optimization by reloading r8169 module with tuned parameters

### 2026-04-28 [~1 hour ago]

- 🔴 **CRITICAL**: Executed live `modprobe -r r8169` + `modprobe r8169` on active system
- 🔴 SSH command appeared to complete, but network immediately became unstable
- Machine showed brief availability at 192.168.0.12, then disappeared
- Attempted IP ping sweep: All responses timeout

### 2026-04-28 [Current]

- 🟡 **Partially Online**: Machine appears in ARP table with valid MAC
- 🔴 **Unresponsive**: No ping, no SSH, no ICMP reply, but network lights active
- 🟡 **Evidence of Bootup**: Brief appearance at .12 suggests machine is trying to boot

---

## Current State - Evidence

### Network Evidence

**ARP Table Verification** (Mac host - en1 interface):

```
192.168.0.12 → 70:b5:e8:3f:72:e6 [OptiPlex MAC]  ✓ RESPONDING IN ARP
```

**Connectivity Tests**:

- ❌ `ping -c 3 192.168.0.12` → 100% packet loss, no responses
- ❌ `ssh -o ConnectTimeout=8 bossbitch@192.168.0.12` → Connection timeout (no RST, no ACK)
- ❌ `nc -zv 192.168.0.12 22` → Timeout (port not responding)
- ✅ Network switch port lights FLASHING (active Ethernet traffic)
- ✅ Machine has valid DHCP assignment (per ARP table)

**Diagnosis**:

- NIC driver working (lights active, in ARP table)
- Kernel network stack deadlocked (no responses to any network requests)
- OS possibly hung during boot sequence

---

## What Went Wrong

### Root Cause: Live Driver Reload on Active System

**The problematic command sequence:**

```bash
echo "$SUDO_PASS" | sudo -S modprobe -r r8169     # Remove driver
sleep 2
echo "$SUDO_PASS" | sudo -S modprobe r8169        # Reload driver
```

**Why this failed:**

1. `modprobe -r` on **running system** unloaded the driver mid-operation
2. This caused:
   - Active SSH session to drop
   - Network stack state corruption
   - DHCP client likely in undefined state
   - Kernel memory leaks in network subsystem
3. `modprobe r8169` reloaded driver, but kernel network stack was already corrupted
4. Machine rebooted during unstable state (watchdog timer?)
5. Boot sequence now hung trying to bring up network with corrupted driver state

**Why the machine shows in ARP:**

- DHCP client got a lease assignment (.12) during boot
- ARP reply for gratuitous DHCP announcement still working
- But higher-level network stack (TCP/IP) is frozen

---

## Attempted Recovery Actions

### Action 1: Auto-Recovery Monitor (10 minutes)

- **Result**: ❌ FAILED
- **Reason**: Machine appeared in ARP but never responded to SSH
- **Evidence**: Watcher ran to completion, machine never became SSH-accessible

### Action 2: Network Scan

- **Result**: ⚠️ PARTIAL SUCCESS
- **Finding**: Machine visible in ARP table, confirming presence and valid MAC
- **Limitation**: Only ARP responses working, TCP/IP stack frozen

### Action 3: Direct SSH Attempt

- **Result**: ❌ FAILED
- **Reason**: Timeout (no TCP ACK, likely kernel not responding to interrupts)

---

## Physical State

**What We Know**:

- ✅ Machine powered on (LEDs lit, fans running)
- ✅ Network interface UP and communicating at Layer 2 (ARP working)
- ✅ DHCP client obtained IP address (192.168.0.12)
- ❌ Kernel not responding to interrupts/network requests (Layer 3+)
- ❓ Monitor/console output unknown (no display connected for observation)

**Network Hardware Status**:

- ✅ Ethernet port lights: FLASHING (active, not dead)
- ✅ Switch port connected to OptiPlex: FLASHING (receiving traffic)
- ✅ ARP communications working
- ❌ TCP/IP stack frozen

---

## Possible States (In Order of Likelihood)

### 1. **MOST LIKELY**: Kernel Network Stack Deadlock

- Symptoms: ARP responses but no TCP/IP
- Cause: modprobe -r while network in use corrupted driver state
- Evidence: ARP table entry, flashing lights, SSH timeout (not refused)
- Recovery: Hard power cycle (cold boot from discharged state)

### 2. **POSSIBLE**: Kernel Hung Task

- Symptoms: Bootup hung, watchdog triggered, but partial responses
- Cause: Network driver initialization loop
- Evidence: Brief appearances on network, then disappears
- Recovery: Force complete power drain (30 second unplug)

### 3. **POSSIBLE**: DHCP Client Loop

- Symptoms: Network stack working but boot incomplete
- Cause: DHCP client stuck requesting same IP repeatedly
- Evidence: Gets IP in ARP, never fully boots
- Recovery: Hard reset with DHCP lease flush

### 4. **UNLIKELY**: Kernel Panic

- Symptoms: Would not appear in ARP table at all
- Current evidence rules this out

---

## Recovery Strategy

### Immediate Action: Hard Power Cycle

**This is the ONLY remaining network-based recovery option.**

```bash
Physical Actions at OptiPlex:
1. Locate power cable (back of machine)
2. Unplug completely from wall power
3. Wait 30 seconds (full capacitor discharge)
4. Hold power button for 10 seconds (additional discharge)
5. Plug power cable back in
6. Press power button to start
7. Wait 60 seconds for boot completion
```

**Rationale**:

- Cold boot clears corrupted driver state from kernel memory
- Full power drain resets all hardware including NIC firmware
- Clean boot sequence should avoid deadlock state
- ARP presence shows hardware is OK, just software stack corrupted

### Post-Recovery Actions (Once Online)

If machine comes back:

```bash
# 1. Verify connectivity
ping -c 3 192.168.0.18

# 2. SSH and check network health
ssh -i ~/.ssh/id_ed25519 bossbitch@192.168.0.18 "
  echo 'Checking network status...'
  ip link show enp2s0
  ip addr show enp2s0
  dmesg | tail -20
  systemctl status systemd-networkd
  cat /sys/class/net/enp2s0/statistics/rx_errors
"

# 3. Run recovery script if needed
OPTIPLEX_SUDO_PASS="YOUR_SUDO_PASSWORD" \
  bash scripts/optiplex-network-recovery.sh

# 4. Verify Frigate
docker ps -f name=frigate --format '{{.Status}}'
```

### If Hard Reset Fails

If machine still won't respond after hard power cycle:

**Required**: Physical console access

```bash
Actions:
1. Connect HDMI monitor to back of OptiPlex
2. Connect USB keyboard/mouse
3. Power on and observe boot process
4. Document any:
   - Kernel panic messages
   - Hung task warnings
   - BIOS/firmware errors
   - Stuck boot screens
5. Report console output for analysis
```

**Alternative**: Force network boot or USB recovery media (requires BIOS access)

---

## Prevention - Lessons Learned

### ❌ DO NOT DO THIS AGAIN

```bash
# DO NOT reload drivers on active system:
modprobe -r r8169  # WRONG! Corrupts state
modprobe r8169
```

### ✅ DO THIS INSTEAD

```bash
# Option 1: Set parameters in boot config
# Edit /etc/default/grub or netplan config
# Set r8169 parameters at boot time
# Reboot cleanly

# Option 2: Use sysfs at runtime (safer)
# echo "options" > /sys/module/r8169/parameters/...

# Option 3: Plan for planned reboot
# Make config changes
# Schedule graceful shutdown during maintenance window
```

---

## Monitoring Agent Tasks

### Immediate (Next 1-2 minutes)

- [ ] Alert operator to perform hard power cycle (unplug 30s)
- [ ] Set up continuous monitoring for machine to reappear

### Short-term (Next 10 minutes after power cycle)

- [ ] Watch ARP table for MAC 70:b5:e8:3f:72:e6
- [ ] Once ARP shows activity, attempt SSH
- [ ] If SSH succeeds, verify Frigate operational
- [ ] Run health checks and log results

### Medium-term (If hard reset fails)

- [ ] Escalate to console access requirement
- [ ] Document any error messages
- [ ] Consider USB recovery boot if available

### Long-term

- [ ] Review why modprobe -r was attempted on active system
- [ ] Update runbooks to prevent this scenario
- [ ] Consider monitoring for network stack instability
- [ ] Set up alerts for "in ARP but not SSH-able" state

---

## Key Contacts & Resources

**OptiPlex Details**:

- Model: Dell OptiPlex 3080
- NIC: Realtek RTL8111
- Driver: r8169 (Linux)
- MAC: 70:b5:e8:3f:72:e6
- Expected IP: 192.168.0.18 (primary) / 192.168.0.12 (DHCP fallback)
- Credentials: bossbitch / [REDACTED - USE YOUR SUDO PASSWORD]

**Frigate Service**:

- Port: 5000
- Docker compose location: ~/frigate-setup
- Config: ~/frigate-setup/frigate/config/config.yml

**Recovery Scripts**:

- Location: `scripts/optiplex-network-recovery.sh`
- Location: `scripts/watch-and-recover.sh`

---

## Current Action Items

**BLOCKING**: Perform hard power cycle

- [ ] Unplug OptiPlex power for 30 seconds
- [ ] Power on and wait 60 seconds
- [ ] Report status

**CONTINGENT**: If comes back online

- [ ] Run SSH health check
- [ ] Verify Frigate running
- [ ] Check network statistics

**CONTINGENT**: If still down after hard reset

- [ ] Connect physical monitor/keyboard
- [ ] Document boot errors
- [ ] Evaluate USB recovery or reinstall
