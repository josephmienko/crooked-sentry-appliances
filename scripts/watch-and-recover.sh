#!/bin/bash
# OptiPlex Auto-Recovery Monitor
# Watches for machine to come back online and runs recovery script automatically

set -euo pipefail

REPO_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
RECOVERY_SCRIPT="$REPO_DIR/scripts/optiplex-network-recovery.sh"
SUDO_PASS="MdR2f/0sXZDO5sO4j9mHuXpx"
SSH_KEY="$HOME/.ssh/id_ed25519"
SSH_USER="bossbitch"

MONITOR_DURATION=600  # 10 minutes
START_TIME=$(date +%s)
MACHINE_IP=""
RECOVERY_RAN=false

echo "╔════════════════════════════════════════════════════════╗"
echo "║  OptiPlex Auto-Recovery Monitor (10 minutes)           ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "Watching for machine at 192.168.0.18 or 192.168.0.12..."
echo "Recovery script: $RECOVERY_SCRIPT"
echo ""

# Function to check if machine is reachable
check_machine() {
    local ip=$1
    timeout 1 ping -c 1 "$ip" >/dev/null 2>&1 && return 0 || return 1
}

# Function to run recovery script
run_recovery() {
    local ip=$1
    
    echo "🟢 Machine detected at $ip!"
    echo ""
    echo "Transferring recovery script..."
    
    if scp -i "$SSH_KEY" -q "$RECOVERY_SCRIPT" "$SSH_USER@$ip:/tmp/optiplex-recovery.sh" 2>/dev/null; then
        echo "✓ Script transferred"
        echo ""
        echo "Running recovery script on $ip..."
        echo "(This may take 10-15 seconds)"
        echo ""
        
        if OPTIPLEX_SUDO_PASS="$SUDO_PASS" \
           ssh -i "$SSH_KEY" -o ConnectTimeout=5 \
               "$SSH_USER@$ip" \
               "bash /tmp/optiplex-recovery.sh" 2>&1; then
            echo ""
            echo "✅ Recovery script completed successfully!"
            RECOVERY_RAN=true
            return 0
        else
            echo ""
            echo "⚠️  Recovery script encountered an error"
            return 1
        fi
    else
        echo "❌ Failed to transfer script"
        return 1
    fi
}

# Monitor loop
while true; do
    ELAPSED=$(($(date +%s) - START_TIME))
    REMAINING=$((MONITOR_DURATION - ELAPSED))
    
    if [[ $REMAINING -le 0 ]]; then
        echo ""
        echo "⏱️  10 minutes elapsed. Monitoring stopped."
        if [[ "$RECOVERY_RAN" == "true" ]]; then
            echo "✅ Recovery was successful!"
            exit 0
        else
            echo "❌ Machine did not come back online during monitoring window"
            exit 1
        fi
    fi
    
    # Check both IPs
    if check_machine "192.168.0.18"; then
        MACHINE_IP="192.168.0.18"
        if run_recovery "$MACHINE_IP"; then
            sleep 5
            echo ""
            echo "Verifying machine is stable..."
            if check_machine "$MACHINE_IP"; then
                echo "✓ Machine is stable and responding"
                exit 0
            fi
        fi
    elif check_machine "192.168.0.12"; then
        MACHINE_IP="192.168.0.12"
        if run_recovery "$MACHINE_IP"; then
            sleep 5
            echo ""
            echo "Verifying machine is stable..."
            # Try to find where it migrated to
            if check_machine "192.168.0.18"; then
                echo "✓ Machine migrated to .18 and is stable"
                exit 0
            elif check_machine "192.168.0.12"; then
                echo "✓ Machine is stable at .12"
                exit 0
            fi
        fi
    else
        # Show progress bar
        PERCENT=$((100 * ELAPSED / MONITOR_DURATION))
        BARS=$((PERCENT / 5))
        printf "\r[%-20s] %3d%% (%ds remaining)   " \
            "$(printf '#%.0s' $(seq 1 $BARS))" \
            "$PERCENT" \
            "$REMAINING"
    fi
    
    sleep 2
done
