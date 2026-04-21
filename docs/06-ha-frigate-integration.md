# Phase 6: Home Assistant Frigate Integration

**Duration**: ~30 min – 1 hour
**Goal**: Connect Home Assistant to Frigate via the official integration for unified monitoring and automation.

## Overview

The Frigate integration for Home Assistant enables:

- Camera controls and live view
- Object detection statistics and histories
- Event monitoring and notifications
- Automation based on detection events

**Prerequisites**:

- Phase 2 (HA OS) complete
- Phase 5 (Frigate) complete and running
- MQTT bridge working (Phase 4)

---

## Step 1: Add Frigate Integration via HA UI

1. **Log into HA** as owner ([http://192.168.1.10:8123](http://192.168.1.10:8123) or [homeassistant.local:8123](http://homeassistant.local:8123))

2. **Settings > Devices & Services > Create Integration** (or "Integrations" button)

3. **Search** for "Frigate"
   - Select "Frigate" (by blakeblackshear)
   - (Not "Frigate Card" – that's a UI card, comes later)

4. **Enter Frigate Server URL**:

   ```text
   http://192.168.1.20:5000

   (Use the OptiPlex IP or hostname + Frigate API port from Phase 5)

5. **Click Submit**

   Expected: HA discovers Frigate and its configuration

**Result**: [ ] Frigate integration appears in HA

---

## Step 2: Verify Integration Status

1. **Settings > Devices & Services > Integrations**
2. **Look for "Frigate"** – should show:
   - Entity count (cameras, detectors, switches, etc.)
   - Status: "Loaded"
3. **Click Frigate entry** to view:
   - Frigate server name and version
   - Discovered cameras/entities
   - Configuration options

**Result**: [ ] Frigate integration loaded and showing entities

---

## Step 3: Review Discovered Entities

Click **Devices** under Frigate integration to see:

| Entity Type | Expected | Notes |
| --- | --- | --- |
| Camera(s) | placeholder_camera (disabled) | Actual cameras added later |
| Detectors | Various object counts | Person, car, dog, cat detections |
| Switches | Frigate recording toggle | Control Frigate recording on/off |
| Sensor(s) | Event counts, uptime | Statistics and monitoring |

**Result**: [ ] Entities discovered and visible

---

## Step 4: Test API Connection

Verify HA can reach Frigate API:

1. **HA Settings > System > Logs**
2. **Filter** for "frigate"
3. **Look** for connection/discovery messages
4. **Expected**: No connection errors or auth failures

Alternatively, use HA developer tools:

```bash
# Via SSH to HA:
ha core logs | grep -i frigate | tail -20
```

**Result**: [ ] No connection errors in logs

---

## Step 5: Add Frigate Card to Dashboard (Optional)

If you want a custom UI card (not just entity states), install and add:

**Via HACS** (if available in Phase 1):

1. Settings > Add-ons > HACS (if installed)
2. Search "Frigate Card"
3. Install
4. Add to dashboard as card

**Or use built-in HA card** (simpler for Phase 1):

1. Create/Edit dashboard
2. Create Manual Card
3. Select "Entities" or "Picture Elements" layout
4. Add Frigate camera/entity to card

**Result**: [ ] Dashboard card displaying Frigate data (optional)

---

## Step 6: Test Live View

Once a camera is configured (Phase 7 or later):

1. **Dashboard or Frigate integration page**
2. **Click camera entity** to view live stream
3. **Expected**: RTSP stream from Frigate loads
   - May show "Loading" briefly while stream initializes
   - Should show live video (if camera connected to Frigate)

**For Phase 1 (no cameras yet)**: Skip to validation

**Result**: [ ] Live view functional (when cameras added)

---

## Step 7: Test Automations (Optional)

Create a test automation using Frigate events:

1. **Settings > Automations & Scenes > Create Automation > Create New Automation**
2. **Trigger**: Event type
3. **Select**: Frigate object detection events
4. **Action**: Notify or log (simple test)
5. **Test** by saving and monitoring logs

**For Phase 1**: This is optional – cameras needed for real testing

**Result**: [ ] Automation framework verified (optional)

---

## Phase 6 Validation Checklist

- [ ] Frigate integration installed in HA
- [ ] Integration shows "Loaded" status
- [ ] Frigate server URL correctly configured (192.168.1.20:5000)
- [ ] Discovered entities visible (cameras, detectors, sensors, switches)
- [ ] No connection errors in HA logs
- [ ] Live view accessible (when cameras configured)
- [ ] Dashboard can display Frigate data
- [ ] Automations framework verified (optional)

---

## Troubleshooting Phase 6

### Integration fails to connect

- Verify Frigate URL: [192.168.1.20:5000/api/version](http://192.168.1.20:5000/api/version) (from HA terminal)
- Firewall: Ensure port 5000 accessible from HA
- CORS: Some Frigate versions allow/block cross-origin requests
- Restart integration: Settings > Devices & Services > Frigate > (options) > Reload

### Cameras not discovered

- Frigate device list empty? Add cameras to frigate/config/config.yml (Phase 5)
- Restart Frigate: `docker compose restart frigate` on OptiPlex
- Reload HA integration after adding cameras

### Live view not loading

- Firewall: Port 8554 (RTSP) must be accessible
- Network: Check latency and bandwidth to Frigate
- Browser compatibility: Try different browser or clear cache

---

## Next Steps

Phase 6 validation complete? ✅

**Proceed to [07-smoke-tests.md](07-smoke-tests.md) for final validation and backup setup.**

---

**Status**: Phase 6 complete. HA connected to Frigate.
