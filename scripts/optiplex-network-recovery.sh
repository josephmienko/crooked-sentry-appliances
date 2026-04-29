#!/bin/bash
# Emergency Network Recovery for OptiPlex RTL8111 Driver Issue
# Use this if the machine boots but network is unstable/flapping

set -euo pipefail

SUDO_PASS="${OPTIPLEX_SUDO_PASS:-}"

if [[ -z "$SUDO_PASS" ]]; then
    echo "ERROR: OPTIPLEX_SUDO_PASS not set"
    echo "Usage: OPTIPLEX_SUDO_PASS='password' $0"
    exit 1
fi

echo "=== OptiPlex Network Recovery ==="
echo ""

# Step 1: Stop network service
echo "[1/5] Stopping network service..."
echo "$SUDO_PASS" | sudo -S systemctl stop systemd-networkd 2>/dev/null || true
sleep 2

# Step 2: Unload driver
echo "[2/5] Unloading r8169 driver..."
echo "$SUDO_PASS" | sudo -S modprobe -r r8169 2>/dev/null || true
sleep 3

# Step 3: Clear driver state
echo "[3/5] Clearing driver state..."
echo "$SUDO_PASS" | sudo -S rmmod r8169 2>/dev/null || true
sleep 2

# Step 4: Reload driver
echo "[4/5] Reloading r8169 driver..."
echo "$SUDO_PASS" | sudo -S modprobe r8169
sleep 3

# Step 5: Restart network
echo "[5/5] Restarting network service..."
echo "$SUDO_PASS" | sudo -S systemctl restart systemd-networkd
sleep 3

echo ""
echo "=== Verifying Network Status ==="
ip link show enp2s0
echo ""
echo "=== IP Address ==="
ip addr show enp2s0 | grep "inet "
echo ""
echo "✓ Recovery complete"
