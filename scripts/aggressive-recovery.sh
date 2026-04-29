#!/bin/bash
# Ultra-Fast OptiPlex Recovery Monitor
# Aggressively monitors and catches brief online windows

set -euo pipefail

REPO_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
RECOVERY_SCRIPT="$REPO_DIR/scripts/optiplex-network-recovery.sh"
SUDO_PASS="MdR2f/0sXZDO5sO4j9mHuXpx"
SSH_KEY="$HOME/.ssh/id_ed25519"
SSH_USER="bossbitch"

MONITOR_DURATION=600  # 10 minutes
START_TIME=$(date +%s)
ATTEMPT_COUNT=0

echo "╔════════════════════════════════════════════════════════╗"
echo "║  AGGRESSIVE OptiPlex Recovery Monitor (Fast Mode)      ║"
echo "║  Checking every 1 second, running recovery FAST        ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Function to check if machine is reachable via SSH
try_ssh() {
    local ip=$1
    if ssh -i "$SSH_KEY" -o ConnectTimeout=2 -o StrictHostKeyChecking=no \
           -o UserKnownHostsFile=/dev/null \
           "$SSH_USER@$ip" "echo 'OK'" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Function to run recovery immediately
run_recovery_fast() {
    local ip=$1
    
    ATTEMPT_COUNT=$((ATTEMPT_COUNT + 1))
    echo ""
    echo "════════════════════════════════════════════════════════"
    echo "🟢 MACHINE DETECTED AT $ip! (Attempt #$ATTEMPT_COUNT)"
    echo "════════════════════════════════════════════════════════"
    echo ""
    echo "[FAST] Transferring recovery script..."
    
    if scp -i "$SSH_KEY" -q -o ConnectTimeout=3 "$RECOVERY_SCRIPT" "$SSH_USER@$ip:/tmp/recovery.sh" 2>/dev/null; then
        echo "✓ Script transferred ($(stat -f%z "$RECOVERY_SCRIPT") bytes)"
        echo ""
        echo "[FAST] Executing recovery (background)..."
        
        # Run recovery in background with timeout
        if timeout 20 bash -c "
            OPTIPLEX_SUDO_PASS='$SUDO_PASS' \
            ssh -i '$SSH_KEY' -o ConnectTimeout=3 \
                '$SSH_USER@$ip' \
                'bash /tmp/recovery.sh 2>&1 | head -50'
        " 2>&1 | head -50; then
            echo ""
            echo "✅ Recovery executed successfully!"
            echo ""
            echo "Waiting 5 seconds for stabilization..."
            sleep 5
            
            # Verify it stuck around
            if try_ssh "$ip"; then
                echo "✅ Machine is STABLE and responding to SSH!"
                echo ""
                echo "Running verification checks..."
                ssh -i "$SSH_KEY" -o ConnectTimeout=3 "$SSH_USER@$ip" \
                    "echo '=== Network Status ==='; ip addr show enp2s0 | grep inet; echo '=== Frigate Status ==='; docker ps -f name=frigate --format '{{.Status}}' 2>/dev/null || echo 'Checking...'"
                
                echo ""
                echo "🎉 RECOVERY COMPLETE - Machine is online and stable!"
                return 0
            else
                echo "⚠️  Machine unstable after recovery, still present though"
                return 1
            fi
        else
            echo "❌ Recovery script failed or timed out"
            return 1
        fi
    else
        echo "❌ Failed to transfer recovery script"
        return 1
    fi
}

# Monitor loop - FAST
while true; do
    ELAPSED=$(($(date +%s) - START_TIME))
    REMAINING=$((MONITOR_DURATION - ELAPSED))
    
    if [[ $REMAINING -le 0 ]]; then
        echo ""
        echo "⏱️  10 minutes elapsed. Monitoring stopped."
        if [[ $ATTEMPT_COUNT -gt 0 ]]; then
            echo "⚠️  Made $ATTEMPT_COUNT recovery attempts but machine keeps dropping"
            echo "Machine is in critical unstable state - needs physical console access"
        else
            echo "❌ Machine never came back online"
        fi
        exit 1
    fi
    
    # Try both IPs rapidly
    if try_ssh "192.168.0.18" 2>/dev/null; then
        if run_recovery_fast "192.168.0.18"; then
            exit 0
        fi
    elif try_ssh "192.168.0.12" 2>/dev/null; then
        if run_recovery_fast "192.168.0.12"; then
            exit 0
        fi
    else
        # Show quick progress
        PERCENT=$((100 * ELAPSED / MONITOR_DURATION))
        printf "\r[%-20s] %3d%% (%ds) Attempts: %d    " \
            "$(printf '#%.0s' $(seq 1 $((PERCENT / 5))))" \
            "$PERCENT" \
            "$REMAINING" \
            "$ATTEMPT_COUNT"
    fi
    
    # Check every 1 second instead of 2
    sleep 1
done
