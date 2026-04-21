# Crooked Sentry Helper Scripts

This directory contains optional helper scripts to reduce manual work during setup and maintenance.

**Philosophy**: Keep scripts simple, documented, and optional. All operations should be repeatable via manual steps if needed.

## Available Scripts

### `validate-network-connectivity.sh`

Performs comprehensive network checks to ensure both appliances are reachable and services are accessible.

**Usage**:

```bash
./scripts/validate-network-connectivity.sh
```

**What it does**:

- Pings both appliances (Raspberry Pi and OptiPlex)
- Tests SSH connectivity to each
- Verifies HA UI is reachable
- Verifies Frigate API is reachable
- Tests DNS/mDNS resolution
- Reports results in simple table format

**Output**: Pass/fail for each test with troubleshooting hints

**Prerequisites**:

- Both appliances on network
- SSH keys configured (or password prompt)
- curl, ping, ssh available on development machine

---

### `generate-secrets-template.sh`

Creates a starter secrets.env file with prompts for you to fill in secure values.

**Usage**:

```bash
./scripts/generate-secrets-template.sh
```

**What it does**:

- Creates a template `secrets.env` file
- Prompts for each required password/credential
- Saves to `.env` (auto-excluded from git)
- Sets permissions to 600 (owner-read-only)

**Output**: `secrets.env` file ready for use

**Note**: Do NOT commit the generated `secrets.env` file.

---

## Adding New Scripts

If you add more helper scripts:

1. **Make them OPTIONAL**: All work should be doable manually if script fails
2. **Document heavily**: Include comments explaining each step
3. **Error handling**: Check for common issues and provide clear error messages
4. **Non-destructive**: Avoid scripts that delete, overwrite, or modify without confirmation
5. **Portable**: Use standard tools (bash, curl, ping, ssh) available on most systems

## General Usage

All scripts use environment variables from `examples/network-config.example.env`. Source it before running:

```bash
source examples/network-config.example.env
./scripts/validate-network-connectivity.sh
```

Or export individual variables:

```bash
export HA_RPI_IP=192.168.1.10
export OPTIPLEX_IP=192.168.1.20
./scripts/validate-network-connectivity.sh
```

---

## Troubleshooting Scripts

If a script fails:

1. **Run manually**: Execute the steps documented in the script by hand (good for understanding)
2. **Check permissions**: Scripts need execute bit: `chmod +x scripts/*.sh`
3. **Check dependencies**: Verify required tools (curl, ssh, etc.) are installed
4. **Review errors**: Most scripts print clear error messages for debugging

---

**Status**: Helper scripts area. Optional utilities for convenience.
