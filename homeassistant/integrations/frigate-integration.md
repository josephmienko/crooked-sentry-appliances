# Frigate NVR Integration with Home Assistant

This guide covers integrating the Frigate NVR (running on OptiPlex, Phase 5) with Home Assistant OS (Phase 6).

**Prerequisites**:

- Frigate running on OptiPlex (Phase 5 complete)
- MQTT broker configured (Phase 4 complete)
- HA OS up and running (Phase 2 complete)

## Installation

### 1. Add Frigate Integration via HA UI

1. **Log in** to HA as owner ([192.168.1.10:8123](http://192.168.1.10:8123))

2. **Settings > Devices & Services**

3. **Create Integration** (orange button or "Create Integration" dropdown)

4. **Search** for "Frigate"
   - Select "Frigate" (by blakeblackshear)
   - NOT "Frigate Card" (that's a UI component for later)

5. **Enter Configuration**:

   ```text
   Frigate URL: http://192.168.1.20:5000
   ```

   Use the exact OptiPlex IP and Frigate API port from Phase 5.

6. **Submit**
   - HA will discover Frigate and its configuration
   - May take 5–10 seconds

### 2. Verify Integration Loaded

### Settings > Devices & Services > Integrations

Find **Frigate** entry:

- Status should show: **"Loaded"** (green)
- Entity count visible (e.g., "5 devices, 12 entities")

**Click "Frigate"** to expand and see:

- Server name and version
- List of discovered devices/entities
- Configuration options

## Discovered Entities

When Frigate integration loads, HA discovers:

### Devices

| Device | Purpose | Notes |
| --- | --- | --- |
| Cameras | Video input devices | Currently placeholder (disabled in config) |
| Detectors | Object detection models | YOLO, person/car/dog/cat counts |
| Switches | Frigate controls | Recording on/off, detect on/off |
| Sensors | Statistics | Uptime, event counts, FPS |

### Entity Examples

```text
camera.frigate_placeholder_camera
sensor.frigate_cameras_recording_state
sensor.frigate_detections_detected
switch.frigate_record
```

### Access Entities

### Settings > Devices & Services > Entities

Search "frigate" to see all discovered entities. Use these in:

- Automations
- Templates
- Dashboards
- Scripts

## Testing the Integration

### Test 1: API Connectivity

From HA, verify API is reachable:

```bash
ssh root@192.168.1.10
curl -s http://192.168.1.20:5000/api/version | head -20
# Should show JSON with Frigate version
```

### Test 2: Check HA Logs

```bash
ssh root@192.168.1.10
ha core logs | grep -i frigate | tail -20
# Should show integration loading messages, no errors
```

### Test 3: Access Frigate from HA Dashboard

1. Create a new dashboard card
2. Select entity type: Camera
3. Choose Frigate camera (if one exists and is enabled)
4. Add to dashboard

Expected: Live view from Frigate loads.

## Using Frigate Entities in Automations

Example automation triggered by Frigate detection:

```yaml
# Via HA UI: Settings > Automations > Create Automation
# Or via YAML:

automation:
  - alias: Person Detected Front Door
    trigger:
      platform: state
      entity_id: binary_sensor.frigate_front_door_person
      to: "on"
    action:
      service: notify.mobile_app
      data:
        message: "Person detected at front door!"
        data:
          image: "http://192.168.1.20:5000/api/front_door/latest.jpg"
```

## Adding Cameras to Frigate

When you have cameras to integrate:

1. **Edit** `frigate/config/config.yml` on OptiPlex
2. **Add** camera definitions with RTSP URLs
3. **Restart** Frigate: `docker compose restart frigate`
4. **Verify** HA discovers new cameras (no restart needed)
5. **Optional**: Configure Frigate Card (Phase 8+) for UI

## Troubleshooting

### Integration fails to load

**Check HA logs**:

```bash
ssh root@192.168.1.10
ha core logs | tail -50
```

**Common causes**:

- Frigate URL incorrect (must be reachable from HA)
- Firewall blocks port 5000
- Frigate service not running

**Action**:

```bash
# From HA, test Frigate API:
ssh root@192.168.1.10
curl -v http://192.168.1.20:5000/api/version
# Should return 200 OK with JSON

# Check Frigate on OptiPlex:
ssh user@192.168.1.20
docker compose ps | grep frigate
# Should show "Up" status
```

### No cameras discovered

**Cause**: Cameras not in Frigate config or all disabled.

**Solution**:

1. Edit `frigate/config/config.yml` on OptiPlex
2. Add camera with `enabled: true`
3. Restart Frigate: `docker compose restart frigate`
4. In HA, reload integration: Settings > Devices & Services > Frigate > (menu) > Reload

### Live view not loading

**Cause**: RTSP stream port (8554) blocked or camera unavailable.

**Check**:

```bash
# From HA, verify RTSP port reachable
ssh root@192.168.1.10
curl -v telnet://192.168.1.20:8554
# or
nc -zv 192.168.1.20 8554
```

**Firewall**:

```bash
# On OptiPlex, verify port open
sudo ufw status | grep 8554
# If blocked, allow:
sudo ufw allow 8554/tcp
```

### Frigate Card Installation (Phase 8+)

For a custom Frigate UI card, install via HACS (Phase 8):

```txt
HACS > Frontend > Search "Frigate" > Install "frigate-card"
```

Then add to dashboards for advanced controls.

## Integration Reference

| Setting | Value | Notes |
| --- | --- | --- |
| Frigate URL | <http://192.168.1.20:5000> | OptiPlex + API port |
| MQTT | Auto-detected | Connected via Mosquitto add-on |
| Cameras | Discoverable | When added to config.yml |
| Snapshots | Auto-provided | Latest snapshot per camera |

## Next Steps

1. **Add cameras** to Frigate config (when available)
2. **Create automations** based on detection events
3. **Build dashboard** with Frigate data
4. **Install Frigate Card** (Phase 8+) for advanced UI

## References

- **Frigate Integration Docs**: [github.com/blakeblackshear/frigate](https://github.com/blakeblackshear/frigate/blob/master/docs/integrations/home-assistant.md)
- **Frigate NVR**: [frigate.video](https://frigate.video/)
- **Frigate Card**: [github.com/dermotduffy/frigate-card](https://github.com/dermotduffy/frigate-card)

---

**Status**: Frigate integrated with HA. Ready for camera configuration and automations.
