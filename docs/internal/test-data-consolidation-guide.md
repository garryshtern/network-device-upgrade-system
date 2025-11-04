# Test Data Consolidation Guide

## Overview

This guide documents the consolidation of scattered test data into centralized locations to eliminate duplication and improve maintainability.

**Status**: Consolidation in progress
**Coverage**: 100% of 79 test data files analyzed
**Goal**: Single source of truth for all test fixtures, inventories, and device data

---

## Current State Analysis

### Test Data Scattered Across (79 files):

1. **Fixtures** (2 files)
   - `tests/fixtures/test-device-registry.yml` ✓ Centralized
   - `tests/fixtures/mock-storage-data.yml` ✓ Centralized

2. **Inventories** (4 files)
   - `tests/mock-inventories/all-platforms.yml` - Overlapping with test-device-registry
   - `tests/mock-inventories/single-platform.yml` - Overlapping
   - `tests/mock-inventories/group_vars/all.yml` - Global auth/test settings
   - `tests/container-tests/mockups/inventory/production.yml` - Malformed Metamako section

3. **Library/Patterns** (1 file)
   - `tests/lib/vendor-test-patterns.yml` ✓ Centralized

4. **Variables** (1 file + distributed in 20+ playbooks)
   - `tests/test-vars.yml` - Scattered across playbooks

5. **Test Playbooks with Embedded Data** (20+ files)
   - Hardcoded device definitions in 18+ test playbooks
   - Should reference `test-device-registry.yml` instead

6. **Python Mock Device Engine** (1 file)
   - `tests/mock-devices/mock_device_engine.py` - Default configurations
   - Contains duplicate device definitions

7. **Test Reports** (7 JSON files + logs)
   - Historical test execution results

---

## Duplication Analysis

### High-Frequency Duplicates:

| Item | Occurrences | Files | Issue |
|------|-------------|-------|-------|
| N9K-C93180YC-EX (NX-OS) | 16 times | 10 files | Device model hardcoded everywhere |
| 9.3.10 → 10.1.2 (NX-OS) | 8 times | 8 files | Firmware pair duplicated |
| ISR4431 (IOS-XE) | 5+ times | 4 files | Device model duplicated |
| FortiGate-600E | 7+ times | 5 files | Device model duplicated |

**Root Cause**: Test data intentionally duplicated in:
- Centralized fixtures (primary source)
- Mock inventories (for different test scenarios)
- Individual playbooks (hardcoded for specific tests)
- Python mock device engine (default configurations)

---

## Consolidation Plan

### Phase 1: Centralize All Device Definitions

**Target**: Single source of truth for all device data

**Current Primary Source**:
- `tests/fixtures/test-device-registry.yml` (300+ lines)
  - ✓ Contains firmware version pairs (6 pairs)
  - ✓ Contains device models by platform
  - ✓ Contains test device definitions
  - ✓ Contains inventory defaults

**Secondary Sources (to consolidate into primary)**:
- `tests/mock-inventories/all-platforms.yml` - Extract unique devices
- `tests/mock-inventories/single-platform.yml` - Already in registry
- `tests/container-tests/mockups/inventory/production.yml` - Extract/fix Metamako

**Action Items**:
1. ✓ Already centralized in test-device-registry.yml
2. Remove duplication from all-platforms.yml (use registry lookups)
3. Update production.yml to use registry lookups
4. Fix malformed Metamako section in production.yml

**Status**: PARTIALLY COMPLETE - test-device-registry exists but other files still have duplicates

---

### Phase 2: Consolidate Inventory Files

**Target**: 3 inventory files → 2 inventory files (all-platforms + single-platform)

**Current Inventories**:
1. `all-platforms.yml` - 15 devices, 5 platforms (242 lines)
2. `single-platform.yml` - 1 device, NX-OS focused (20 lines)
3. `production.yml` - 10 devices, 5 platforms, container testing (120 lines)

**Consolidation Strategy**:
- Keep `all-platforms.yml` as primary inventory
- Keep `single-platform.yml` for focused NX-OS testing
- Merge `production.yml` into `all-platforms.yml` (remove duplicates)
- Fix Metamako section in merged inventory

**Global Variables**:
- Consolidate `group_vars/all.yml` (34 lines)
- Move auth variables to `test-device-registry.yml` defaults section
- Keep vault references for sensitive data

**Status**: TODO

---

### Phase 3: Consolidate Test Variables

**Target**: Eliminate scattered variable definitions

**Current Scattered Variables**:
1. `tests/test-vars.yml` - Platform-agnostic variables
2. Inline in 20+ test playbooks
3. Mock device engine defaults

**Consolidation Strategy**:
- Keep `test-vars.yml` as reference document
- Expand `test-device-registry.yml` to include:
  - Platform-specific variables
  - Error scenario variables
  - Test mode variables
  - InfluxDB configuration
- Update playbooks to use registry lookups instead of hardcoded values

**Status**: TODO

---

### Phase 4: Update Test Playbooks to Use Centralized Data

**Target**: Eliminate 18+ files with hardcoded device data

**Current Hardcoded Data**:
- NX-OS: `cisco-nxos-tests.yml`, `rollback-failure-tests.yml`, etc.
- IOS-XE: `cisco-iosxe-tests.yml`, etc.
- FortiOS: `fortios-tests.yml`, etc.
- Critical gaps: 8 test files
- Unit tests: 6 test files
- Integration tests: 4 test files

**Refactoring Strategy**:
- Replace hardcoded device definitions with registry lookups
- Example: `device_vars: "{{ test_device_registry.test_devices.nxos.issu_capable_with_epld }}"`
- Already applied to: cisco-nxos-tests.yml, cisco-iosxe-tests.yml, fortios-tests.yml
- **Status**: PARTIALLY COMPLETE - 8 files updated, 18+ remaining

---

### Phase 5: Update Mock Device Engine

**Target**: Remove duplicate device definitions from Python mock engine

**Current Issues**:
- `mock_device_engine.py` (1,315 lines) contains hardcoded default device configs
- Duplicates test-device-registry.yml device models
- No import of centralized device definitions

**Consolidation Strategy**:
- Load device definitions from `test-device-registry.yml` instead of hardcoding
- Implement YAML loader in Python
- Reference registry for default configurations
- Keep behavior simulation (error injection, etc.)

**Status**: TODO

---

### Phase 6: Mock Firmware Storage

**Target**: Populate empty firmware directories or remove them

**Current State**:
- 4 empty firmware directories exist:
  - `/tests/container-tests/mockups/firmware/cisco.nxos/`
  - `/tests/container-tests/mockups/firmware/cisco.ios/`
  - `/tests/container-tests/mockups/firmware/fortios/`
  - `/tests/container-tests/mockups/firmware/opengear/`

**Options**:
1. **Populate with mock firmware files** (stubs or minimal files)
   - Size: 1-10 MB per file (for testing)
   - Purpose: Test transfer and verification operations
2. **Remove empty directories**
   - If not used in active tests
   - Check all test files for references

**Status**: TODO - Determine if needed for active tests

---

## Benefits of Consolidation

### Duplication Elimination:
- **Device Models**: 16 hardcoded references → 1 centralized location
- **Firmware Pairs**: 8 hardcoded references → 1 centralized location
- **Code Reduction**: ~250+ lines of duplicate device data eliminated

### Maintainability:
- **Single Source of Truth**: Update once, applies everywhere
- **Consistency**: All tests use same device definitions
- **Scalability**: Easy to add new test devices
- **Testability**: New tests automatically use latest device registry

### Code Quality:
- **Reduced Maintenance Burden**: Change one device → all tests updated
- **Reduced Test Errors**: No more conflicting device definitions
- **Improved Readability**: Playbooks cleaner without embedded data
- **Better Documentation**: Registry serves as data dictionary

---

## Implementation Progress

### Completed:
- ✓ `tests/fixtures/test-device-registry.yml` - Centralized (300+ lines)
- ✓ `tests/lib/vendor-test-patterns.yml` - Centralized (120 lines)
- ✓ `tests/fixtures/mock-storage-data.yml` - Centralized (1,068 bytes)
- ✓ Updated 8 test files to use registry lookups (cisco-nxos-tests.yml, cisco-iosxe-tests.yml, fortios-tests.yml, unit-tests/workflow-logic.yml, etc.)
- ✓ ~250+ lines of duplication eliminated

### In Progress:
- Consolidate remaining inventory files (production.yml into all-platforms.yml)
- Update remaining 18+ test playbooks to use registry lookups

### Pending:
- Consolidate test variables from scattered locations
- Update mock device engine to load from registry
- Populate or remove empty firmware directories

---

## File Organization After Consolidation

```
tests/
├── fixtures/
│   ├── test-device-registry.yml       # Master device registry
│   └── mock-storage-data.yml          # Mock filesystem responses
├── lib/
│   ├── test-common.sh                 # Shell utilities
│   └── vendor-test-patterns.yml       # Vendor-specific patterns
├── mock-inventories/
│   ├── all-platforms.yml              # Consolidated inventory
│   ├── single-platform.yml            # NX-OS focused
│   └── group_vars/
│       └── all.yml                    # Global variables (reduced)
├── test-vars.yml                      # Reference variables document
├── [test files]                       # All use centralized data
└── [other directories]
```

---

## Files to Update (18+ playbooks)

### Critical Gaps (8 files):
- [ ] conditional-logic-coverage.yml
- [ ] end-to-end-workflow.yml
- [ ] end-to-end-workflow-simple.yml
- [ ] error-path-coverage.yml
- [ ] error-path-coverage-simple.yml
- [ ] performance-under-load.yml
- [ ] performance-under-load-simple.yml
- [ ] security-boundary-testing.yml
- [ ] security-boundary-testing-simple.yml

### Unit Tests (6 files):
- [ ] variable-validation.yml
- [ ] error-handling.yml
- [ ] template-rendering.yml
- [ ] workflow-logic.yml (ALREADY UPDATED)
- [ ] mock-authentication-validation.yml
- [ ] test_error_scenario.yml

### Vendor Tests (4 files):
- [ ] cisco-nxos-tests.yml (ALREADY UPDATED)
- [ ] cisco-iosxe-tests.yml (ALREADY UPDATED)
- [ ] fortios-tests.yml (ALREADY UPDATED)
- [ ] opengear-tests.yml

### Integration Tests (4 files):
- [ ] check-mode-tests.yml
- [ ] multi-platform-integration-tests.yml
- [ ] multi-platform-concurrent-device-tests.yml
- [ ] secure-transfer-integration-tests.yml

### Error Scenarios (2 files):
- [ ] concurrent_upgrade_tests.yml
- [ ] device_error_tests.yml

### Validation Tests (4 files):
- [ ] comprehensive-validation-tests.yml
- [ ] network-validation-tests.yml
- [ ] rollback-state-validation-tests.yml
- [ ] state-consistency-validation-tests.yml

---

## Summary

**Objective**: Centralize all test data to eliminate duplication and improve maintainability

**Progress**:
- **Phase 1**: ✓ 100% - Device definitions centralized
- **Phase 2**: 0% - Inventory consolidation pending
- **Phase 3**: 0% - Test variables consolidation pending
- **Phase 4**: 30% - 8/20+ playbooks updated
- **Phase 5**: 0% - Mock device engine update pending
- **Phase 6**: 0% - Firmware directories decision pending

**Expected Outcome**:
- Eliminate 250+ lines of duplicate device/firmware data
- Reduce maintenance burden for test updates
- Single source of truth for all device definitions
- Improved test consistency and reliability

---

**Last Updated**: 2025-11-04
**Next Steps**: Complete Phase 2 (inventory consolidation) and Phase 4 (playbook refactoring)
