# Mosquitto MQTT Add-on Configuration

This guide covers installing and configuring the Mosquitto MQTT broker add-on on Home Assistant OS (Phase 4).

**Prerequisites**: HA OS up and running (Phase 2 complete)

## Installation

### 1. Via HA UI (Easiest)

1. **Settings > Add-ons > Add-on Store**
2. **Search**: "Mosquitto"
3. **Select**: Official Community version (by community)
4. **Install**
5. Wait for download and installation (~2–3 minutes)

### 2. Via Terminal (Alternative)

```bash
ssh root@192.168.1.10
ha addon install community_mosquitto
```

## Configuration

### 1. Set Users and Passwords

In HA UI: **Settings > Add-ons > Mosquitto Broker > Configuration**

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

**Replace**:
- `<your-secure-password>` with a strong password (Phase 1 secrets.env)
- `<frigate-password>` with Frigate's MQTT password

**Save and proceed to start**.

### 2. Start the Add-on

**Settings > Add-ons > Mosquitto Broker > Start**

Or via terminal:

```bash
ssh root@192.168.1.10
ha addon start community_mosquitto
```

Wait for startup. Should show:

```
1 client(s) connected
```

### 3. Verify Running

```bash
# Via HA UI
Settings > Add-ons > Mosquitto Broker
# Should show status: "Started" and "Healthy"

# Via terminal
ssh root@192.168.1.10
ha addon info community_mosquitto
# Look for "state": "started", "healthy": true
```

## HA Integration Auto-Discovery

HA should automatically discover the local MQTT broker:

1. **Settings > Devices & Services > Integrations**
2. **Look for MQTT** (should appear automatically)
3. **Verify**: Shows "Connected" status

If not auto-discovered:

1. **Create Integration** button
2. **Search**: "MQTT"
3. **Configure**: Broker = localhost (or 127.0.0.1)
4. **Port**: 1883
5. **User/Password**: Leave blank (HA auto-authenticates)

## Testing MQTT

### Test from HA CLI

```bash
ssh root@192.168.1.10

# Publish a test message
mosquitto_pub -h localhost -u homeassistant -P <your-password> \
  -t test/ha \
  -m "Hello from HA"

# Subscribe to test
mosquitto_sub -h localhost -u homeassistant -P <your-password> \
  -t test/#
```

### Test from OptiPlex (Frigate Host)

```bash
ssh user@192.168.1.20

# Install MQTT tools if needed
sudo apt install -y mosquitto-clients

# Publish from OptiPlex
mosquitto_pub -h 192.168.1.10 -u frigate -P <frigate-password> \
  -t frigate/test \
  -m "Hello from Frigate"
```

### Verify Bridge Between HA and OptiPlex

From HA:

```bash
ssh root@192.168.1.10
mosquitto_sub -h localhost -u homeassistant -P <your-password> -t frigate/# -v
```

From OptiPlex (in another terminal):

```bash
ssh user@192.168.1.20
mosquitto_pub -h 192.168.1.10 -u frigate -P <frigate-password> \
  -t frigate/test \
  -m "Message at $(date)"
```

You should see the message in the HA terminal.

## ACL (Access Control List) – Optional

For fine-grained permission control, configure an ACL file:

1. **Create ACL file** on HA:
   ```bash
   ssh root@192.168.1.10
   
   cat > /config/mosquitto/aclfile.txt << 'EOF'
   user homeassistant
   topic readwrite #
   
   user frigate
   topic readwrite frigate/#
   
   # Deny all others
   pattern read $SYS/
   EOF
   ```

2. **Update Configuration**:
   ```yaml
   # In Mosquitto config (HA UI > Configuration)
   aclfile: /config/mosquitto/aclfile.txt
   ```

3. **Restart** add-on after changes

See [../../examples/mosquitto-v4-aclfile.example.txt](../../examples/mosquitto-v4-aclfile.example.txt) for full template.

## Enable Auto-Start

**Settings > Add-ons > Mosquitto Broker > Advanced options**

- **Auto-start**: Enabled (checked)
- **Auto-update**: Optional (checked to auto-update)

Ensures Mosquitto starts automatically after HA restarts.

## Logs & Troubleshooting

### View Mosquitto Logs

**Settings > Add-ons > Mosquitto Broker > Logs**

Or via terminal:

```bash
ssh root@192.168.1.10
ha addon logs community_mosquitto
```

### Common Issues

**Connection refused (port 1883)**:
- Verify add-on is running
- Check firewall allows port 1883 (should be open internally)
- Verify hostname/IP correct (use 192.168.1.10 if mDNS unavailable)

**Auth failed**:
- Verify username/password match configuration
- Check for typos
- Restart add-on after configuration changes

**Add-on crashes on start**:
- Check logs for YAML syntax errors
- Verify ACL file format (if using ACL)
- Revert configuration to defaults and restart

## Reference

- **Mosquitto Add-on**: https://github.com/home-assistant/addons/tree/master/mosquitto
- **MQTT 5.0 Spec**: https://mqtt.org/mqtt-specification-v5-0/
- **Frigate MQTT**: https://docs.frigate.video/configuration/mqtt

---

**Status**: Mosquitto configured and ready for Phase 5 Frigate integration.
