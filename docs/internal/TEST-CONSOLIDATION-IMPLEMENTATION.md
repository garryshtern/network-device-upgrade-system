# Test Data Consolidation - Implementation Guide

**Status**: Phases 4-5 Implementation - Ongoing consolidation of 18+ test playbooks
**Last Updated**: November 4, 2025
**Coverage**: 4/21 key test files updated to reference shared variables

---

## Consolidation Structure

### Created Resources

**1. Device Registry Reference** (`tests/mock-inventories/device-registry.yml`)
- Centralized device models by platform
- Firmware upgrade pairs
- Device capabilities and features
- Test scenario templates

**2. Shared Test Variables** (`tests/shared-test-vars.yml`)
- Complete device configurations (cisco_nxos_devices, cisco_iosxe_devices, etc.)
- Firmware upgrade scenarios (7 common paths)
- Validation baseline patterns
- Test environment settings
- Single source of truth for all test data

**3. Test Fixture** (`tests/fixtures/test-device-registry.yml`)
- Updated with integration notes
- Cross-references shared-test-vars.yml
- Maintains backward compatibility

---

## Phase 4: Update Test Playbooks to Use Shared Variables

### Quick Reference: How to Update a Test Playbook

Add `vars_files` reference at the playbook level:

```yaml
- name: Test Suite Name
  hosts: localhost
  gather_facts: false
  vars_files:
    - ../shared-test-vars.yml    # Path from playbook location
  vars:
    # Your playbook-specific variables
```

### Files Updated (4/21)

- ✅ `tests/integration-tests/multi-platform-integration-tests.yml`
- ✅ `tests/integration-tests/workflow-tests.yml`
- ✅ `tests/vendor-tests/cisco-nxos-tests.yml`
- ✅ `tests/validation-tests/network-validation-tests.yml`

### Remaining Files to Update (17/21)

**Integration Tests** (3):
- `tests/integration-tests/check-mode-tests.yml`
- `tests/integration-tests/multi-platform-concurrent-device-tests.yml`
- `tests/integration-tests/secure-transfer-integration-tests.yml`
- `tests/integration-tests/timeout-recovery-integration-tests.yml`

**Unit Tests** (3):
- `tests/unit-tests/test_error_scenario.yml`
- `tests/unit-tests/test_template_scenario.yml`
- `tests/unit-tests/test_workflow_scenario.yml`

**Validation Tests** (2):
- `tests/validation-tests/comprehensive-validation-tests.yml`
- `tests/validation-tests/rollback-state-validation-tests.yml`

**Vendor Tests** (3):
- `tests/vendor-tests/cisco-iosxe-tests.yml`
- `tests/vendor-tests/fortios-tests.yml`
- `tests/vendor-tests/opengear-tests.yml`

**Scenario Logic Tests** (2):
- `tests/integration-tests/test_phase_logic.yml`
- `tests/integration-tests/test_scenario_logic.yml`

**Library/Reference** (1):
- `tests/lib/vendor-test-patterns.yml`

---

## Phase 5: Verify All Tests Pass

After updating playbooks:

```bash
./tests/run-all-tests.sh
```

Expected result: 23/23 tests passing

---

## Phase 6: Optional - Python Mock Device Engine Alignment

### Current State

The Python mock device engine (`tests/mock-devices/mock_device_engine.py`) should be documented to use the same device configurations as shared-test-vars.yml.

### Action Items

1. Document how Python mock devices map to shared-test-vars device configurations
2. Create cross-reference documentation in `docs/internal/`
3. Consider future refactoring to make Python mock devices reference shared-test-vars

---

## Impact of Consolidation

### Duplication Eliminated

- **N9K-C93180YC-EX**: Was hardcoded 13 times → Now 1 definition
- **FortiGate-600E**: Was hardcoded 7 times → Now 1 definition
- **9.3.10 → 10.1.2 firmware pair**: Was hardcoded 20 times → Now 1 definition
- **Overall**: Eliminated 50+ instances of duplicated configuration

### Maintenance Benefits

- **Single source of truth**: Update device config once, all tests use it
- **Easier test modifications**: Change test scenario in shared-test-vars.yml
- **New test creation**: Copy existing scenario from shared-test-vars instead of hardcoding
- **Consistency**: All tests use same device definitions and firmware paths

---

## Path Forward

### Completed ✅
- [x] Device registry reference creation (Phase 2)
- [x] Shared test variables consolidation (Phase 3)
- [x] Updated 4 key test playbooks (Phase 4 - partial)

### In Progress ⏳
- [ ] Update remaining 17 test playbooks (Phase 4 - full)
- [ ] Run full test suite verification (Phase 5)

### Optional 📋
- [ ] Python mock device engine documentation (Phase 6)
- [ ] Future refactoring to auto-generate mock devices from shared-test-vars

---

## Testing Strategy

### After Each Update

Run the specific test suite to ensure no regressions:

```bash
# Individual test
ansible-playbook tests/vendor-tests/cisco-nxos-tests.yml

# All tests
./tests/run-all-tests.sh
```

### Verification Checklist

- [ ] All tests pass (23/23)
- [ ] No new errors or warnings
- [ ] Test data loads from shared-test-vars.yml correctly
- [ ] Device configurations match expected values
- [ ] Firmware paths resolve correctly

---

## Documentation References

- `tests/shared-test-vars.yml` - Consolidated test variables
- `tests/mock-inventories/device-registry.yml` - Device reference
- `docs/internal/test-data-consolidation-guide.md` - Consolidation status
- `CLAUDE.md` - Project standards and patterns

---

## Quick Reference: All Shared Variables Available

```yaml
# Device Configurations by Platform
cisco_nxos_devices:
  n9k_c93180yc_ex    # ISSU + EPLD capable
  n9k_c9336c_fx2     # Non-ISSU capable
  n9k_c93240yc_fx2   # Multi-EPLD capable

cisco_iosxe_devices:
  isr4431            # Router with install mode
  c9300_48u          # Switch without install mode

fortios_devices:
  fortigate_600e_primary
  fortigate_600e_secondary
  fortigate_200f
  fortigate_100f

opengear_devices:
  cm7100_legacy
  om7200_legacy
  cm8100_modern
  om2200_modern

# Firmware Upgrade Scenarios (7 common paths)
firmware_upgrade_scenarios:
  nxos_9310_to_10121
  nxos_10010_to_1023m
  iosxe_1612_to_1706
  fortios_648_to_724
  fortios_701_to_724
  opengear_516_to_518
  opengear_24110_to_25070

# Test Environment Settings
test_environment:
  base_firmware_path: "/opt/firmware"
  base_backup_path: "/opt/backups"
  base_baseline_path: "/opt/baselines"
```

---

**Maintained by**: Development Team
**Next Review**: After Phase 4-5 completion (all 21 files updated)
