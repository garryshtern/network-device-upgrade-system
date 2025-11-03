# Compliance Fixes TODO List

**Generated**: November 3, 2025
**Target**: Bring codebase to 100% compliance with CLAUDE.md standards
**Estimated Effort**: 6-8 hours
**Blocking Issue**: Cannot deploy until all violations fixed

---

## PHASE 1: CRITICAL FIXES - 10 `and` Clauses (HIGH PRIORITY - 30 MIN)

These are the simplest and highest-value fixes. Must be done first.

### TODO 1.1: Fix `and` clauses in arp-validation.yml
- **File**: `ansible-content/roles/network-validation/tasks/arp-validation.yml`
- **Violations**: 2
- **Lines**: 30, 73
- **Current**:
  ```yaml
  Line 30: when: network_baseline_pre.arp_data is defined and network_baseline_post.arp_data is defined
  Line 73: when: network_baseline_pre.mac_data is defined and network_baseline_post.mac_data is defined
  ```
- **Fix to**:
  ```yaml
  Line 30:
  when:
    - network_baseline_pre.arp_data is defined
    - network_baseline_post.arp_data is defined

  Line 73:
  when:
    - network_baseline_pre.mac_data is defined
    - network_baseline_post.mac_data is defined
  ```
- **Status**: ⬜ TODO

### TODO 1.2: Fix `and` clauses in routing-validation.yml
- **File**: `ansible-content/roles/network-validation/tasks/routing-validation.yml`
- **Violations**: 2
- **Lines**: 30, 73
- **Fix**: Convert `and` to YAML list syntax (same pattern as 1.1)
- **Status**: ⬜ TODO

### TODO 1.3: Fix `and` clauses in multicast-validation.yml
- **File**: `ansible-content/roles/network-validation/tasks/multicast-validation.yml`
- **Violations**: 6
- **Lines**: 30, 73, 116, 142, 185, 228
- **Fix**: Convert all 6 `and` clauses to YAML list syntax
- **Status**: ⬜ TODO

### TODO 1.4: Verify all `and` fixes and run tests
- **Action**: After fixing all 10 `and` violations:
  ```bash
  ./tests/run-all-tests.sh
  ```
- **Expected**: All 22 tests pass
- **Status**: ⬜ TODO (depends on 1.1-1.3)

---

## PHASE 2: CONVERT FOLDED SCALARS - 92 Instances (3-4 HOURS)

Convert all `msg: |`, `msg: >-`, `fail_msg: |` to YAML list syntax.

### TODO 2.1: Fix folded scalars in Opengear tasks (19 violations)

#### TODO 2.1.1: image-loading-legacy.yml
- **File**: `ansible-content/roles/opengear-upgrade/tasks/image-loading-legacy.yml`
- **Violations**: 5 (lines 158, 197, 204, 253, 263)
- **Fix**: Convert `msg: |` to `msg: [list items]`
- **Status**: ⬜ TODO

#### TODO 2.1.2: image-installation-legacy.yml
- **File**: `ansible-content/roles/opengear-upgrade/tasks/image-installation-legacy.yml`
- **Violations**: 5 (lines 49, 78, 128, 283)
- **Status**: ⬜ TODO

#### TODO 2.1.3: image-installation.yml
- **File**: `ansible-content/roles/opengear-upgrade/tasks/image-installation.yml`
- **Violations**: 3 (lines 100, 289)
- **Status**: ⬜ TODO

#### TODO 2.1.4: Other Opengear files
- **Files**: console-server-check.yml, main.yml, serial-management.yml, smart-pdu-check.yml, web-automation.yml
- **Violations**: 6
- **Status**: ⬜ TODO

### TODO 2.2: Fix folded scalars in FortiOS tasks (12 violations)

#### TODO 2.2.1: multi-step-upgrade.yml
- **File**: `ansible-content/roles/fortios-upgrade/tasks/multi-step-upgrade.yml`
- **Violations**: 5 (lines 8, 34, 101, 129)
- **Status**: ⬜ TODO

#### TODO 2.2.2: image-installation.yml
- **File**: `ansible-content/roles/fortios-upgrade/tasks/image-installation.yml`
- **Violations**: 1 (line 243)
- **Status**: ⬜ TODO

#### TODO 2.2.3: Other FortiOS files
- **Files**: ha-cluster-upgrade.yml, ha-coordination.yml, image-loading.yml, main.yml, standalone-upgrade.yml
- **Violations**: 6
- **Status**: ⬜ TODO

### TODO 2.3: Fix folded scalars in Cisco IOS-XE tasks (6 violations)

#### TODO 2.3.1: All IOS-XE files
- **Files**:
  - bundle-mode.yml (line 63)
  - check-install-mode.yml (line 54)
  - image-loading.yml (line 85)
  - image-installation.yml (line 180)
  - install-mode.yml (line 66)
  - main.yml (line 30)
- **Violations**: 6
- **Status**: ⬜ TODO

### TODO 2.4: Fix folded scalars in Cisco NX-OS tasks (5+ violations)

#### TODO 2.4.1: All NX-OS task files
- **Files**: check-issu-capability.yml, issu-procedures.yml, main.yml, reboot.yml
- **Violations**: 5+
- **Status**: ⬜ TODO

### TODO 2.5: Fix folded scalars in Common tasks (2 violations)

#### TODO 2.5.1: connectivity-check.yml and network-resources-gathering.yml
- **Files**:
  - connectivity-check.yml
  - network-resources-gathering.yml
- **Violations**: 2
- **Status**: ⬜ TODO

### TODO 2.6: Fix folded scalars in Image Validation (3 violations)

#### TODO 2.6.1: integrity-audit.yml and version-verification.yml
- **Files**:
  - integrity-audit.yml (line 58)
  - version-verification.yml (lines 62, 73)
- **Violations**: 3
- **Status**: ⬜ TODO

### TODO 2.7: Fix folded scalars in Emergency Rollback (1 violation)

#### TODO 2.7.1: emergency-rollback.yml
- **File**: `ansible-content/playbooks/emergency-rollback.yml`
- **Violations**: 1
- **Status**: ⬜ TODO

### TODO 2.8: Fix folded scalars in Molecule test files (12 violations)

#### TODO 2.8.1: All molecule/default/* files
- **Locations**: Multiple molecule test files across roles
- **Violations**: 12 total
- **Note**: These are test files, still must comply
- **Status**: ⬜ TODO

### TODO 2.9: Verify all folded scalar fixes and run tests
- **Action**: After fixing all 92 folded scalars:
  ```bash
  ansible-lint ansible-content/ --offline --parseable-severity
  yamllint ansible-content/
  ./tests/run-all-tests.sh
  ```
- **Expected**: All tests pass, no yamllint errors
- **Status**: ⬜ TODO (depends on 2.1-2.8)

---

## PHASE 3: FIX `| default()` VIOLATIONS - 65 Instances (2-3 HOURS)

### TODO 3.1: Fix netbox_dynamic.yml (41 violations - PRIORITY 1)
- **File**: `ansible-content/inventory/netbox_dynamic.yml`
- **Violations**: 41 (lines 9, 38, 41, 58, 60, 62, 64, 83, 86, 90, 92, 94, 98, 100, 102, 104, 106, 110, 112, 114, 116, 118, 122, 124, 126, 133, 135, 143, 165, 196, 203, 210, 243, 244, and more)
- **Primary Issue**: Heavy use of `| default()` for environment variables and configuration
- **Root Cause**: Should be using proper variable definitions instead
- **Approach**:
  1. Create `group_vars/all.yml` entries for all defaults
  2. Or use `group_vars/all/` directory structure
  3. Document all configuration variables
  4. Remove all `| default()` filters
- **Complexity**: HIGH - Requires understanding of how netbox_dynamic.yml is used
- **Status**: ⬜ TODO (BLOCKED - needs consultation on proper structure)

### TODO 3.2: Fix connectivity-check.yml (9 violations)
- **File**: `ansible-content/roles/common/tasks/connectivity-check.yml`
- **Violations**: 9 (lines 32, 48, 102, 103, 104, 105, 106, 256)
- **Primary Issue**: Uses `| default()` for ansible_net_* facts
- **Root Cause**: These should be guaranteed by gather_facts
- **Approach**:
  1. Verify gather_facts is always called before this role
  2. Consider using `assert` to validate facts are present
  3. OR define facts in role defaults/main.yml
- **Status**: ⬜ TODO

### TODO 3.3: Fix get-storage-output.yml (4 violations)
- **File**: `ansible-content/roles/space-management/tasks/get-storage-output.yml`
- **Violations**: 4 (lines 40, 41, 42, 43)
- **Primary Issue**: Uses `| default(false)` to check if results are skipped
- **Approach**:
  1. Refactor to check result structure differently
  2. OR define defaults in role defaults/main.yml
- **Status**: ⬜ TODO

### TODO 3.4: Fix remaining files (11 violations across 12 files)
- **Files**:
  - `roles/fortios-upgrade/tasks/image-installation.yml` (4)
  - `roles/cisco-nxos-upgrade/tasks/epld-installation.yml` (3)
  - `roles/common/tasks/network-resources-gathering.yml` (2)
  - `roles/common/tasks/config-backup.yml` (2)
  - `roles/common/tasks/metrics-export.yml` (1)
  - `roles/common/tasks/update-rollback-state.yml` (1)
  - `roles/cisco-nxos-upgrade/tasks/image-loading.yml` (1)
  - `roles/opengear-upgrade/tasks/image-installation.yml` (1)
  - `roles/opengear-upgrade/tasks/image-installation-legacy.yml` (1)
  - `roles/opengear-upgrade/tasks/image-loading-legacy.yml` (1)
  - `playbooks/network-validation.yml` (1)
- **Status**: ⬜ TODO

### TODO 3.5: Verify all `| default()` fixes and run tests
- **Action**: After fixing all 65 violations:
  ```bash
  ansible-lint ansible-content/ --offline --parseable-severity
  ./tests/run-all-tests.sh
  ```
- **Expected**: All tests pass, no linting errors
- **Status**: ⬜ TODO (depends on 3.1-3.4)

---

## PHASE 4: PLATFORM ORGANIZATION REFACTORING - 8 Files (2-3 HOURS)

Consolidate multiple separate `when: platform ==` clauses into single blocks.

### TODO 4.1: Refactor parse-storage-output.yml
- **File**: `ansible-content/roles/space-management/tasks/parse-storage-output.yml`
- **Current Issue**: 4 separate platform tasks (lines 12, 21, 30, 39)
- **Approach**:
  1. Create 4 separate blocks (one per platform)
  2. Each block has `when: platform == 'xxx'`
  3. Move all platform-specific tasks INTO the block
- **Status**: ⬜ TODO

### TODO 4.2: Refactor get-storage-output.yml
- **File**: `ansible-content/roles/space-management/tasks/get-storage-output.yml`
- **Current Issue**: 4 separate platform tasks (lines 13, 21, 28, 34)
- **Status**: ⬜ TODO

### TODO 4.3: Refactor connectivity-check.yml
- **File**: `ansible-content/roles/common/tasks/connectivity-check.yml`
- **Current Issue**: 4 separate platform tasks (lines 79, 120, 141, 160)
- **Status**: ⬜ TODO

### TODO 4.4: Refactor config-backup.yml
- **File**: `ansible-content/roles/common/tasks/config-backup.yml`
- **Current Issue**: 4 separate platform tasks (lines 27, 34, 42, 50)
- **Status**: ⬜ TODO

### TODO 4.5: Refactor image-loading.yml playbook
- **File**: `ansible-content/playbooks/image-loading.yml`
- **Current Issue**: 4 separate platform blocks
- **Status**: ⬜ TODO

### TODO 4.6: Refactor image-installation.yml playbook
- **File**: `ansible-content/playbooks/image-installation.yml`
- **Current Issue**: 4 separate platform blocks
- **Status**: ⬜ TODO

### TODO 4.7: Refactor compliance-audit.yml playbook
- **File**: `ansible-content/playbooks/compliance-audit.yml`
- **Current Issue**: 4 separate platform blocks
- **Status**: ⬜ TODO

### TODO 4.8: Refactor platform-assessment.yml
- **File**: `ansible-content/roles/space-management/tasks/platform-assessment.yml`
- **Current Issue**: 3 separate platform blocks (lines 43, 51, 58)
- **Status**: ⬜ TODO

### TODO 4.9: Verify platform refactoring and run tests
- **Action**: After refactoring all 8 files:
  ```bash
  ./tests/run-all-tests.sh
  ansible-lint ansible-content/ --offline --parseable-severity
  ```
- **Expected**: All tests pass, improved code organization
- **Status**: ⬜ TODO (depends on 4.1-4.8)

---

## PHASE 5: FINAL VALIDATION (30 MIN)

### TODO 5.1: Run complete test suite
```bash
./tests/run-all-tests.sh
```
- **Expected**: Passed: 22, Failed: 0
- **Status**: ⬜ TODO (depends on phases 1-4)

### TODO 5.2: Run ansible-lint
```bash
ansible-lint ansible-content/ --offline --parseable-severity
```
- **Expected**: 0 errors
- **Status**: ⬜ TODO

### TODO 5.3: Run yamllint
```bash
yamllint ansible-content/
```
- **Expected**: 0 errors
- **Status**: ⬜ TODO

### TODO 5.4: Run pre-commit checks
```bash
# Full pre-commit validation
ansible-playbook --syntax-check ansible-content/playbooks/main-upgrade-workflow.yml \
  --extra-vars="target_hosts=localhost target_firmware=test.bin maintenance_window=true max_concurrent=1"
```
- **Expected**: All checks pass
- **Status**: ⬜ TODO

### TODO 5.5: Commit all fixes with comprehensive message
```bash
git add -A
git commit -m "fix: bring codebase to 100% compliance with CLAUDE.md standards

- Fix 10 'and' clauses in when conditions → YAML list syntax
- Convert 92 folded scalars in debug/fail messages → YAML list syntax
- Remove 65 | default() violations from playbooks and tasks
- Refactor 8 files for platform organization (single when per platform)
- All 22 tests pass, ansible-lint clean, yamllint clean

This brings the codebase into full compliance with:
- CLAUDE.md strict standards
- .claude/instructions.md guidelines
- Pre-commit quality gates

Files modified: 68 files
Violations fixed: 197+
Compliance status: NOW 100%
"
```
- **Status**: ⬜ TODO (final step after all tests pass)

---

## SUMMARY

| Phase | Task Count | Effort | Priority | Status |
|---|---|---|---|---|
| Phase 1: `and` clauses | 4 | 30 min | CRITICAL | ⬜ |
| Phase 2: Folded scalars | 8 | 3-4 hrs | CRITICAL | ⬜ |
| Phase 3: `\| default()` | 5 | 2-3 hrs | CRITICAL | ⬜ |
| Phase 4: Platform org | 9 | 2-3 hrs | HIGH | ⬜ |
| Phase 5: Validation | 5 | 30 min | CRITICAL | ⬜ |
| **TOTAL** | **31** | **6-8 hrs** | **BLOCKING** | **0% DONE** |

---

## CRITICAL NOTES

1. **Order Matters**: Do phases in order (1→2→3→4→5). Earlier fixes may affect later fixes.

2. **netbox_dynamic.yml Blocker**: This file has 41 violations. Requires decision on:
   - Should it use `group_vars/all.yml`?
   - Should it use environment variables with validation?
   - Should defaults be in role defaults?
   - **ACTION NEEDED**: Clarify proper approach before fixing

3. **Test Suite**: Run `./tests/run-all-tests.sh` after each phase to catch regressions

4. **Linting**: Run `ansible-lint` and `yamllint` frequently to validate fixes

5. **Git Discipline**: Create separate commits for each major phase for easier review/rollback

---

**Generated**: November 3, 2025
**Status**: Ready for execution
**Blocking**: YES - Cannot deploy without these fixes
