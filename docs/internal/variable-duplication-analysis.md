# Variable Duplication Analysis & Remediation Plan

**Date**: November 4, 2025
**Scope**: Comprehensive audit of `group_vars/all.yml` across all locations
**Status**: READY FOR REMEDIATION

---

## Executive Summary

**Found**: 11 duplicated variables defined in BOTH `ansible-content/group_vars/all.yml` AND `ansible-content/inventory/group_vars/all.yml`

**Critical Issues**: 10 of 11 duplicates have **CONFLICTING VALUES**

**Risk**: Variable precedence causes inventory-level values to override playbook-level, leading to unexpected behavior

---

## Duplicated Variables Detail

### Critical Conflicts (Values differ significantly)

#### 1. `ansible_user`
- **Playbook-level**: `"admin"` (simple static value)
- **Inventory-level**: `>-` (folded scalar with ternary logic for dynamic credentials)
- **Winner**: Inventory-level (precedence rules)
- **Issue**: Breaks CLAUDE.md rule against folded scalars in conditionals
- **Impact**: Real deployments use vault variables, testing uses static "admin"

#### 2. `backup_base_path`
- **Playbook-level**: `"./backups"` (relative path for testing)
- **Inventory-level**: `"{{ network_upgrade_base_path }}/backups"` (absolute path for deployment)
- **Winner**: Inventory-level
- **Issue**: Testing uses relative, production uses absolute - inconsistent behavior
- **Impact**: Backups written to different locations depending on execution context

#### 3. `baseline_base_path`
- **Playbook-level**: `"./baselines"` (relative)
- **Inventory-level**: `"{{ network_upgrade_base_path }}/baselines"` (absolute, depends on network_upgrade_base_path)
- **Winner**: Inventory-level
- **Issue**: Same as backup_base_path
- **Impact**: Baseline files scattered across two locations

#### 4. `baseline_file_pre_upgrade`
- **Playbook-level**: `.../pre_upgrade.json`
- **Inventory-level**: `.../pre_upgrade_baseline.json` (adds "_baseline")
- **Winner**: Inventory-level
- **Issue**: Inconsistent filename patterns
- **Impact**: Baseline comparison fails if code expects `pre_upgrade.json` but file is `pre_upgrade_baseline.json`

#### 5. `baseline_file_post_upgrade`
- **Playbook-level**: `.../post_upgrade.json`
- **Inventory-level**: `.../post_upgrade_baseline.json` (adds "_baseline")
- **Winner**: Inventory-level
- **Issue**: Same as pre_upgrade
- **Impact**: Inconsistent file naming

#### 6. `bfd_enabled`
- **Playbook-level**: `false` (disabled for testing)
- **Inventory-level**: `true` (enabled for validation)
- **Winner**: Inventory-level
- **Issue**: Opposite default values - causes unexpected behavior
- **Impact**: Validation tests may fail in production due to BFD checks

#### 7. `include_startup_config`
- **Playbook-level**: `false` (exclude startup config in testing)
- **Inventory-level**: `true` (include in production backups)
- **Winner**: Inventory-level
- **Issue**: Different backup strategy per context
- **Impact**: Production backups include more data than testing

### Minimal/No Conflicts

#### 8. `bgp_enabled`
- **Both**: `true` ✓ (SAME)
- **Issue**: Unnecessary duplication
- **Remediation**: Keep in playbook-level only, remove from inventory

#### 9. `backup_type`
- **Values differ slightly** in comments, but effectively same
- **Both**: `"pre_upgrade"` (value is identical)
- **Issue**: Unnecessary duplication
- **Remediation**: Keep in playbook-level only

#### 10. `multicast_enabled`
- **Both**: `true` ✓ (SAME)
- **Issue**: Unnecessary duplication
- **Remediation**: Keep in playbook-level only

#### 11. `show_debug`
- **Both**: `false` ✓ (SAME)
- **Issue**: Unnecessary duplication
- **Remediation**: Keep in playbook-level only

---

## Root Cause Analysis

### Why This Duplication Exists

1. **Historical Development**:
   - Inventory `all.yml` was created first for actual deployments
   - Playbook-level `all.yml` was added later for testing/safety
   - No consolidation or cleanup occurred

2. **Conflicting Design Philosophies**:
   - Playbook-level: "Safe defaults for testing" (metrics off, validation off, relative paths)
   - Inventory-level: "Production configuration" (metrics on, validation on, absolute paths)

3. **Lack of Documentation**:
   - No clear guidelines on where variables should be defined
   - Developers added variables wherever seemed appropriate

4. **Variable Precedence Confusion**:
   - Developers may not realize inventory values override playbook values
   - Led to multiple definitions assuming they're independent

---

## Remediation Strategy

### Phase 1: Consolidation Rules (THIS SPRINT)

**Principle**: "Single Source of Truth"
- Each variable defined in EXACTLY ONE location
- Playbook-level `group_vars/all.yml` is the default source
- Inventory-level `group_vars/` can override specific settings for that inventory only

### Phase 2: Variable Classification

#### Category A: Universal Defaults (→ Playbook-level)
Variables that apply to all execution contexts:
- Feature flags: `bgp_enabled`, `bfd_enabled`, `multicast_enabled`
- Debug settings: `show_debug`
- Backup type: `backup_type`
- Metadata fields: `default_*`
- Validation settings: `comparison_status`

#### Category B: Path Variables (→ Playbook-level + Inventory override)
Variables for file storage - define with relative paths in playbook, override in inventory if needed:
- `backup_base_path`: Playbook `"./backups"` → Inventory `"{{ network_upgrade_base_path }}/backups"`
- `baseline_base_path`: Playbook `"./baselines"` → Inventory `"{{ network_upgrade_base_path }}/baselines"`
- `baseline_file_pre_upgrade`: Playbook standard name → Inventory production name

#### Category C: Connection/Credentials (→ Inventory-level ONLY)
Variables that differ per inventory:
- `ansible_user`: Dynamic credentials with vault substitution
- `ansible_password`: Dynamic credentials with vault substitution
- `ansible_ssh_private_key_file`: Path specific to that inventory
- Connection timeouts: `ansible_connection_timeout`, `ansible_connect_timeout`, `ansible_command_timeout`

#### Category D: REMOVED (Consolidate to playbook-level only)
Variables that have SAME value in both locations:
- `bgp_enabled: true`
- `multicast_enabled: true`
- `show_debug: false`

---

## Detailed Remediation Plan

### STEP 1: Update `ansible-content/group_vars/all.yml` (Playbook-level)

**Action**: Ensure playbook-level has safe defaults

```yaml
# Feature Flags (universal defaults)
bgp_enabled: true
bfd_enabled: false  # Default disabled for safety
multicast_enabled: true

# Backup/Baseline Paths (relative for testing)
backup_base_path: "./backups"
baseline_base_path: "./baselines"
baseline_file_pre_upgrade: "{{ baseline_base_path }}/{{ inventory_hostname }}_pre_upgrade.json"
baseline_file_post_upgrade: "{{ baseline_base_path }}/{{ inventory_hostname }}_post_upgrade.json"

# Backup behavior
backup_type: "pre_upgrade"
include_startup_config: false  # Conservative for testing

# Connection (safe defaults)
ansible_user: "admin"

# Debug
show_debug: false
```

### STEP 2: Update `ansible-content/inventory/group_vars/all.yml` (Inventory-level)

**Action**: Keep ONLY inventory-specific overrides

**Remove these** (duplicates with same values):
- `bgp_enabled: true` (line 126)
- `multicast_enabled: true` (line 128)
- `show_debug: false` (comment reference)

**Override these** (production-specific values):
```yaml
# Feature Flags (inventory override)
bfd_enabled: true  # Enable BFD for production validation

# Paths (production absolute paths)
backup_base_path: "{{ network_upgrade_base_path }}/backups"
baseline_base_path: "{{ network_upgrade_base_path }}/baselines"
baseline_file_pre_upgrade: "{{ baseline_base_path }}/{{ inventory_hostname }}_pre_upgrade_baseline.json"
baseline_file_post_upgrade: "{{ baseline_base_path }}/{{ inventory_hostname }}_post_upgrade_baseline.json"

# Backup behavior
include_startup_config: true  # Include startup config in production

# Connection Credentials (INVENTORY ONLY - not in playbook)
ansible_user: >-  # Dynamic based on platform
  {{
    (platform == 'nxos' and vault_cisco_nxos_username is defined) | ternary(...) or 'admin'
  }}
ansible_password: >-  # Dynamic based on platform
  {{
    (platform == 'nxos' and vault_cisco_nxos_password is defined) | ternary(...) or omit
  }}
ansible_ssh_private_key_file: >-  # Dynamic based on platform
  {{
    (platform == 'nxos' and vault_cisco_nxos_ssh_key is defined) | ternary(...) or omit
  }}
```

### STEP 3: Document Variable Ownership

**Update CLAUDE.md** with new section:

```markdown
## Variable Definition Guidelines

### Where Variables Are Defined

1. **Playbook-level** (`ansible-content/group_vars/all.yml`)
   - Universal defaults for all execution contexts
   - Safe values for testing without inventory
   - Feature flags, debug settings, metadata

2. **Inventory-specific** (`ansible-content/inventory/group_vars/`)
   - Connection credentials and authentication
   - Deployment-specific paths (absolute vs relative)
   - Feature overrides for production environment
   - Platform-specific configurations

3. **Role defaults** (`roles/*/defaults/main.yml`)
   - Role-specific variables
   - Internal implementation details
   - Lowest precedence in Ansible hierarchy

### Variable Precedence (Highest to Lowest)
1. Inventory group_vars (highest precedence)
2. Playbook-level group_vars
3. Role defaults (lowest precedence)

### Example: Defining a New Variable

**If** the variable applies to all execution contexts → Add to **playbook-level**
**If** the variable is inventory-specific → Add to **inventory-specific only**
**If** the variable has both → Add to **playbook with safe default**, override in **inventory**
```

### STEP 4: Validation Testing

Create test to verify:
1. Playbook execution without inventory uses playbook-level values
2. Playbook execution with inventory uses inventory-level values (overrides)
3. All 11 formerly-duplicate variables have expected values in both contexts
4. File paths are correct for each context

---

## Files to Modify

| File | Changes | Lines |
|------|---------|-------|
| `ansible-content/group_vars/all.yml` | Verify has complete safe defaults | No change needed |
| `ansible-content/inventory/group_vars/all.yml` | Remove 4 duplicate lines, add 2 override sections | ±6 lines |
| `CLAUDE.md` | Add "Variable Definition Guidelines" section | +25 lines |
| `docs/internal/variable-duplication-analysis.md` | This document (new) | +300 lines |

---

## Impact Analysis

### Before Remediation
- 11 variables defined in TWO places
- 10 conflicts cause unexpected behavior
- Confusing behavior when using inventory vs standalone
- CLAUDE.md rules violated (folded scalars in conditionals)

### After Remediation
- Each variable defined in EXACTLY ONE location
- Inventory level clearly documented as overrides only
- Predictable behavior: playbook-level is source, inventory overrides
- CLAUDE.md rules followed consistently

---

## Estimated Effort

- **Analysis**: ✓ Complete (this document)
- **Playbook-level cleanup**: 15 minutes
- **Inventory-level cleanup**: 20 minutes
- **Testing**: 30 minutes
- **Documentation**: 20 minutes
- **Total**: ~1.5 hours

---

## Risk Assessment

### Low Risk Changes
- Removing true duplicates (bgp_enabled, multicast_enabled, show_debug)
- Adding notes/comments to inventory pointing to playbook-level
- Documentation updates

### Medium Risk Changes
- Inventory overrides for paths (backup_base_path, baseline_base_path)
- Feature overrides (bfd_enabled, include_startup_config)
- **Mitigation**: Comprehensive testing, verify all 23 tests pass

### Validation Required
- [ ] Playbook without inventory: uses playbook-level values
- [ ] Playbook with inventory: uses inventory-level overrides
- [ ] All 23 tests pass
- [ ] No syntax errors
- [ ] Ansible lint passes

---

## Success Criteria

- [x] Comprehensive audit completed (11 duplicates identified)
- [x] Root cause analysis documented
- [x] Remediation plan defined with clear phases
- [ ] Implementation in next sprint
- [ ] All tests passing post-remediation
- [ ] Documentation updated with variable guidelines

---

**Next Step**: Execute Phase 1-2 (consolidation) in next sprint
