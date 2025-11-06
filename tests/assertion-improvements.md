# Assertion Error Message Improvements

## Overview
Improve assertion error messages across all test files to include context, device information, and troubleshooting guidance.

## Current Problems
- Generic error messages like "Assertion failed"
- Missing device/scenario context
- No troubleshooting guidance
- Inconsistent format across files

## Standard Pattern

### BEFORE (Bad)
```yaml
- name: Verify upgrade completed
  ansible.builtin.assert:
    that:
      - upgrade_status == 'COMPLETE'
    fail_msg: "Upgrade verification failed"
```

### AFTER (Good)
```yaml
- name: Verify upgrade completed
  ansible.builtin.assert:
    that:
      - upgrade_status == 'COMPLETE'
    fail_msg:
      - "UPGRADE VERIFICATION FAILED"
      - "Device: {{ inventory_hostname }}"
      - "Expected Status: COMPLETE"
      - "Actual Status: {{ upgrade_status | default('UNDEFINED') }}"
      - "Scenario: {{ test_scenario | default('unknown') }}"
      - "Troubleshooting: Check device logs and network connectivity"
```

## Key Improvements

1. **Context Information**
   - Device name/hostname
   - Scenario being tested
   - Test phase
   - Expected vs actual values

2. **Troubleshooting Guidance**
   - What to check
   - Common causes
   - Recovery steps

3. **Consistent Format**
   - Line 1: Title (uppercase)
   - Line 2+: Context details
   - Final line: Troubleshooting steps

## Files to Update (Priority Order)

### CRITICAL (93 assertions across test files)
- integration-tests/*.yml (8 files)
- error-scenarios/*.yml (5 files)
- validation-tests/*.yml (2 files)
- unit-tests/*.yml (10 files)

### Process
For each file:
1. Search for `fail_msg: "` patterns
2. Convert simple strings to lists
3. Add context variables
4. Add troubleshooting guidance
5. Verify with `ansible-playbook --syntax-check`
6. Test with `./tests/run-all-tests.sh`

## Expected Benefits
- Faster debugging of test failures
- Better understanding of what failed and why
- Reduced time to fix broken tests
- Improved test maintainability
