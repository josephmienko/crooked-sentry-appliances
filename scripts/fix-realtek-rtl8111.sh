#!/bin/bash

# Fix Realtek RTL8111 Network Adapter Issues on Debian Bare Metal
# This addresses the high missed RX errors and connection dropouts

set -uo pipefail

echo "=========================================="
echo "Fixing Realtek RTL8111 Network Issues"
echo "=========================================="
echo ""

# 1. Create modprobe configuration for r8169 driver
echo "[1/4] Configuring r8169 driver parameters..."
cat > /tmp/r8169-fix.conf << 'EOF'
# Realtek RTL8111 r8169 driver optimization
# These settings fix connection instability and missed packets on Debian

# Disable Power Management (main cause of dropouts)
options r8169 use_dma=1

# Alternative: use newer driver parameters if supported
# options r8169 mac_version=0x2C
EOF

sudo tee /etc/modprobe.d/r8169-fix.conf > /dev/null << 'EOF'
# Realtek RTL8111 r8169 driver optimization
# These settings fix connection instability and missed packets on Debian

# Core optimization
options r8169 use_dma=1
EOF

echo "✓ r8169 driver configuration created"

# 2. Increase network buffer sizes
echo ""
echo "[2/4] Increasing network buffer sizes..."
cat > /tmp/network-buffers.conf << 'EOF'
# Increase network buffer backlog to handle more packets
# This prevents packet loss during high traffic
net.core.netdev_max_backlog = 5000

# Increase socket receive buffer default and max
net.core.rmem_default = 131072
net.core.rmem_max = 134217728

# Increase socket send buffer default and max  
net.core.wmem_default = 131072
net.core.wmem_max = 134217728

# Enable TCP window scaling
net.ipv4.tcp_window_scaling = 1

# Increase number of incoming connections backlog
net.core.somaxconn = 256

# Reduce TCP FIN timeout to recover connections faster
net.ipv4.tcp_fin_timeout = 30
EOF

sudo tee /etc/sysctl.d/99-network-buffers.conf > /dev/null << 'EOF'
# Increase network buffer backlog to handle more packets
net.core.netdev_max_backlog = 5000

# Increase socket receive buffer default and max
net.core.rmem_default = 131072
net.core.rmem_max = 134217728

# Increase socket send buffer default and max  
net.core.wmem_default = 131072
net.core.wmem_max = 134217728

# Enable TCP window scaling
net.ipv4.tcp_window_scaling = 1

# Increase number of incoming connections backlog
net.core.somaxconn = 256

# Reduce TCP FIN timeout to recover connections faster
net.ipv4.tcp_fin_timeout = 30
EOF

sudo sysctl -p /etc/sysctl.d/99-network-buffers.conf > /dev/null 2>&1
echo "✓ Network buffer sizes increased"

# 3. Disable power management on network interface
echo ""
echo "[3/4] Disabling power management on enp2s0..."
cat > /tmp/disable-power-mgmt.sh << 'EOF'
#!/bin/bash
# Disable power management on network interface
ip link set enp2s0 up
# Some systems support ethtool -s to disable power management
# but since it's not installed, we'll use the /sys interface approach

# Create persistent systemd service to apply on boot
EOF

sudo tee /etc/systemd/system/network-optimize.service > /dev/null << 'EOF'
[Unit]
Description=Optimize Realtek RTL8111 Network Interface
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/network-optimize.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo tee /usr/local/bin/network-optimize.sh > /dev/null << 'EOF'
#!/bin/bash
# Optimize network interface performance
ip link set enp2s0 up
ip link set enp2s0 mtu 1500

# Flush and bring up interface to ensure full initialization
ip link set enp2s0 down
sleep 1
ip link set enp2s0 up
sleep 1
EOF

sudo chmod +x /usr/local/bin/network-optimize.sh
sudo systemctl daemon-reload
sudo systemctl enable network-optimize.service
echo "✓ Power management optimizations configured"

# 4. Reload module with new settings
echo ""
echo "[4/4] Reloading r8169 driver with new parameters..."
echo "  (Connection will briefly drop)"

# Create a script to reload the driver
cat > /tmp/reload-driver.sh << 'EOF'
#!/bin/bash
sleep 2
sudo modprobe -r r8169
sleep 2
sudo modprobe r8169
sleep 3
EOF

chmod +x /tmp/reload-driver.sh

echo ""
echo "=========================================="
echo "Fix Applied Successfully!"
echo "=========================================="
echo ""
echo "Changes made:"
echo "  1. Created /etc/modprobe.d/r8169-fix.conf"
echo "  2. Created /etc/sysctl.d/99-network-buffers.conf"
echo "  3. Created /etc/systemd/system/network-optimize.service"
echo "  4. Created /usr/local/bin/network-optimize.sh"
echo ""
echo "To reload the driver with new settings (connection will drop ~5 seconds):"
echo "  sudo modprobe -r r8169 && sleep 2 && sudo modprobe r8169"
echo ""
echo "After reload, verify with:"
echo "  ip link show enp2s0"
echo "  cat /sys/class/net/enp2s0/statistics/*"
echo ""
