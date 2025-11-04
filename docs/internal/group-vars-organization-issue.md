# Group Variables Organization Issue

**Date**: November 4, 2025
**Severity**: HIGH - Configuration conflict causing unexpected behavior
**Status**: IDENTIFIED

---

## Problem Summary

There are **two separate `group_vars/all.yml` files** with conflicting variable definitions:

1. **`ansible-content/group_vars/all.yml`** (250 lines) - Playbook-level defaults
2. **`ansible-content/inventory/group_vars/all.yml`** (163 lines) - Inventory-level overrides

**Critical Conflict**: Metrics export settings are contradictory:

| Setting | Playbook-Level | Inventory-Level | Impact |
|---------|-----------------|-----------------|--------|
| `export_metrics` | `false` (disabled) | `true` (ENABLED) | When inventory used, metrics enabled by default |
| `send_metrics` | Not defined | `true` (duplicate) | Conflicting variable names |

---

## Root Cause Analysis

### Ansible Variable Precedence
When running playbooks against the inventory, Ansible loads variables in this order (highest to lowest precedence):
1. **Inventory group_vars** (`ansible-content/inventory/group_vars/all.yml`) ← **Takes priority**
2. Playbook-level group_vars (`ansible-content/group_vars/all.yml`)
3. Role defaults (`roles/*/defaults/main.yml`)

**Result**: Inventory-level settings override playbook-level settings, causing the metrics to be enabled by default.

### Why This Causes the User's Issue

When running a playbook with the inventory:
```bash
ansible-playbook playbooks/main-upgrade-workflow.yml -i ansible-content/inventory/hosts.yml
```

1. Ansible loads `export_metrics: true` from inventory group_vars
2. During metrics-export.yml execution, validation block attempts to check InfluxDB config
3. InfluxDB config is empty (not configured in environment)
4. **Assertion fails** with the error the user reported

---

## Current Duplication

### Inventory-Level `all.yml` (163 lines) Contains:
- Connection settings (timeouts, credentials)
- Upgrade workflow settings (retries, delays, timeouts)
- Backup/rollback settings
- Validation settings
- **Metrics settings** (export_metrics, send_metrics)
- Notification settings
- Network validation settings
- Logging settings
- Compliance settings
- Platform mappings

### Playbook-Level `all.yml` (250 lines) Contains:
- Network facts defaults
- NetBox integration
- Connection defaults
- Firmware management defaults
- Device metadata defaults
- Feature flags
- Upgrade maintenance defaults
- Compliance/security defaults
- Geographic/organizational defaults
- **Metrics settings** (export_metrics, influxdb_*, metrics_webhook_*, etc.)
- Debug settings
- Platform-specific defaults
- Data initialization

---

## Variables with Conflicting Definitions

### 1. Metrics Configuration
**Inventory** (lines 108-110):
```yaml
export_metrics: true
metrics_batch_size: 100
metrics_export_interval: 30
```

**Playbook** (lines 147-163):
```yaml
export_metrics: false
log_metrics_locally: false
debug_metrics: false
update_netbox: false
influxdb_url: ""
influxdb_token: ""
influxdb_bucket: "network_upgrades"
influxdb_org: "default"
metrics_webhook_url: ""
metrics_webhook_token: ""
```

**Winner**: `export_metrics: true` from inventory (breaks default safe behavior)

### 2. Duplicated Variable Names
- **`send_metrics`** - exists ONLY in inventory (line 139), conflicts with standardized `export_metrics`
- **`log_metrics_locally`** - exists ONLY in playbook (line 148)
- **`debug_metrics`** - exists ONLY in playbook (line 149)

### 3. Overlapping Settings
- `show_debug`: Both files (different values: false vs false)
- `bgp_enabled`: Inventory (true), Playbook (true) - OK
- `backup_enabled`: Only inventory (true)
- `skip_validation`: Only inventory (false)

---

## Why This Structure Exists (Hypothesis)

1. **Inventory-level `all.yml`** was originally designed for:
   - Real deployment scenarios with actual inventory
   - Connection credentials (vault-based)
   - Production settings (metrics enabled, notifications on)

2. **Playbook-level `all.yml`** was later added for:
   - Safe defaults when testing without inventory
   - Comprehensive variable definitions per CLAUDE.md rules
   - Safe defaults (metrics disabled, no notifications)

3. **No consolidation happened** - Both files coexist, causing conflicts

---

## Recommended Fix

### Phase 1: Consolidate Variable Definitions
Consolidate into a **single source of truth** in `ansible-content/group_vars/all.yml`:

```yaml
# METRICS AND MONITORING
# Metrics export settings - STANDARDIZED VARIABLE NAME: export_metrics
# Default: false (metrics disabled, safe for all scenarios)
export_metrics: false

# InfluxDB settings (required if export_metrics is true)
influxdb_url: ""
influxdb_token: ""
influxdb_bucket: "network_upgrades"
influxdb_org: "default"

# Webhook settings (both url and token required)
metrics_webhook_url: ""
metrics_webhook_token: ""

# Metrics behavior
log_metrics_locally: false
debug_metrics: false
update_netbox: false
```

### Phase 2: Separate Inventory-Specific Settings
Keep **only connection/inventory-specific** settings in `ansible-content/inventory/group_vars/all.yml`:

```yaml
# Connection settings (inventory-specific)
ansible_connection_timeout: 30
ansible_command_timeout: 300
ansible_connect_timeout: 30

# Dynamic credentials (vault-based)
ansible_user: >-
  {{ (platform == 'nxos' and vault_cisco_nxos_username is defined) | ternary(...) }}

# File paths specific to this inventory
network_upgrade_base_path: "/var/lib/network-upgrade"
firmware_base_path: "{{ network_upgrade_base_path }}/firmware"
```

### Phase 3: Environment Variable Overrides
Use environment variables or extra_vars for deployment-specific overrides:

```bash
# For production deployment with InfluxDB
ansible-playbook playbooks/main-upgrade-workflow.yml \
  -i ansible-content/inventory/hosts.yml \
  -e "export_metrics=true" \
  -e "influxdb_url=https://monitoring.example.com:8086" \
  -e "influxdb_token=***secret***"
```

---

## Implementation Plan

### Step 1: Clean Up Variable Names
- [ ] Remove `send_metrics` from inventory (use `export_metrics` only)
- [ ] Consolidate metrics configuration to playbook-level defaults
- [ ] Update all references to use `export_metrics` (already done in current branch)

### Step 2: Consolidate Files
- [ ] Move all **universal default variables** to `ansible-content/group_vars/all.yml`
- [ ] Remove redundant variables from `ansible-content/inventory/group_vars/all.yml`
- [ ] Keep ONLY **inventory-specific settings** in inventory group_vars:
  - Connection settings (timeouts, connection type)
  - Dynamic credentials (vault-based)
  - Inventory-relative paths

### Step 3: Test All Scenarios
- [ ] Playbook execution without inventory (uses playbook-level defaults)
- [ ] Playbook execution with inventory (inventory settings override playbook defaults)
- [ ] Environment variable overrides work correctly
- [ ] All tests pass (22/22)

### Step 4: Document
- [ ] Update CLAUDE.md with variable precedence rules
- [ ] Document which variables belong at which level
- [ ] Add examples of correct variable organization

---

## Impact Analysis

### Current Behavior (Broken)
- Inventory defaults metrics ON (unsafe for production without config)
- Playbook defaults metrics OFF (safe for testing)
- Conflict causes user confusion and silent failures

### After Fix (Safe)
- All defaults from playbook-level group_vars (safe)
- Inventory can override with explicit settings
- Environment variables/extra_vars for deployment-specific values
- Clear, single source of truth

---

## Related Documentation

- **CLAUDE.md**: Variable management rules (section 3)
- **Project Structure**: See `CLAUDE.md` section on project structure
- **Metrics Configuration**: See `docs/internal/metrics-export-analysis.md`
- **Guard Rails**: See `docs/internal/metrics-guard-rails-fix.md`

---

## Files to be Modified

1. `ansible-content/inventory/group_vars/all.yml` - Remove duplicate variables
2. `ansible-content/group_vars/all.yml` - Already has proper consolidated variables
3. Test suite - Verify all scenarios work correctly

---

**Status**: Ready for implementation in next phase
**Blocker**: None - can be implemented anytime
**Testing**: Comprehensive test coverage exists (22 test suites)
