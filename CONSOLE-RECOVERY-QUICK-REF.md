# OptiPlex Network Recovery - Console Commands

**Quick Reference for Console Recovery**

---

## LOGIN

```
Username: bossbitch
Password: [USE YOUR SUDO PASSWORD - NOT COMMITTED TO REPO]
```

---

## NETWORK RECOVERY STEPS

### Step 1: Check Interface Status

```bash
ip link show enp2s0
```

Expected output should show: `UP` or `DOWN`

### Step 2: Check Current IP

```bash
ip addr show enp2s0
```

Look for: `inet 192.168.0.XX/24`

### Step 3: Restart Networking

```bash
sudo systemctl restart systemd-networkd
```

Wait 3 seconds, then check:

```bash
ip addr show enp2s0
```

### Step 4: Test Internet Connectivity

```bash
ping 8.8.8.8
```

Press Ctrl+C after 3-4 pings. Should see responses.

### Step 5: Check SSH Service

```bash
sudo systemctl status ssh
```

Should say: `active (running)`

If not running:

```bash
sudo systemctl restart ssh
```

### Step 6: Verify SSH Port

```bash
sudo ss -tlnp | grep 22
```

Should show SSH listening on port 22

---

## FULL RECOVERY SCRIPT (Copy & Paste All)

```bash
echo "=== Network Recovery ===" && \
echo "" && \
echo "Step 1: Interface Status" && \
ip link show enp2s0 && \
echo "" && \
echo "Step 2: Current IP" && \
ip addr show enp2s0 && \
echo "" && \
echo "Step 3: Restarting Network..." && \
sudo systemctl restart systemd-networkd && \
sleep 3 && \
echo "Step 4: IP After Restart" && \
ip addr show enp2s0 && \
echo "" && \
echo "Step 5: Testing Internet" && \
ping -c 3 8.8.8.8 && \
echo "" && \
echo "Step 6: SSH Status" && \
sudo systemctl status ssh && \
echo "" && \
echo "Step 7: SSH Port Check" && \
sudo ss -tlnp | grep 22 && \
echo "" && \
echo "✓ Recovery Complete!"
```

---

## DOCKER STATUS (After SSH Works)

From your Mac, run:

```bash
ssh -i ~/.ssh/id_ed25519 bossbitch@192.168.0.18 "docker ps -f name=frigate --format '{{.Status}}'"
```

---

## EMERGENCY: Reload R8169 Driver Cleanly

If network still not working after above steps:

```bash
# Unload driver cleanly
sudo modprobe -r r8169
sleep 2

# Reload driver
sudo modprobe r8169
sleep 3

# Restart networking
sudo systemctl restart systemd-networkd
sleep 3

# Check status
ip addr show enp2s0
```

---

## TROUBLESHOOTING

**If no IP address appears:**

```bash
# Check DHCP client logs
journalctl -u systemd-networkd -n 50

# Check interface details
ip link show
ip addr show

# Force DHCP renewal
sudo systemctl restart systemd-networkd
sleep 3
ip addr show
```

**If still no IP:**

```bash
# Check Netplan config
sudo cat /etc/netplan/*.yaml

# Manually request DHCP
sudo dhclient enp2s0
```

**If SSH won't connect even with IP:**

```bash
# Check SSH is running
sudo systemctl status ssh

# Restart SSH
sudo systemctl restart ssh

# Check SSH is listening
sudo ss -tlnp | grep ssh

# Tail SSH logs
sudo journalctl -u ssh -n 20
```

---

## QUICK CHECKLIST

- [ ] Login: `bossbitch` / [USE YOUR SUDO PASSWORD]
- [ ] Check interface: `ip link show enp2s0`
- [ ] Check IP: `ip addr show enp2s0`
- [ ] Restart network: `sudo systemctl restart systemd-networkd`
- [ ] Test ping: `ping -c 3 8.8.8.8`
- [ ] Check SSH: `sudo systemctl status ssh`
- [ ] SSH port listening: `sudo ss -tlnp | grep 22`

Once all green:

- [ ] From Mac: `ssh -i ~/.ssh/id_ed25519 bossbitch@192.168.0.18`
- [ ] Verify Frigate: `docker ps -f name=frigate`
- [ ] Done!

---

## MACHINE INFO

- **Hostname**: bossbitch (or similar)
- **IP (Expected)**: 192.168.0.18 (or .12)
- **Interface**: enp2s0 (Realtek RTL8111)
- **Driver**: r8169
- **Frigate Location**: ~/frigate-setup/

---

**Last Updated**: April 29, 2026
