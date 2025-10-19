# High Priority TODO - Code Duplication Removal

**Created:** 2025-10-19
**Target Completion:** Week 1
**Estimated Impact:** ~250 lines saved, significant complexity reduction

---

## 🔴 Task 1: Abstract Common Upgrade State Initialization

**Priority:** ⚠️ CRITICAL
**Estimated Time:** 2-3 hours
**Lines Saved:** ~25 lines
**Complexity Reduction:** High

### Problem
All 5 vendor roles duplicate identical upgrade state fields:

```yaml
# Duplicated in: cisco-iosxe, cisco-nxos, fortios, metamako, opengear
{role}_upgrade_state:
  device: "{{ inventory_hostname }}"              # IDENTICAL
  current_version: ""                              # IDENTICAL
  target_version: "{{ target_firmware_version }}" # IDENTICAL
  # ... then platform-specific fields
```

### Implementation Steps

- [ ] **Step 1.1:** Create `common_upgrade_state` base structure in `group_vars/all.yml`
  ```yaml
  # Add to group_vars/all.yml
  common_upgrade_state:
    device: "{{ inventory_hostname }}"
    current_version: ""
    target_version: "{{ target_firmware }}"
    upgrade_start_time: ""
    upgrade_end_time: ""
    upgrade_status: "pending"
  ```

- [ ] **Step 1.2:** Update `cisco-iosxe-upgrade/defaults/main.yml:34-40`
  - Remove duplicate base fields
  - Extend `common_upgrade_state` with IOS-XE specific fields
  - Example: `iosxe_upgrade_state: "{{ common_upgrade_state | combine(iosxe_specific_fields) }}"`

- [ ] **Step 1.3:** Update `cisco-nxos-upgrade/defaults/main.yml:30-36`
  - Remove duplicate base fields
  - Extend `common_upgrade_state` with NX-OS specific fields

- [ ] **Step 1.4:** Update `fortios-upgrade/defaults/main.yml:30-38`
  - Remove duplicate base fields
  - Extend `common_upgrade_state` with FortiOS specific fields

- [ ] **Step 1.5:** Update `metamako-mos-upgrade/defaults/main.yml:30-37`
  - Remove duplicate base fields
  - Extend `common_upgrade_state` with Metamako specific fields

- [ ] **Step 1.6:** Update `opengear-upgrade/defaults/main.yml:30-37`
  - Remove duplicate base fields
  - Extend `common_upgrade_state` with Opengear specific fields

- [ ] **Step 1.7:** Remove `| default('')` from target_version (already defined globally)

### Testing Requirements

- [ ] Run syntax check on all modified role defaults
- [ ] Run vendor-specific tests for all 5 platforms
- [ ] Verify upgrade state initialization in check mode
- [ ] Confirm all tests pass (23/23)

### Files to Modify

```
ansible-content/inventory/group_vars/all.yml
ansible-content/roles/cisco-iosxe-upgrade/defaults/main.yml
ansible-content/roles/cisco-nxos-upgrade/defaults/main.yml
ansible-content/roles/fortios-upgrade/defaults/main.yml
ansible-content/roles/metamako-mos-upgrade/defaults/main.yml
ansible-content/roles/opengear-upgrade/defaults/main.yml
```

### Success Criteria

- ✅ No duplicate base fields across vendor roles
- ✅ All vendor roles extend common base structure
- ✅ All tests pass
- ✅ Code reduction: ~25 lines

---

## 🔴 Task 2: Consolidate Wait-for-Connection Patterns

**Priority:** HIGH
**Estimated Time:** 1-2 hours
**Lines Saved:** ~20 lines
**Complexity Reduction:** Medium

### Problem
`common/tasks/wait-for-device.yml` exists but is NOT used in 3 key playbooks that still use raw `wait_for_connection`:

**Current Locations:**
1. `playbooks/main-upgrade-workflow.yml:295-296`
2. `playbooks/emergency-rollback.yml`
3. `playbooks/image-installation.yml`

### Implementation Steps

- [ ] **Step 2.1:** Replace in `main-upgrade-workflow.yml:295-296`
  ```yaml
  # BEFORE:
  - name: Wait for device to come back online
    ansible.builtin.wait_for_connection:
      timeout: "{{ connectivity_timeout }}"
      delay: 30

  # AFTER:
  - name: Wait for device to come back online
    ansible.builtin.include_role:
      name: common
      tasks_from: wait-for-device
    vars:
      wait_timeout: "{{ connectivity_timeout }}"
      wait_delay: 30
  ```

- [ ] **Step 2.2:** Find and replace in `emergency-rollback.yml`
  - Search for `ansible.builtin.wait_for_connection`
  - Replace with `include_role` pattern above

- [ ] **Step 2.3:** Find and replace in `image-installation.yml`
  - Search for `ansible.builtin.wait_for_connection`
  - Replace with `include_role` pattern above

- [ ] **Step 2.4:** Verify no other playbooks use raw `wait_for_connection`
  ```bash
  grep -r "ansible.builtin.wait_for_connection" ansible-content/playbooks/
  ```

### Testing Requirements

- [ ] Run syntax check on all modified playbooks
- [ ] Run workflow integration tests
- [ ] Test emergency rollback scenario
- [ ] Verify connection timeout behavior unchanged
- [ ] Confirm all tests pass (23/23)

### Benefits

- ✅ Consistent timeout handling across all playbooks
- ✅ Better authentication failure detection (built into wait-for-device.yml)
- ✅ Centralized connection retry logic
- ✅ Easier to modify timeout behavior globally

### Files to Modify

```
ansible-content/playbooks/main-upgrade-workflow.yml
ansible-content/playbooks/emergency-rollback.yml
ansible-content/playbooks/image-installation.yml
```

### Success Criteria

- ✅ No raw `wait_for_connection` in playbooks
- ✅ All playbooks use `common/wait-for-device.yml`
- ✅ All tests pass
- ✅ Code reduction: ~20 lines

---

## 🔴 Task 3: Abstract Platform-Specific Conditionals

**Priority:** HIGH
**Estimated Time:** 3-4 hours
**Lines Saved:** ~52 lines
**Complexity Reduction:** High

### Problem
26 platform conditionals across playbooks use repeated patterns:

```yaml
# Repeated 26 times across playbooks
when:
  - ansible_network_os is defined
  - ansible_network_os == 'cisco.nxos.nxos'  # or other platforms
```

### Implementation Steps

- [ ] **Step 3.1:** Create custom filter plugin `filter_plugins/platform_filters.py`
  ```python
  # ansible-content/filter_plugins/platform_filters.py
  def is_platform(network_os, platform_name):
      """
      Check if network_os matches platform name.
      Handles both FQCN and short names.

      Examples:
        - is_platform('cisco.nxos.nxos', 'nxos') -> True
        - is_platform('nxos', 'nxos') -> True
        - is_platform('cisco.ios.ios', 'nxos') -> False
      """
      if not network_os:
          return False

      platform_map = {
          'nxos': ['cisco.nxos.nxos', 'nxos'],
          'ios': ['cisco.ios.ios', 'ios', 'iosxe'],
          'fortios': ['fortinet.fortios.fortios', 'fortios'],
          'metamako': ['metamako_mos', 'metamako'],
          'opengear': ['opengear', 'opengear_og']
      }

      return network_os.lower() in [p.lower() for p in platform_map.get(platform_name.lower(), [])]

  class FilterModule(object):
      def filters(self):
          return {'is_platform': is_platform}
  ```

- [ ] **Step 3.2:** Update `main-upgrade-workflow.yml` (10 occurrences)
  ```yaml
  # BEFORE:
  when:
    - ansible_network_os is defined
    - platform == 'nxos'

  # AFTER:
  when: ansible_network_os | is_platform('nxos')
  ```

- [ ] **Step 3.3:** Update `compliance-audit.yml` (6 occurrences)

- [ ] **Step 3.4:** Update `common/tasks/health-check.yml` (4 occurrences)

- [ ] **Step 3.5:** Update remaining playbooks (6 occurrences)

- [ ] **Step 3.6:** Search for ALL platform conditionals
  ```bash
  grep -r "ansible_network_os is defined" ansible-content/
  grep -r "platform == " ansible-content/
  ```

### Testing Requirements

- [ ] Create unit tests for `is_platform` filter
- [ ] Run syntax check on all modified playbooks
- [ ] Test each platform-specific code path
- [ ] Verify filter works with FQCN and short names
- [ ] Test undefined/null network_os values
- [ ] Confirm all tests pass (23/23)

### Files to Modify

```
ansible-content/filter_plugins/platform_filters.py (NEW)
ansible-content/playbooks/main-upgrade-workflow.yml
ansible-content/playbooks/compliance-audit.yml
ansible-content/playbooks/network-validation.yml
ansible-content/roles/common/tasks/health-check.yml
ansible-content/roles/common/tasks/connectivity-check.yml
... (and others with platform conditionals)
```

### Success Criteria

- ✅ Custom filter plugin created and tested
- ✅ All platform conditionals use `is_platform` filter
- ✅ Handles both FQCN and short platform names
- ✅ All tests pass
- ✅ Code reduction: ~52 lines

---

## 📊 High Priority Summary

| Task | Priority | Time | Lines Saved | Status |
|------|----------|------|-------------|--------|
| 1. Abstract Upgrade State | CRITICAL | 2-3h | ~25 | ⬜ Not Started |
| 2. Consolidate Wait Patterns | HIGH | 1-2h | ~20 | ⬜ Not Started |
| 3. Abstract Platform Conditionals | HIGH | 3-4h | ~52 | ⬜ Not Started |
| **TOTAL** | | **6-9h** | **~97 lines** | **0/3 Complete** |

---

## 🎯 Execution Order

### Recommended Sequence:
1. **Task 2 first** (easiest, quick win, 1-2 hours)
2. **Task 1 second** (medium complexity, high impact, 2-3 hours)
3. **Task 3 last** (most complex, requires filter plugin, 3-4 hours)

### Rationale:
- Start with easiest task to build momentum
- Task 2 has no dependencies, can be done immediately
- Task 1 affects role defaults, test thoroughly before Task 3
- Task 3 is most complex and benefits from having clean codebase

---

## ✅ Validation Checklist

After completing ALL high priority tasks:

- [ ] All 23 tests pass
- [ ] `ansible-lint` returns 0 warnings
- [ ] `yamllint` returns 0 errors
- [ ] Syntax check passes on all playbooks
- [ ] No duplicate upgrade state fields
- [ ] No raw `wait_for_connection` in playbooks
- [ ] All platform conditionals use `is_platform` filter
- [ ] Code reduced by ~97 lines
- [ ] Documentation updated (CLAUDE.md, IMPROVEMENT_TODO.md)
- [ ] Git commits follow project standards

---

## 📝 Notes

- **MANDATORY:** Run full test suite after EACH task completion
- **ZERO TOLERANCE:** Any test failures block next task
- **UPDATE TESTS:** Ensure test files updated if validation logic changes
- **COMMIT FREQUENTLY:** One commit per completed task with clear message
- **DOCUMENT CHANGES:** Update IMPROVEMENT_TODO.md as tasks complete
