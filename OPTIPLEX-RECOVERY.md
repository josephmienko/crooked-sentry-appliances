# OptiPlex Network Recovery - Quick Steps

**Status**: Machine is offline after RTL8111 driver reload. Need hard power cycle.

## Phase 1: Hard Power Cycle

```bash
# At the OptiPlex physically:

1. Unplug power cable from back of machine
   (Wait 10 seconds for capacitors to fully discharge)

2. Plug power cable back in

3. Press power button to turn on

4. Machine will boot and attempt DHCP
```

## Phase 2: Catch and Recover

**Watch for the machine to appear on network** (using your Mac):

```bash
# Terminal on Mac: Monitor for machine to come back
watch -n 0.5 'ping -c 1 192.168.0.18 2>/dev/null && echo "✓ UP at .18" || ping -c 1 192.168.0.12 2>/dev/null && echo "✓ UP at .12" || echo "Down"'
```

## Phase 3: Run Recovery Script

**Once machine appears online (even briefly), run:**

```bash
# Copy recovery script to machine
scp -i ~/.ssh/id_ed25519 \
  ~/crooked-sentry-appliances/scripts/optiplex-network-recovery.sh \
  bossbitch@192.168.0.12:/tmp/ 2>/dev/null || \
scp -i ~/.ssh/id_ed25519 \
  ~/crooked-sentry-appliances/scripts/optiplex-network-recovery.sh \
  bossbitch@192.168.0.18:/tmp/

# SSH and run it
OPTIPLEX_SUDO_PASS="MdR2f/0sXZDO5sO4j9mHuXpx" \
  ssh -i ~/.ssh/id_ed25519 bossbitch@192.168.0.12 \
  "bash /tmp/optiplex-network-recovery.sh"

# Or if at .18:
OPTIPLEX_SUDO_PASS="MdR2f/0sXZDO5sO4j9mHuXpx" \
  ssh -i ~/.ssh/id_ed25519 bossbitch@192.168.0.18 \
  "bash /tmp/optiplex-network-recovery.sh"
```

## Phase 4: Verify

```bash
# Verify network is stable
ping -c 10 192.168.0.18

# Check Frigate
ssh -i ~/.ssh/id_ed25519 bossbitch@192.168.0.18 \
  "docker ps -f name=frigate --format '{{.Status}}'"

# Check network stats
ssh -i ~/.ssh/id_ed25519 bossbitch@192.168.0.18 \
  "cat /sys/class/net/enp2s0/statistics/rx_errors"
```

## What the Recovery Script Does

1. Stops systemd-networkd (network service)
2. Unloads r8169 driver module completely
3. Reloads driver with clean state
4. Restarts network service
5. Verifies interface is back up

---

**Important**: The r8169 live reload was a bad idea. In future:
- ✅ Set driver parameters at boot time (grub/netplan)
- ❌ Don't reload drivers on active systems without recovery plan
- ✅ If changes needed, plan for clean reboot instead
