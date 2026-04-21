# Phase 8: HACS, Themes & Branding (Future)

**Status**: Placeholder for future implementation  
**Target**: After Phase 7 validation complete  
**Dependencies**: Phase 1–7 fully operational

## Overview

Phase 8 integrates the following custom repositories and components into Home Assistant:

1. **lovelace-m3-core-cards** – Material Design 3 core card components
2. **lovelace-m3-lighting-dashboard** – M3 lighting UI dashboard
3. **lovelace-frigate-event-feed** – Frigate event feed card
4. **ha-material-theme** – Theme system
5. **ha-branding-overrides** – Custom branding (logos, colors)

## Why Phase 8 (Not Phase 1)?

Systems become more stable and less error-prone when:
- Core services are proven operational (Phase 1–7)
- HACS updates don't break core functionality
- Custom components can be added/removed without impacting reliability
- Team is familiar with HA troubleshooting

## Prerequisites

- [ ] Phase 1–7 validation complete
- [ ] HA system stable and backed up
- [ ] Frigate integration working
- [ ] No critical errors in existing automations

## Planned Work

### Step 1: Install HACS

HACS (Home Assistant Community Store) is a package manager for custom HA components.

- [ ] SSH into HA OS
- [ ] Download HACS installer
- [ ] Run installer script
- [ ] Restart HA
- [ ] Configure HACS (GitHub token for private repos if needed)

**Estimated time**: 30 minutes

### Step 2: Add Custom Repositories

Once HACS is installed, add the custom repos:

- [ ] `lovelace-m3-core-cards`
- [ ] `lovelace-m3-lighting-dashboard`
- [ ] `lovelace-frigate-event-feed`
- [ ] `ha-material-theme`
- [ ] `ha-branding-overrides`

**Estimated time**: 15 minutes (assume repos are split from monorepo)

### Step 3: Install Components via HACS

- [ ] Search HACS for each component
- [ ] Install M3 core cards
- [ ] Install M3 lighting dashboard
- [ ] Install Frigate event feed card
- [ ] Restart HA after installations

**Estimated time**: 30 minutes

### Step 4: Apply Theme

- [ ] Settings > Themes
- [ ] Select "ha-material-theme" or equivalent
- [ ] Apply to all users or specific user
- [ ] Verify branding overrides visible (logos, colors)

**Estimated time**: 15 minutes

### Step 5: Build Custom Dashboards

Using installed components:

- [ ] Create Lighting Dashboard (using M3 cards)
- [ ] Add Frigate event feed to main dashboard
- [ ] Apply M3 styling throughout

**Estimated time**: 1–2 hours (design as desired)

### Step 6: Validate & Backup

- [ ] Dashboard functionality verified
- [ ] No visual glitches or missing elements
- [ ] Create HA backup with Phase 8 customizations
- [ ] Document any custom configurations

**Estimated time**: 30 minutes

## Risks & Mitigation

| Risk | Mitigation |
|------|-----------|
| HACS update breaks core HA | Keep backup from Phase 7; rollback if needed |
| Custom component incompatibility | Install one at a time; test before proceeding |
| Theme conflicts with integrations | Test theme on test user first |
| Lost backups during customization | Create backup before and after each major change |

## Rollback Plan

If Phase 8 causes issues:

1. **Stop HA**: Settings > System > Restart
2. **Access backup**: HA Settings > System > Backups
3. **Restore Phase 7 backup**: (ensures you can revert if critical)
4. **Debug**: Identify which component caused issue
5. **Retry**: Re-add components one at a time

## Implementation Notes

When ready to implement Phase 8:

1. Create a detailed Phase 8 implementation document
2. Coordinate with team on theme/dashboard decisions
3. Test custom components on non-production HA first (if possible)
4. Document exact versions of HACS and custom components for reproducibility

## References (Future)

- HACS Documentation: https://hacs.xyz/
- M3 Design System: https://m3.material.io/
- HA Themes: https://www.home-assistant.io/docs/frontend/themes/

---

**Next Phase**: Phase 8 will be implemented after Phase 7 validation is complete and stable. Planning to begin Q3 2025 (or when system has run 1+ month without issues).
