# Phase 4: MQTT Setup

**Duration**: ~30 min – 1 hour  
**Goal**: Deploy a stable MQTT 5.0 broker for inter-appliance messaging between HA and Frigate.

## Decision: Mosquitto Add-on on HA OS

For Phase 1, we use the **Mosquitto add-on** (runs on Raspberry Pi via HA) instead of a separate broker. Advantages:
- Simple installation (via HA add-on store)
- Built-in to HA ecosystem
- No additional hardware/container needed
- Sufficient for single-home setup

**Future consideration**: If you outgrow HA's Mosquitto, migrate to dedicated broker later.

---

## Step 1: Install Mosquitto Add-on on HA OS

1. **SSH or use HA Terminal**:
   ```bash
   ssh root@192.168.1.10
   # or use Settings > System > Terminal in HA UI
   ```

2. **Via HA UI** (easiest):
   - Go to Settings > Add-ons > Add-on Store
   - Search for "Mosquitto" (official HA Community)
   - Click the result from "community" or similar
   - Click **Install**
   - Wait for download and installation (~2–3 min)

3. **Alternative**: Via terminal (if UI not available):
   ```bash
   # Check existing add-ons
   ha addons list
   
   # Install Mosquitto
   ha addon install community_mosquitto
   ```

**Result**: [ ] Mosquitto add-on installed

---

## Step 2: Configure Mosquitto Add-on

After installation, configure the addon settings:

1. **In HA UI**: Settings > Add-ons > Mosquitto Broker
2. **Configuration tab**:
   ```yaml
   logins:
     - username: homeassistant
       password: <your-secure-password>
     - username: frigate
       password: <frigate-password>
   
   require_certificate: false
   certfile: fullchain.pem
   keyfile: privkey.pem
   ```
   - Replace `<your-secure-password>` with a strong password (store in secrets.env)
   - Add frigate user for Phase 5

3. **Optional – Enable ACL** (access control) for security:
   - See examples/mosquitto-v4-aclfile.example.txt
   - Check Mosquitto documentation for ACL format

4. **Click Save** and proceed to next step

**Result**: [ ] Mosquitto configured with users

---

## Step 3: Start Mosquitto Add-on

In HA UI or terminal:

```bash
# Via HA UI: Settings > Add-ons > Mosquitto Broker > Start
# Or via terminal:
ha addon start community_mosquitto
```

Wait for startup message. Check add-on status:

```bash
ha addon info community_mosquitto
# Should show "state": "started" and "healthy": true
```

**Result**: [ ] Mosquitto started and healthy

---

## Step 4: Verify MQTT from HA

Home Assistant should auto-discover the local MQTT broker:

1. Go to Settings > Devices & Services > Integrations
2. Look for **MQTT** (should show up automatically or click Create to add)
3. Verify it shows "Connected"

**Result**: [ ] HA connected to MQTT broker

---

## Step 5: Test MQTT from OptiPlex

Test pub/sub from the Frigate host:

```bash
# SSH to OptiPlex
ssh user@192.168.1.20

# Install MQTT client tools
sudo apt install -y mosquitto-clients

# Test publish
mosquitto_pub -h 192.168.1.10 \
  -u homeassistant \
  -P <your-password> \
  -t test/ping \
  -m "hello from optiplex"

# Test subscribe (from another terminal/session)
mosquitto_sub -h 192.168.1.10 \
  -u homeassistant \
  -P <your-password> \
  -t test/ping
# In another session, publish again – should see message

# Or test bidirectional with verbose output
mosquitto_pub -h 192.168.1.10 \
  -u homeassistant \
  -P <your-password> \
  -v \
  -t test/announce \
  -m "{\"host\": \"optiplex\", \"status\": \"ready\"}"
```

**Expected Output**:
- No connection errors
- Message appears in subscriber session
- Successful pub/sub flow

**Result**: [ ] MQTT connectivity from OptiPlex verified

---

## Step 6: Verify MQTT Broker from HA

In HA, test by publishing a message and observing on OptiPlex:

1. **In HA** – Developer Tools > MQTT:
   - Topic: `test/ha-announce`
   - Payload: `{"status": "online", "timestamp": "now"}`
   - Click **Publish**

2. **On OptiPlex** (in another terminal):
   ```bash
   mosquitto_sub -h 192.168.1.10 \
     -u homeassistant \
     -P <your-password> \
     -t test/# \
     -v
   # Should see message from HA published
   ```

**Result**: [ ] MQTT bridge between HA and OptiPlex verified

---

## Phase 4 Validation Checklist

- [ ] Mosquitto add-on installed on HA OS
- [ ] Mosquitto add-on running and healthy
- [ ] Users configured (homeassistant, frigate)
- [ ] HA MQTT integration connected
- [ ] MQTT client tools installed on OptiPlex
- [ ] Pub/sub from OptiPlex to MQTT broker successful
- [ ] Pub/sub from HA to MQTT broker successful
- [ ] Firewall allows MQTT (port 1883) traffic between appliances

---

## MQTT Port & Settings for Later Phases

| Setting | Value | Notes |
|---------|-------|-------|
| Broker Host | 192.168.1.10 | HA OS / Raspberry Pi |
| Broker Port | 1883 | Standard MQTT (no SSL Phase 1) |
| User (HA) | homeassistant | Default HA user |
| User (Frigate) | frigate | Created for Frigate integration |
| Password | [your password] | Stored in secrets.env |
| Protocol | MQTT 3.1.1 | Mosquitto default |

---

## Troubleshooting Phase 4

### Mosquitto not starting

- Check add-on logs: Settings > Add-ons > Mosquitto > Logs
- Verify YAML syntax in configuration
- Restart add-on: Stop > Wait 5 sec > Start

### Cannot connect from OptiPlex

- Verify firewall allows port 1883: `sudo ufw status` (OptiPlex)
- Test connectivity: `telnet 192.168.1.10 1883` (or `ncat` if telnet unavailable)
- Verify username/password correct
- Check Mosquitto logs in HA for auth errors

### HA MQTT integration not connecting

- Ensure Mosquitto add-on is running
- Restart MQTT integration: Settings > Devices & Services > MQTT > (options menu) > Reload

---

## Next Steps

Phase 4 validation complete? ✅

**Proceed to [05-frigate-compose.md](05-frigate-compose.md) to deploy Frigate with Docker Compose.**

---

**Status**: Phase 4 complete. MQTT broker ready for Phase 5 integration.
