# Phase 9: Federated Access (Future)

**Status**: Placeholder for future implementation  
**Target**: After Phase 8 complete (Q3–Q4 2025 estimate)  
**Dependencies**: Phase 1–8 fully operational

## Overview

Phase 9 adds federated authentication and optional remote access:

1. **ha-federated-access** – Single Sign-On (SSO) via OIDC
2. **NetBird Integration** (optional) – Secure VPN for remote access
3. **AuthentiK** (optional) – Federated identity provider

## Why Phase 9 (Not Phase 1)?

Security best practices recommend:
- Core system proven stable first (Phase 1–8)
- Local fallback account always available
- Auth infrastructure tested separately before federation
- Team familiarity with HA before adding complexity

## Current Authentication (Phase 1–7)

- **Local owner account only** (no SSO)
- **Internal network access** (no remote access)
- **Username/password** authentication

## Planned Authentication (Phase 9)

- **OIDC-based SSO** (via ha-federated-access)
- **Multiple user support** via federated identity provider
- **Optional**: Remote access via NetBird VPN
- **Optional**: Third-party identity provider (Google, GitHub, custom IdP)

## Federated Access Components

### ha-federated-access

Enables OIDC/OAuth2 authentication for Home Assistant.

- **Supported providers**: Keycloak, Auth0, Okta, custom OIDC servers
- **Features**: Multi-user support, role-based access control
- **Installation**: Via HACS (Phase 8 prerequisite)

### NetBird (Optional)

Mesh VPN for secure remote access without port forwarding or DDoS exposure.

- **Setup**: Install NetBird client on HA and development machines
- **Access**: Your HA OS behind NAT as if local network
- **Security**: WireGuard-based, zero-trust networking

### AuthentiK (Optional)

A lightweight OIDC provider if you want to host your own identity system:

- **Setup**: Docker container on OptiPlex or separate appliance
- **Users**: Local database or LDAP integration
- **Requires**: Minimal overhead HA integration

## Prerequisites

- [ ] Phase 1–8 complete and stable
- [ ] HA system has been running successfully for 1+ month
- [ ] Team familiarity with auth concepts (OIDC, JWT, etc.)
- [ ] Backup strategy in place (Phase 7 complete)
- [ ] Local owner account permanently available as fallback

## Planned Work

### Step 1: Install ha-federated-access

- [ ] Via HACS (Phase 8 prerequisite)
- [ ] Search and install "ha-federated-access"
- [ ] Restart HA
- [ ] Configure OIDC settings

**Estimated time**: 30 minutes

### Step 2: Set Up Identity Provider

**Option A**: Use existing OIDC provider (Google, GitHub)
- [ ] Register OAuth apps on provider
- [ ] Configure client ID and secret in HA

**Option B**: Deploy AuthentiK on OptiPlex (Docker)
- [ ] Create Docker Compose for AuthentiK
- [ ] Add users locally or via LDAP
- [ ] Configure authentiK as OIDC provider for HA

**Estimated time**: 1–2 hours (Option B more complex)

### Step 3: Test SSO

- [ ] Log out of local HA account
- [ ] Log in via OIDC/SSO
- [ ] Verify multi-user support works
- [ ] Test role-based access (if configured)

**Estimated time**: 30 minutes

### Step 4: Enable Remote Access (Optional)

If desired:

- [ ] Install NetBird client on HA
- [ ] Configure NetBird network
- [ ] Add development machine to network
- [ ] Test HA access over NetBird VPN

**Estimated time**: 1 hour (dependent on NetBird setup)

### Step 5: Maintain Local Fallback

**CRITICAL**: Always keep local account accessible:

- [ ] Local owner account remains active
- [ ] Disable SSO-only enforcement
- [ ] Test local login path regularly

**Estimated time**: 10 minutes (one-time setup)

### Step 6: Document & Backup

- [ ] Create Phase 9 implementation guide
- [ ] Document OIDC provider configuration
- [ ] Create backup with federated access configured
- [ ] Test backup restore to verify reproducibility

**Estimated time**: 1 hour

## Architecture (Planned)

```
┌─────────────────────────────────────────────────────────┐
│  Your Local Network + Remote (NetBird Optional)         │
│                                                          │
│  ┌──────────┐        ┌─────────────────────────────┐   │
│  │   HA OS  │        │  Identity Provider          │   │
│  │ (RPi)    │◄──────►│  (OIDC via AuthentiK or    │   │
│  │          │        │   Third-party IdP)          │   │
│  └──────────┘        └─────────────────────────────┘   │
│       ▲                                                  │
│       │OIDC Flow                                        │
│       │                                                  │
│  ┌────────────────────────────────────────────────────┐ │
│  │  User Login / SSO                                  │ │
│  │  (Local fallback always available)                 │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  Optional Remote Access:                                │
│  Dev Machine ◄──NetBird VPN──► HA (behind NAT)        │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## Risks & Mitigation

| Risk | Mitigation |
|------|--------|
| SSO outage blocks all access | Maintain working local account; test fallback weekly |
| Identity provider misconfiguration | Document all settings; create backup before changes |
| NetBird client update breaks access | Keep HA accessible via local network; test VPN periodically |
| Token expiry issues | Monitor token refresh; configure generous TTLs initially |

## Rollback Plan

If Phase 9 causes authentication issues:

1. **Local access still works**: Use local owner account from Phase 1–7
2. **Disable SSO**: Settings > Users & Permissions > Authentication Provider (disable)
3. **Restore backup**: Use Phase 8 backup (pre-federated) if needed
4. **Debug**: Review HA logs for auth errors

## Assumptions & Constraints

- **No shared identity system yet**: Each user locally managed or via single OIDC provider
- **No directory service**: If LDAP needed, Phase 9+ expansion
- **No multi-tenancy**: Single HA instance for single home
- **No advanced IAM**: Complex role models deferred to Phase 9+

## Future Expansions (Phase 9+)

Beyond initial Phase 9:

- [ ] LDAP directory integration
- [ ] Multi-appliance SSO (if adding more homes)
- [ ] Advanced role-based access control (RBAC)
- [ ] Audit logging for security compliance
- [ ] OAuth2 device flow for mobile apps

## References (Future)

- **ha-federated-access**: [GitHub repo when split]
- **OIDC Spec**: https://openid.net/connect/
- **AuthentiK**: [Custom IdP docs when finalized]
- **NetBird**: https://netbird.io/
- **Home Assistant Auth**: https://www.home-assistant.io/docs/authentication/

---

**Implementation timeline**: Q3–Q4 2025 (after Phase 8 stable for 1+ month). Check back when Phase 7 validation is complete.

**Status**: Federated access planned. Not implemented in Phase 1 setup.
