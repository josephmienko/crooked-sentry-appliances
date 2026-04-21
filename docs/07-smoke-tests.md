# Phase 7: Smoke Tests & Backups

**Duration**: ~1 hour  
**Goal**: Validate system operability end-to-end and establish backup/recovery procedures.

## Overview

Smoke tests are quick checks to verify nothing is obviously broken. This phase ensures all Phase 1–6 investments are protected via backups.

**Prerequisites**: 
- Phase 1–6 all complete and validated

---

## Section A: Connectivity & Reachability Tests

### Test 1: Appliance Network Reachability

From development machine:

```bash
# Raspberry Pi (HA)
ping -c 4 192.168.1.10
# Expected: 4 replies, 0% loss

# OptiPlex (Frigate)
ping -c 4 192.168.1.20
# Expected: 4 replies, 0% loss
```

**Result**: [ ] Pass / [ ] Fail

---

### Test 2: HA Web UI

```bash
curl -s http://192.168.1.10:8123 | head -20
# Expected: HTML response from HA UI

# Or visual test:
open http://192.168.1.10:8123
# Expected: Dashboard loads without errors
```

**Result**: [ ] Pass / [ ] Fail

---

### Test 3: Frigate Web UI & API

```bash
curl -s http://192.168.1.20:5000/api/version
# Expected: JSON response with version info

# Visual test:
open http://192.168.1.20:5000
# Expected: Frigate dashboard loads
```

**Result**: [ ] Pass / [ ] Fail

---

### Test 4: MQTT Broker Connectivity

```bash
# From OptiPlex
mosquitto_pub -h 192.168.1.10 -u homeassistant -P <password> \
  -t test/connectivity \
  -m "smoke test $(date)"
# Expected: No error, message published

# From HA (via SSH):
ssh root@192.168.1.10
mosquitto_pub -h localhost -u homeassistant -P <password> \
  -t test/connectivity \
  -m "from HA $(date)"
# Expected: No error
```

**Result**: [ ] Pass / [ ] Fail

---

## Section B: Service Restart Resilience

### Test 5: Frigate Restart

On OptiPlex:

```bash
cd ~/frigate-setup

# Stop Frigate
docker compose stop frigate
sleep 5

# Verify stopped
docker compose ps | grep frigate
# Expected: "Exited" status

# Start Frigate
docker compose start frigate
sleep 10

# Verify running
docker compose ps | grep frigate
# Expected: "Up" status with health (likely "healthy" or "starting")

# Check logs for errors
docker compose logs frigate | tail -20
# Expected: Normal startup messages, no critical errors
```

**Result**: [ ] Pass (Frigate restarts cleanly) / [ ] Fail

---

### Test 6: HA Restart

Via HA UI:

1. **Settings > System > (buttons menu) > Restart Home Assistant**
2. **Wait** 2–3 minutes
3. **Reload** browser after 2 minutes
4. **Verify** HA UI loads and is responsive

Or via SSH:

```bash
ssh root@192.168.1.10
ha core restart
# Wait 2-3 minutes for restart
```

**Result**: [ ] Pass (HA fully restarts) / [ ] Fail

---

### Test 7: Full System Restart (Optional but Recommended)

Power off both appliances:

```bash
# HA restart (via UI as above) or:
ssh root@192.168.1.10 && sudo shutdown -h now

# OptiPlex restart:
ssh user@192.168.1.20 && sudo shutdown -h now
```

Wait 2 minutes, then power on both. Verify:

1. Both appliances boot successfully
2. Network connectivity restored
3. HA reachable and responsive after ~3–5 minutes
4. Frigate running and API responding

**Result**: [ ] Pass (full restart successful) / [ ] Fail

---

## Section C: Service Integration Checks

### Test 8: Frigate Visible in HA Devices

1. **HA Settings > Devices & Services > Integrations**
2. **Find Frigate integration**
3. **Verify**:
   - Shows "Loaded" status
   - Entity count > 0 (at minimum, camera and sensors)
   - No error indicators

**Result**: [ ] Pass / [ ] Fail

---

### Test 9: MQTT Integration in HA

1. **HA Settings > Devices & Services > Integrations**
2. **Find MQTT**
3. **Verify**:
   - Shows "Connected" status
   - No error messages

```bash
# Alternative (via HA SSH):
ha integration info mqtt
# Should show status: "loaded"
```

**Result**: [ ] Pass / [ ] Fail

---

### Test 10: HA System Health

1. **HA Settings > System > System Health**
2. **Review**:
   - All components show green "OK"
   - Database operational
   - Network connectivity good
   - Logs show no persistent errors

**Result**: [ ] Pass / [ ] Fail

---

## Section D: Storage & Resource Checks

### Test 11: HA Storage Status

```bash
ssh root@192.168.1.10

# HA storage info:
ha core info | grep -i storage

# Or check filesystem:
df -h | grep -E "Filesystem|root|boot"
# Expected: > 1 GB free on root partition
```

**HA UI**: Settings > System > Storage also shows usage.

**Result**: [ ] Pass (>1 GB free) / [ ] Fail

---

### Test 12: OptiPlex Disk Space

```bash
ssh user@192.168.1.20
df -h

# Check Frigate recordings directory:
du -sh ~/frigate-setup/frigate/recordings
# Expected: >100 GB available for future recordings
```

**Result**: [ ] Pass (sufficient space) / [ ] Fail

---

## Section E: Backup & Recovery

### Test 13: Create HA Backup

1. **HA Settings > System > Backups**
2. **Click Create Backup**
3. **Wait** for backup completion (~2–5 minutes depending on size)
4. **Verify** backup appears in list with timestamp

**Result**: [ ] Pass (backup created successfully) / [ ] Fail

---

### Test 14: Verify Backup Can Be Restored (Optional)

This is destructive if done incorrectly. **Feel free to skip** if not comfortable.

Only if confident:
1. **Create a second backup** (safety net)
2. **Restore first backup** from the backup list
3. **Verify** HA restarts and settings intact
4. **Re-backup** to ensure data preserved

**Result**: [ ] Pass (backup/restore works) / [ ] Skipped

---

### Test 15: Export OptiPlex Configuration

Create a backup of Frigate config:

```bash
cd ~/frigate-setup

# Tar all important data
tar czf ~/frigate-backup-$(date +%Y%m%d).tar.gz \
  docker-compose.yml \
  .env \
  frigate/config/

# List backup
ls -lh ~/frigate-backup-*.tar.gz

# Verify tar is readable:
tar tzf ~/frigate-backup-$(date +%Y%m%d).tar.gz | head -10
# Should show files inside archive
```

**Store this backup securely** (e.g., copy to NAS or external drive).

**Result**: [ ] Pass (Frigate backup created) / [ ] Fail

---

### Test 16: Document System State

Create a status document:

```bash
cat > deployment-completed-phase7.txt << 'EOF'
=== SYSTEM COMPLETION STATUS ===
Date: $(date)
Time spent: Approximately 8-12 hours total

APPLIANCES:
- Raspberry Pi (HA): $( ssh root@192.168.1.10 uname -a | head -1)
  Hostname: ha-rpi
  IP: 192.168.1.10
  HA Version: [Note from Settings > System > About]
  Storage: [Note storage status]

- Dell OptiPlex (Frigate): $(ssh user@192.168.1.20 uname -a | head -1)
  Hostname: optiplex-frigate
  IP: 192.168.1.20
  Docker: [Note Docker version]
  Storage: [Note available space]

SERVICES:
- Home Assistant OS: Running & Healthy
- Mosquitto Add-on: Running & Connected
- Frigate Docker: Running & Connected via MQTT
- HA Frigate Integration: Loaded

BACKUPS:
- HA Backup: [location/size]
- Frigate Config Backup: [location/size]
- Last tested: [date]

KNOWN ISSUES / NOTES:
[Any workarounds or special configurations]

NEXT PHASE:
Placeholder for future HACS/themes/federated auth

EOF

cat deployment-completed-phase7.txt
```

**Result**: [ ] Status document created

---

## Phase 7 Validation Checklist

**Connectivity**:
- [ ] Raspberry Pi responds to ping
- [ ] OptiPlex responds to ping
- [ ] HA Web UI accessible and responsive
- [ ] Frigate Web UI accessible and responsive
- [ ] MQTT broker reachable from both appliances

**Service Resilience**:
- [ ] Frigate restarts cleanly (no restart loops)
- [ ] HA restarts cleanly and reloads successfully
- [ ] Full system restart successful (both appliances boot)

**Integration Health**:
- [ ] Frigate integration visible and "Loaded" in HA
- [ ] MQTT integration shows "Connected" status
- [ ] System Health shows all components OK
- [ ] No persistent error messages in logs

**Storage**:
- [ ] HA storage > 1 GB free
- [ ] OptiPlex storage > 100 GB available (for recordings)
- [ ] Frigate recordings directory has write access

**Backups**:
- [ ] HA backup created and verified
- [ ] Frigate config backed up and portable
- [ ] System state documented in deployment file

---

## Troubleshooting Phase 7

### Service won't restart

- Check available disk space (`df -h`)
- Review logs for errors
- If persistent, restart the container from scratch (delete and recreate)

### Integration shows errors after restart

- Restart the integration (Settings > Devices & Services > [integration name] > Reload)
- Verify source service (Frigate/MQTT/HA) is running

### Backup creation fails

- Ensure >500 MB free space on HA system
- Check HA logs for database errors
- Try again after 5 minutes (may be temporary lock)

---

## Post-Phase 7: System Ready

Congratulations! Your appliance infrastructure is now **stable and validated**. 

**You can now**:
- Add actual cameras to Frigate
- Build automations in HA
- Deploy custom dashboards
- Plan future phases (HACS, themes, federated auth)

---

## Next Steps (Future Phases)

### Phase 8: HACS & Custom Components (Future)

Integrate split-off repos:
- `lovelace-m3-core-cards`
- `lovelace-m3-lighting-dashboard`
- `lovelace-frigate-event-feed`
- `ha-material-theme`
- `ha-branding-overrides`

### Phase 9: Federated Access (Future)

Add SSO/OIDC via `ha-federated-access` repository (and potentially NetBird for remote access).

---

**Status**: Phase 7 complete. System stable, backed up, and ready for production use.

---

**End of Phase 7. All core appliance setup complete.**
