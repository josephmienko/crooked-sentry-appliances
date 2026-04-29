# Frigate Crash Diagnosis & Resolution

## Root Causes Identified

### 1. **Insufficient Shared Memory (SHM) - Primary Issue**

- **Problem**: Container had only 64MB SHM, but Frigate 0.17+ requires minimum 114MB (recommended 256MB+)
- **Symptom**: Container crashes after 10-30 minutes of operation when processing video frames
- **Fix Applied**: Updated `docker-compose.yml` with `shm_size: 256mb`

### 2. **Invalid Configuration Structure**  

- **Problem**: Config file was written for Frigate 0.13-0.16 format, incompatible with 0.17.1
- **Issues**:
  - `camera` array instead of `cameras` object with named keys
  - Invalid `retention` structure under `record`
  - Multiple extra fields not permitted in current version
- **Symptom**: Config validation errors causing safe mode startup, potential instability
- **Fix Applied**: Updated `config.yml` to valid 0.17.1 format:
  - Renamed `camera:` array → `cameras:` object
  - Restructured camera properties to match schema
  - Simplified record section (removed invalid retention structure)

## Changes Made

### docker-compose.yml

```yaml
# Added line:
shm_size: 256mb
```

### config.yml

**Before (broken 0.13 format):**

```yaml
camera:  # ← Array (wrong for 0.17)
  - name: placeholder_camera
    enabled: false
    # ... nested properties incorrectly placed

record:
  enabled: true
  retention:  # ← Invalid structure for 0.17
    default: 5
    objects:
      person: 14
```

**After (valid 0.17 format):**

```yaml
cameras:  # ← Object with named keys (correct)
  placeholder_camera:
    enabled: false
    # ... properly nested properties

record:
  enabled: true
```

## Verification Results

✅ **Container Status**: Up and healthy (8+ seconds running stable)
✅ **Config Validation**: No errors - clean startup
✅ **API**: Responding successfully to `/api/stats` and `/api/version`
✅ **SHM**: Now 256MB available (previously 64MB)
✅ **Services**: All processes started successfully (Recording, Embedding, Detection, etc.)

## Why It Was Crashing

1. **Frame Buffer Overflow**: With only 64MB SHM and video processing, Frigate would fill shared memory
2. **Out of Memory Errors**: Once SHM full, inter-process communication failed
3. **Container Restart**: Docker's restart policy would restart the container, repeating the cycle
4. **Config Errors**: Invalid config forced safe mode, reducing stability further

## Long-Term Recommendations

1. **Monitor SHM Usage**: 256MB is good for placeholder; scale up when adding real cameras
   - Each HD stream needs ~20-30MB SHM
   - Multi-camera setups may need 512MB+

2. **Update Configuration**: When upgrading Frigate versions, always validate config:

   ```bash
   # Check current config in web UI
   curl http://192.168.0.18:5000/api/config
   ```

3. **Set Proper Restart Policy**: Current `restart: unless-stopped` is correct for production

4. **Add Real Cameras**: Update `cameras` section with actual RTSP URLs when available:

   ```yaml
   cameras:
     front_door:
       enabled: true
       ffmpeg:
         inputs:
           - path: rtsp://user:pass@camera-ip:554/stream
             roles:
               - detect
               - record
   ```

## Current System Status

- **Appliance**: 192.168.0.18 (Debian with Docker)
- **Frigate Version**: 0.17.1-416a9b7
- **Container**: Running healthy ✓
- **MQTT**: Connected to 192.168.0.13:1883 ✓
- **API**: Accessible at <http://192.168.0.18:5000> ✓
