# Test Data Consolidation Reference

**Purpose**: Detailed reference for the shared test data pattern. Use this when creating or modifying test files.

**Link from CLAUDE.md**: Section 3b references this file for detailed guidance.

---

## Single Source of Truth for Test Data

All test playbooks MUST use `tests/shared-test-vars.yml` for device configurations and test scenarios.

### Pattern - How to Reference Shared Test Variables

**✅ CORRECT: All test playbooks reference shared-test-vars.yml**
```yaml
- name: My Test Suite
  hosts: localhost
  gather_facts: false
  vars_files:
    - ../shared-test-vars.yml    # Path depends on file location
  vars:
    # Playbook-specific variables only
    test_environment: true

  tasks:
    - name: Use shared variables
      debug:
        msg: "Testing device: {{ cisco_nxos_devices.n9k_c93180yc_ex.device_model }}"
```

### What's in `tests/shared-test-vars.yml`

**Device Configurations (all platforms)**
```yaml
cisco_nxos_devices:
  n9k_c93180yc_ex:     # ISSU + EPLD capable
  n9k_c9336c_fx2:      # Non-ISSU capable
  n9k_c93240yc_fx2:    # Multi-EPLD capable

cisco_iosxe_devices:
  isr4431:             # Router with install mode
  c9300_48u:           # Switch without install mode

fortios_devices:
  fortigate_600e_primary:
  fortigate_600e_secondary:
  fortigate_200f:
  fortigate_100f:

opengear_devices:
  cm7100_legacy:       # Legacy architecture
  om7200_legacy:
  cm8100_modern:       # Modern architecture
  om2200_modern:
```

**Firmware Upgrade Scenarios (7 common paths)**
```yaml
firmware_upgrade_scenarios:
  nxos_9310_to_10121:
  nxos_10010_to_1023m:
  iosxe_1612_to_1706:
  fortios_648_to_724:
  fortios_701_to_724:
  opengear_516_to_518:
  opengear_24110_to_25070:
```

**Test Environment Settings**
```yaml
test_environment:
  base_firmware_path: "/opt/firmware"
  base_backup_path: "/opt/backups"
  base_baseline_path: "/opt/baselines"
```

### Benefits of Consolidation

- **Eliminated 50+ duplications**: Device configs, firmware pairs
- **Easier maintenance**: Update device config once, all tests use it
- **New test creation**: Copy scenarios from shared-test-vars instead of hardcoding
- **Consistency**: All tests use same device definitions

### Path Reference Rules

| File Location | vars_files Path |
|---|---|
| `tests/integration-tests/*.yml` | `../shared-test-vars.yml` |
| `tests/unit-tests/*.yml` | `../shared-test-vars.yml` |
| `tests/validation-tests/*.yml` | `../shared-test-vars.yml` |
| `tests/vendor-tests/*.yml` | `../shared-test-vars.yml` |
| `tests/playbook-tests/**/*.yml` | `../../shared-test-vars.yml` (nested one level deeper) |

### Included Task Files (not playbooks)

**Don't add vars_files to task files** - parent playbook handles loading.

Just add this comment:
```yaml
---
# This is an included task file
# Note: This is an included task file, shared-test-vars loaded by parent playbook

- name: Task in included file
```

**Examples of included task files:**
- `tests/integration-tests/test_phase_logic.yml`
- `tests/integration-tests/test_scenario_logic.yml`
- `tests/unit-tests/test_error_scenario.yml`
- `tests/unit-tests/test_template_scenario.yml`
- `tests/unit-tests/test_workflow_scenario.yml`

---

## When Creating New Test Files

1. **Copy structure from existing test** in same directory
2. **Add vars_files reference** using correct path (see table above)
3. **Use devices/scenarios from shared-test-vars.yml** - DO NOT hardcode
4. **Run full test suite** to verify: `./tests/run-all-tests.sh`

### Example: Creating New Vendor Test

```yaml
---
# New Vendor Platform Tests
# Tests vendor-specific functionality

- name: New Vendor Platform Tests
  hosts: localhost
  gather_facts: false
  vars_files:
    - ../shared-test-vars.yml
  vars:
    role_path: "{{ playbook_dir }}/../../ansible-content/roles/new-vendor-upgrade"

  tasks:
    - name: Get device config from shared variables
      set_fact:
        test_device: "{{ new_vendor_devices.device_model_1 }}"

    - name: Validate vendor role structure
      stat:
        path: "{{ role_path }}"
      register: vendor_role_check

    - name: Assert vendor role exists
      assert:
        that:
          - vendor_role_check.stat.exists
          - vendor_role_check.stat.isdir
        fail_msg: "Vendor role directory not found"
        success_msg: "✓ Vendor role structure validated"
```

---

## Common Patterns from Shared Variables

### Device Configuration Access
```yaml
# Get a device config
- set_fact:
    device: "{{ cisco_nxos_devices.n9k_c93180yc_ex }}"

# Get device model
debug: msg="{{ cisco_nxos_devices.n9k_c93180yc_ex.device_model }}"

# Iterate over all devices in a platform
loop: "{{ cisco_nxos_devices | dict2items }}"
loop_control:
  loop_var: device_entry
```

### Firmware Scenario Access
```yaml
# Get a firmware upgrade scenario
- set_fact:
    upgrade_path: "{{ firmware_upgrade_scenarios.nxos_9310_to_10121 }}"

# Use in upgrade validation
- assert:
    that:
      - target_version == firmware_upgrade_scenarios.nxos_9310_to_10121.target
```

### Test Environment Settings
```yaml
# Use in file operations
- set_fact:
    firmware_dir: "{{ test_environment.base_firmware_path }}/nxos"
```

---

## Related Files

- **CLAUDE.md Section 3b** - Quick reference in main project guide
- **tests/shared-test-vars.yml** - The actual consolidated data
- **tests/TEST-CONSOLIDATION-IMPLEMENTATION.md** - Implementation details
- **tests/fixtures/test-device-registry.yml** - Device registry reference

---

**Last Updated**: November 4, 2025
**Status**: Reference for test development
