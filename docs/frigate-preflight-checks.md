# Frigate Preflight Checks

**Purpose**: Verify system readiness before deploying Frigate container.  
**When to use**: Before Phase 5 (Frigate Docker Compose).  
**Duration**: ~15 minutes  
**Owner**: Manual runbook (not automated).

---

## Prerequisites

- Phase 3 (OptiPlex Linux + Docker) complete
- SSH access to OptiPlex
- Docker and Docker Compose installed (`docker --version` and `docker compose --version`)
- Phase 4 (MQTT setup) complete if planning MQTT integration

---

## Preflight Checklist

### 1. Storage & Disk Space

**Why**: Frigate stores video recordings and must have adequate free space.

**Check disk space**:

```bash
ssh ubuntu@192.168.1.20  # or your OptiPlex user/IP

# Check available disk space on root and data partitions
df -h

# Check available space on /mnt (if Frigate recordings mount there)
df -h /mnt
```

**Expected**:

- At least 500GB free on the partition where `./frigate/recordings` will live
- If using `/mnt/frigate-recordings`, ensure it's mounted and writable

**If space is insufficient**:

- Add external USB/NAS storage and mount to `/mnt/frigate-recordings`
- Use symbolic links: `ln -s /mnt/frigate-recordings ./frigate/recordings`
- Document storage path in `.env` file for future reference

**Result**: [ ] At least 500GB free on recording storage path

---

### 2. Recording Storage Directory

**Why**: Frigate needs pre-created, writable directories before starting.

**Create directories**:

```bash
cd /path/to/compose/optiplex-frigate
mkdir -p ./frigate/{config,recordings,cache}
chmod 755 ./frigate
ls -la ./frigate/
```

**Expected output**:

```
total 0
drwxr-xr-x   config
drwxr-xr-x   recordings
drwxr-xr-x   cache
```

**If using external mount**:

```bash
mkdir -p /mnt/frigate-recordings
sudo chown $USER:$USER /mnt/frigate-recordings
chmod 755 /mnt/frigate-recordings
```

**Result**: [ ] Directories exist with correct permissions (755)

---

### 3. Docker Compose Validation

**Why**: Ensures required environment variables are set and `.env` syntax is correct.

**Validate compose file**:

```bash
cd /path/to/compose/optiplex-frigate

# Test with .env.example (should FAIL due to empty required secrets)
docker compose --env-file .env.example config 2>&1 | head -20
# Expected FAILURE: "ERROR: Invalid interpolation format for..."
#   (This confirms required-secret syntax is working correctly)

# Create a valid test .env with dummy secrets
cp .env.example .env.test
sed -i 's/MQTT_PASSWORD=$/MQTT_PASSWORD=test_mqtt_pass_123/' .env.test
sed -i 's/FRIGATE_RTSP_PASSWORD=$/FRIGATE_RTSP_PASSWORD=test_rtsp_pass_456/' .env.test

# Now validation should PASS
docker compose --env-file .env.test config > /dev/null && echo "✓ Compose syntax valid"

# Clean up test file
rm .env.test
```

**Expected**:

- With `.env.example`: FAIL with clear error about missing required variables
- With real `.env`: PASS (generates valid Docker Compose config)

**Result**: [ ] Compose file syntax is valid and required-secret checks work

---

### 4. MQTT Connectivity & Credentials

**Why**: Frigate needs to publish events to MQTT broker for HA integration.

**Test MQTT connectivity**:

```bash
# From OptiPlex, test connection to MQTT broker on HA (192.168.1.10)
# Using mosquitto_sub client (part of mosquitto-clients package)

ssh ubuntu@192.168.1.20

# Check if mosquitto_sub is available
which mosquitto_sub
# If not found, install: sudo apt-get install mosquitto-clients

# Test connection (replace with your actual HA IP and MQTT user/password from Phase 4)
mosquitto_sub -h 192.168.1.10 -p 1883 -u frigate -P "your_mqtt_password" -t "test" -W 2
# Should connect and wait for messages (press Ctrl+C to exit)
# If timeout or connection refused, MQTT is not accessible from OptiPlex
```

**Expected**:

- Connection succeeds and waits for messages
- No "Connection refused" or timeout errors

**If MQTT is not accessible**:

- Verify MQTT broker is running on HA: `mosquitto -v` or check HA add-on status
- Verify network connectivity: `ping 192.168.1.10` from OptiPlex
- Check firewall rules on HA: ensure port 1883 is open (default MQTT port)
- Verify credentials match what was set in Phase 4

**Result**: [ ] MQTT broker is reachable and credentials are correct

---

### 5. Frigate Config YAML Syntax

**Why**: Invalid Frigate config will cause container startup to fail.

**Validate Frigate config** (if present):

```bash
cd /path/to/compose/optiplex-frigate

# Option 1: PyYAML validation (requires 'python3 -c' and PyYAML library)
if [ -f ./frigate/config/config.yml ]; then
  python3 -c 'import yaml, sys; yaml.safe_load(open(sys.argv[1]))' ./frigate/config/config.yml && echo "✓ YAML syntax valid" || echo "✗ YAML syntax error"
fi
# Note: If PyYAML is not installed, install with: python3 -m pip install --user pyyaml

# Option 2: If PyYAML is unavailable, use Frigate Docker to validate
# (This performs full Frigate config validation)
if [ -f ./frigate/config/config.yml ]; then
  docker run --rm -v "$(pwd)/frigate/config:/config" ghcr.io/blakeblackshear/frigate:stable frigate -c /config/config.yml --check-config > /dev/null 2>&1 && echo "✓ Frigate config valid" || echo "✗ Frigate config error"
fi

# Option 3: If neither Python nor Docker is available, defer validation to container startup
# (Errors will appear in 'docker compose logs frigate' if config is invalid)
```

**Expected**:

- No YAML parsing errors
- Frigate config loads without syntax issues

**Prerequisites**:

- **Option 1**: Python 3 with PyYAML (`pip install pyyaml`)
- **Option 2**: Docker CLI (`docker` command available)
- **Option 3**: No prerequisites; validation deferred to container startup

**Note**: Full config validation happens during container startup. If there are errors, they will appear in `docker compose logs frigate`.

**Result**: [ ] Frigate config YAML syntax is valid (or deferred to container startup)

---

### 6. Network Firewall / Port Allowlist

**Why**: Cameras and HA need to reach Frigate API and RTSP proxy ports.

**Required ports** (documented; **not automated**):

| Port | Service | Direction | Source | Purpose |
|------|---------|-----------|--------|---------|
| 5000 (default) | Frigate API | Inbound | HA appliance (192.168.1.10) | HA add-on integration |
| 8554 (default) | Frigate RTSP proxy | Inbound | IP cameras (network) | Camera stream proxy |
| 8555 | Frigate live stream | Inbound | Any | Browser live view |
| 8556 | Go2rtc API | Inbound | Any | Stream management |

**To verify/configure firewall**:

```bash
ssh ubuntu@192.168.1.20

# Check current firewall status
sudo ufw status
# If UFW is active:
#   Status: active

# Allow Frigate API from HA appliance
sudo ufw allow from 192.168.1.10 to any port 5000/tcp comment "Frigate API from HA"

# Allow RTSP proxy from any (cameras will connect)
sudo ufw allow 8554/tcp comment "Frigate RTSP proxy"
sudo ufw allow 8554/udp comment "Frigate RTSP proxy"

# Allow live stream / Go2rtc (optional, for remote access)
sudo ufw allow 8555/tcp comment "Frigate live stream"
sudo ufw allow 8556/tcp comment "Go2rtc API"

# Verify rules are applied
sudo ufw status numbered
```

**If UFW is not active**:

- Skip firewall configuration for now (or configure using iptables/firewalld if needed)
- Network must be trusted (private network assumed)

**Result**: [ ] Firewall rules are configured or network is trusted

---

## Summary Checklist

Before proceeding to Phase 5 (Frigate Docker Compose), verify:

- [ ] At least 500GB free disk space for recordings
- [ ] `./frigate/{config,recordings,cache}` directories created (755 permissions)
- [ ] Docker Compose syntax is valid (required-secret checks working)
- [ ] MQTT broker is reachable from OptiPlex with correct credentials
- [ ] Frigate config YAML syntax is valid (if present)
- [ ] Firewall rules allow Frigate ports (or network is trusted)

**If all checks pass**: You are ready to proceed with Phase 5.

**If any check fails**: Review the troubleshooting section above and resolve before proceeding.

---

## Troubleshooting

| Problem | Cause | Solution |
|---------|-------|----------|
| Disk space insufficient | Too many recordings or small partition | Add external storage or configure retention policy in Frigate config |
| MQTT unreachable | Network connectivity or firewall | Check HA network, MQTT port 1883 open, credentials correct |
| Compose validation fails | Missing `.env` or required secrets | Copy `.env.example` to `.env` and fill in real values |
| Frigate won't start | YAML config syntax error | Check `docker compose logs frigate` for error details |
| Cameras can't connect to proxy | Port 8554 blocked by firewall | Add UFW rule: `sudo ufw allow 8554` |

---

## Next Steps

Once all preflight checks pass, proceed to **Phase 5: Frigate Docker Compose** to deploy Frigate and integrate with HA.
