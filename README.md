# Crooked Sentry Appliances

A clean, phased setup for a Home Assistant appliance infrastructure focused on Raspberry Pi (HA OS) + Dell OptiPlex (Frigate) integration.

## Project Goal

Build a narrowly-focused, production-ready Home Assistant ecosystem with:
- **Primary appliance**: Raspberry Pi running Home Assistant OS
- **Video analytics**: Dell OptiPlex 3080 running Frigate via Docker Compose
- **Connectivity**: MQTT broker (HA Mosquitto add-on preferred) for inter-system communication
- **Simplicity first**: Clean, documented, repeatable steps with no clever automation
- **Future-ready**: Placeholder structure for phased additions (themes, auth, federated access)

## Hardware Assumptions (Phase 1)

| Role | Hardware | OS | Services |
|------|----------|----|----|
| Primary | Raspberry Pi 4B/5 | Home Assistant OS | Home Assistant, Mosquitto add-on |
| Analytics | Dell OptiPlex 3080 | Ubuntu/Debian Linux | Docker, Frigate, supporting services |
| Development | MacBook Pro | macOS | (NOT included in Phase 1) |

## Repo Structure

```
crooked-sentry-appliances/
├── README.md                               # This file
├── docs/
│   ├── setup-phases.md                     # Detailed phase roadmap
│   ├── prerequisites.md                    # Hardware/network assumptions
│   ├── 01-inventory-assumptions.md         # Phase 1 planning checklist
│   ├── 02-ha-os-install.md                 # Phase 2: Raspberry Pi setup
│   ├── 03-optiplex-linux-docker.md         # Phase 3: OptiPlex baseline
│   ├── 04-mqtt-setup.md                    # Phase 4: MQTT broker decision
│   ├── 05-frigate-compose.md               # Phase 5: Frigate Docker setup
│   ├── 06-ha-frigate-integration.md        # Phase 6: HA integration config
│   ├── 07-smoke-tests.md                   # Phase 7: Validation checklist
│   └── FUTURE-08-hacs-themes-branding.md   # Phase 8 placeholder
├── examples/
│   ├── docker-compose-template.yml         # Example Frigate compose file
│   ├── mosquitto-v4-aclfile.example.txt    # MQTT ACL example
│   ├── frigate-config.example.yml           # Minimal Frigate config
│   ├── network-config.example.env           # Network assumptions/template
│   └── ha-secrets-template.yaml             # HA secrets file template
├── scripts/
│   ├── README.md                           # Script usage guide
│   ├── validate-network-connectivity.sh    # Test DNS/IP reachability
│   └── generate-secrets-template.sh        # Helper for secrets generation
├── compose/
│   └── optiplex-frigate/
│       ├── docker-compose.yml              # Frigate + supporting services
│       ├── .env.example                    # Environment template
│       └── README.md                       # Compose-specific notes
├── homeassistant/
│   ├── README.md                           # HA OS configuration notes
│   ├── add-ons/                            # Add-on configuration snippets
│   │   └── mosquitto-setup.md              # Mosquitto add-on config
│   ├── integrations/                       # Integration setup guides
│   │   └── frigate-integration.md          # Frigate integration steps
│   └── automation-examples/                # Future automation snippets
└── .gitignore                              # Secrets and environment files

```

## Quick Start (High Level)

1. **Read**: [prerequisites.md](docs/prerequisites.md) to confirm hardware/network
2. **Plan**: [setup-phases.md](docs/setup-phases.md) overview
3. **Phase 1**: [01-inventory-assumptions.md](docs/01-inventory-assumptions.md) – gather info and validate network
4. **Phase 2**: [02-ha-os-install.md](docs/02-ha-os-install.md) – Raspberry Pi OS setup
5. **Phase 3**: [03-optiplex-linux-docker.md](docs/03-optiplex-linux-docker.md) – OptiPlex Linux + Docker baseline
6. **Phase 4**: [04-mqtt-setup.md](docs/04-mqtt-setup.md) – MQTT broker setup
7. **Phase 5**: [05-frigate-compose.md](docs/05-frigate-compose.md) – Frigate Docker Compose
8. **Phase 6**: [06-ha-frigate-integration.md](docs/06-ha-frigate-integration.md) – HA integration
9. **Phase 7**: [07-smoke-tests.md](docs/07-smoke-tests.md) – Validation checks
10. **Later**: Themes, branding, federated access (documented as placeholders)

## Key Principles

- **No hardcoding**: Secrets, IPs, and hostnames in example files with clear templating
- **Safety first**: Documented assumptions, validation steps after each phase
- **Repeatable**: Prefer documented steps over one-liners or clever scripts
- **Local fallback**: Always keep a local HA owner account (no SSO-only initial setup)
- **Future-ready**: Clear placeholders for future complexity (HACS, themes, auth)

## Future Integrations (Not Phase 1)

These repos will be integrated in later phases:
- `lovelace-m3-core-cards` – Material Design 3 core components
- `lovelace-m3-lighting-dashboard` – M3 lighting UI
- `lovelace-frigate-event-feed` – Frigate event integration
- `ha-material-theme` – Theme system
- `ha-branding-overrides` – Custom branding
- `ha-federated-access` – Federated auth (SSO/OIDC)

## Support & Validation

After each phase, refer to the included validation checklist:
- Network reachability
- Service startup checks
- Integration status verification
- Backup and rollback readiness

See [07-smoke-tests.md](docs/07-smoke-tests.md) for comprehensive validation steps.

## Contributing

When adding to this setup:
1. Keep the phase structure intact
2. Document assumptions (IPs, hostnames, credentials)
3. Provide example config files (never hardcode secrets)
4. Include validation steps
5. Test repeatability

---

**Status**: Phase 1 skeleton created. Ready for inventory and prerequisites review.
