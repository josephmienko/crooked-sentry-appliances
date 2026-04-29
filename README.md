<h1><a href="https://josephmienko.github.io/crooked-sentry-appliances/">crooked-sentry-appliances</a></h1>
<picture align="center">
  <!-- Desktop Dark Mode -->
  <source media="(min-width: 769px) and (prefers-color-scheme: dark)" srcset="assets/header-wide-dark-inline.svg">
  <!-- Desktop Light Mode -->
  <source media="(min-width: 769px) and (prefers-color-scheme: light)" srcset="assets/header-wide-light-inline.svg">
  <!-- Mobile Dark Mode -->
  <source media="(max-width: 768px) and (prefers-color-scheme: dark)" srcset="assets/header-stacked-dark-inline.svg">
  <!-- Mobile Light Mode -->
  <source media="(max-width: 768px) and (prefers-color-scheme: light)" srcset="assets/header-stacked-light-inline.svg">
  <img src="assets/header-wide-light-inline.svg" alt="crooked-sentry-appliances">
</picture>
<b align="left" class="cs-repo-meta">
  <span class="cs-repo-subtitle">Part of the Crooked Sentry universe</span>
  <span class="cs-repo-meta-separator" aria-hidden="true">|</span>
  <span class="cs-repo-badges">
    <a href="https://github.com/josephmienko/crooked-sentry-appliances/actions/workflows/validate.yml"><img src="https://github.com/josephmienko/crooked-sentry-appliances/actions/workflows/validate.yml/badge.svg" alt="Validate" align="absmiddle" /></a>
    <a href="https://app.codecov.io/gh/josephmienko/crooked-sentry-appliances"><img src="https://codecov.io/gh/josephmienko/crooked-sentry-appliances/badge.svg" alt="Codecov test coverage" align="absmiddle" /></a>
  </span>
</b>

## Overview

**crooked-sentry-appliances** is a cleanly-documented, phased setup for a home automation appliance infrastructure. It orchestrates a Raspberry Pi running Home Assistant OS with a Dell OptiPlex 3080 running Frigate video analytics, connected via MQTT.

The goal is pilot-ready simplicity: narrowly-focused, repeatable setup steps with no clever automation—infrastructure you can understand, modify, and operate without external dependencies. **Not production-ready until hardware-validated and tested end-to-end**.

---

## Runtime Model

- **Raspberry Pi 4/5** (HA OS) – **Primary appliance**
  - Home Assistant Core
  - Mosquitto MQTT add-on (broker)
  - Frigate integration

- **OptiPlex 3080** (Linux + Docker) – **Analytics appliance**
  - Frigate NVR (Docker Compose)
  - Video stream processing
  - MQTT client connection to HA

- **MQTT** – **Inter-appliance messaging**
  - Lives on HA OS via Mosquitto add-on (Phase 1)
  - Future phases may move to dedicated broker
  - No encryption in Phase 1 (internal network only)

---

## Hardware Roles

| Role | Hardware | OS | Primary Services |
| --- | --- | --- | --- |
| **Primary** | Raspberry Pi 4B/5 | Home Assistant OS | Home Assistant, Mosquitto add-on |
| **Analytics** | Dell OptiPlex 3080 | Ubuntu 22.04 LTS / Debian 12 | Docker, Frigate, supporting services |
| **Development** | MacBook Pro, Linux PC, Windows PC | macOS, Linux, Windows | (Phase 1: not included in appliance setup) |

---

## Repo Layout

```
crooked-sentry-appliances/
├── README.md                               # This file
├── _config.yml                             # GitHub Pages config
├── assets/                                 # Static assets (served by Pages)
│   ├── header-wide-dark-inline.svg
│   ├── header-wide-light-inline.svg
│   ├── header-stacked-dark-inline.svg
│   └── header-stacked-light-inline.svg
├── _includes/                              # Jekyll/Pages includes only
│   └── head-custom.html
│
├── docs/                                   # Detailed phase guides
│   ├── prerequisites.md                    # Hardware/network assumptions
│   ├── setup-phases.md                     # Master roadmap
│   ├── 01-inventory-assumptions.md         # Phase 1: Inventory checklist
│   ├── 02-ha-os-install.md                 # Phase 2: HA OS setup
│   ├── 03-optiplex-linux-docker.md         # Phase 3: Docker host
│   ├── 04-mqtt-setup.md                    # Phase 4: MQTT broker
│   ├── 05-frigate-compose.md               # Phase 5: Frigate NVR
│   ├── 06-ha-frigate-integration.md        # Phase 6: HA + Frigate
│   ├── 07-smoke-tests.md                   # Phase 7: Validation
│   └── FUTURE-08-hacs-themes-branding.md   # Phase 8 (placeholder)
│
├── examples/                               # Configuration templates
│   ├── network-config.example.env          # Network topology template
│   ├── frigate-config.example.yml          # Minimal Frigate config
│   ├── mosquitto-v4-aclfile.example.txt    # MQTT access control
│   └── ha-secrets-template.yaml            # HA secrets file template
│
├── compose/                                # Docker Compose setup
│   └── optiplex-frigate/
│       ├── docker-compose.yml              # Frigate service definition
│       ├── .env.example                    # Environment variables
│       └── README.md                       # Frigate operations guide
│
├── homeassistant/                          # HA configuration guides
│   ├── README.md                           # HA setup overview
│   ├── add-ons/
│   │   └── mosquitto-setup.md              # Mosquitto add-on config
│   └── integrations/
│       └── frigate-integration.md          # Frigate integration
│
├── scripts/                                # Helper scripts
│   ├── README.md                           # Script documentation
│   ├── validate-network-connectivity.sh    # Network health checks
│   └── generate-secrets-template.sh        # Secrets generation
│
└── .gitignore                              # Security: never commit secrets
```

---

## Configuration Contract

### Network Assumptions

- **HA OS (Raspberry Pi)**: Static or DHCP-reserved IP (e.g., `192.168.1.10`)
- **OptiPlex (Frigate)**: Static or DHCP-reserved IP (e.g., `192.168.1.20`)
- **MQTT broker**: Accessible to both appliances (internal network, no external exposure in Phase 1)
- **Development machine**: Network-reachable test client for validation

### Environment Contract

All credentials stored in:

- `examples/secrets.env` (non-committed template)
- HA's `/config/secrets.yaml`
- OptiPlex's `.env` for Docker Compose

Never commit real secrets. Use `.gitignore` to prevent leaks.

### Integration Contract

- **HA ↔ Frigate**: Official HA Frigate integration (HTTP API)
- **HA ↔ MQTT**: Auto-discovery via standard HA MQTT integration
- **Frigate ↔ MQTT**: Frigate publishes events and stats to MQTT topics

---

## Setup Phases

This repo documents **9 phases**, but Phase 1–7 are the **core appliance setup** (all tested and working). Phases 8–9 are future extensions (placeholders only).

### Core Phases (1–7)

| Phase | Duration | Focus | Status |
| --- | --- | --- | --- |
| **1** | 30 min | Inventory & network assumptions | ✅ Complete |
| **2** | 1–2 hrs | Raspberry Pi: HA OS install & onboarding | ✅ Complete |
| **3** | 1–2 hrs | OptiPlex: Linux + Docker baseline | ✅ Complete |
| **4** | 30–60 min | MQTT broker: Mosquitto add-on | ✅ Complete |
| **5** | 1–2 hrs | Frigate NVR: Docker Compose deployment | ✅ Complete |
| **6** | 30–60 min | Home Assistant: Frigate integration | ✅ Complete |
| **7** | 1 hr | Smoke tests: Validation & backups | ✅ Complete |

**See [setup-phases.md](docs/setup-phases.md) for the complete roadmap including Phases 8–9.**

### Quick Start

1. **Review prerequisites**: [prerequisites.md](docs/prerequisites.md)
2. **Start Phase 1**: [01-inventory-assumptions.md](docs/01-inventory-assumptions.md)
3. **Follow phases sequentially** through Phase 7
4. **Validate** with Phase 7 smoke tests

---

## Validation

Each phase includes a **validation checklist**. After Phase 7, you have:

- ✅ Both appliances powered on and network-reachable
- ✅ Home Assistant OS running and accessible
- ✅ Frigate NVR deployed and responding to API
- ✅ MQTT broker connected (manual runbook; syntax-validated only)
- ✅ HA + Frigate integration loaded and showing entities
- ✅ Full system restart tested and successful
- ✅ Backup and rollback procedures documented

**See [07-smoke-tests.md](docs/07-smoke-tests.md) for comprehensive validation steps.**

---

## Future Integrations (Phases 8–9)

These are **placeholders** and **not required for Phase 1**:

### Phase 8: HACS, Themes & Branding (Split Repo: `ha-branding-overrides`)

- Custom Material Design 3 theme
- Lovelace card integrations
- UI customization

### Phase 9: Federated Access & Auth (Split Repo: `ha-federated-access`)

- OAuth2 / OIDC integration
- NetBird VPN (future)
- AuthentiK SSO (future)

---

## Out Of Scope For Initial Setup

The following are **explicitly out of scope** for Phase 1–7:

- **Federated authentication (SSO)** – Phase 9 only
- **Remote access via NetBird** – Phase 9 only
- **TLS/SSL encryption** – Phase 1 assumes internal network only
- **Multi-zone HA setup** – Phase 1 is single-home
- **GPU acceleration** – Future optimization (Frigate can run without)
- **Custom automations** – Phase 1 establishes baseline infrastructure
- **Split repos as dependencies** – They're decoupled features, not requirements

---

## Key Principles

- **Narrowly-focused**: Raspberry Pi + Frigate. Nothing more.
- **Ready for pilot**: Documented and syntax-validated after Phase 7. Hardware validation required before production use.
- **Documented**: Every step explains what, why, and how to troubleshoot.
- **Repeatable**: Same steps produce same result every time.
- **No clever automation**: Prefer documented steps you understand and can modify.
- **Version-controlled**: All infrastructure-as-code in git (except secrets).
- **Vendor-independent**: Uses open-source projects (HA, Frigate, Docker, Mosquitto).

---

## Documentation References

- **Setup Phases**: [setup-phases.md](docs/setup-phases.md)
- **Phase Details**: [docs/](docs/) directory
- **Home Assistant**: <https://www.home-assistant.io/>
- **Frigate**: <https://docs.frigate.video/>
- **Mosquitto**: <https://mosquitto.org/>

---

## Project Status

**Phase 1–7 complete and documented.** Ready for pilot deployment; hardware validation required before production.

Phases 8–9 are future extensions (split into separate repos). Start with Phase 1 when ready.
