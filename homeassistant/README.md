# Home Assistant OS Configuration & Documentation

This directory contains Home Assistant configuration notes and snippets for the Raspberry Pi (HA OS) appliance.

**Note**: We do NOT store a full HA configuration dump here. Instead, we document key setup steps, add-on configurations, and integration guides.

**Why not full config?** HA configuration is large, changes frequently, and is handled via the UI. This directory focuses on reproducible setup and integration docs.

## Directory Structure

```
homeassistant/
├── README.md                    # This file
├── add-ons/                     # Add-on configuration guides
│   ├── mosquitto-setup.md       # Mosquitto MQTT add-on setup
│   └── [future-add-ons].md
├── integrations/                # Integration setup guides
│   ├── frigate-integration.md   # Frigate integration steps
│   └── [future-integrations].md
└── automation-examples/         # Automation templates (future)
    └── [example-automations].md
```

## Quick Reference

### SSH into HA OS

```bash
ssh root@192.168.1.10
# or via hostname
ssh root@ha-rpi.local
```

### HA CLI Commands

```bash
# Check HA status
ha core info

# View logs
ha core logs

# Restart HA
ha core restart

# List add-ons
ha addons list
```

### Key HA Directories

Via SSH, HA data is stored in `/config/`:

```bash
ssh root@192.168.1.10
# List config files
ls -la /config/

# Check backups
ls -la /config/backups/

# Edit secrets
nano /config/secrets.yaml

# View automations (if enabled)
cat /config/automations.yaml
```

## Phase 2 Setup Notes

HA OS was installed via Phase 2 with:
- Local owner account (no SSO)
- Timezone configured
- SSH access enabled

See [../docs/02-ha-os-install.md](../docs/02-ha-os-install.md) for full Phase 2 details.

## Add-ons Setup (Phase 4)

### Mosquitto MQTT Broker

See [add-ons/mosquitto-setup.md](add-ons/mosquitto-setup.md) for detailed configuration.

**Quick start**:
1. Settings > Add-ons > Add-on Store > Search "Mosquitto"
2. Install official Community Mosquitto
3. Configure users and start
4. Verify MQTT integration auto-detects

## Integrations Setup (Phase 6+)

### Frigate NVR

See [integrations/frigate-integration.md](integrations/frigate-integration.md) for setup.

**Quick start**:
1. Frigate running on OptiPlex (Phase 5 complete)
2. Settings > Devices & Services > Create Integration > Frigate
3. Enter API URL: `http://192.168.1.20:5000`
4. Verify integration loads

## Future Additions

Once core phases are complete, we may add:
- Custom automations (Phase 8+)
- Dashboard configurations
- Scene setup
- Presence detection
- Notification templates

These will be documented as they're implemented.

## Backups

HA backups are created via the UI (Phase 7):

```bash
# SSH to HA to access backups directly
ssh root@192.168.1.10
ls -la /config/backups/

# Backup location
/config/backups/
```

## Troubleshooting

### HA not responding

```bash
ssh root@192.168.1.10
ha core logs | tail -20
# Check for errors

# Restart if needed
ha core restart
```

### Add-on won't start

```bash
ssh root@192.168.1.10
ha addons list | grep -i [addon-name]
ha addon logs [addon-name]
# Check error messages
```

### Storage full

```bash
ssh root@192.168.1.10
du -sh /config/
df -h /

# Clean old logs/backups if needed
# HA UI: Settings > System > Logs > clear
```

## Documentation References

- **Home Assistant**: https://www.home-assistant.io/
- **HA OS**: https://github.com/home-assistant/operating-system
- **HA CLI**: https://github.com/home-assistant/cli
- **Mosquitto Add-on**: https://github.com/home-assistant/addons/tree/master/mosquitto

---

**Status**: HA OS configuration area. Placeholder for integration guides.
