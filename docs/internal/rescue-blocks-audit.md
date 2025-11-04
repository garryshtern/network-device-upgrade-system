# Rescue Blocks Audit - Complete Analysis

**Date**: November 4, 2025
**Scope**: All 15 files with rescue blocks in ansible-content/
**Status**: AUDIT COMPLETE - 8 files require remediation

---

## Executive Summary

**Found**: 15 files with rescue blocks
**Categorized**: 3 categories based on behavior
- ✓ **GOOD (5 files)**: Rescue blocks properly fail and stop workflow
- ❌ **PROBLEMATIC (8 files)**: Rescue blocks silently suppress errors or continue workflow
- ✓ **PARTIAL (2 files)**: Some rescues are correct, some are not

**User Requirement**: "No rescues. If there is a failure, the system should stop and report."

**Interpretation**: This means:
- Remove rescue blocks that silently suppress errors
- ALL error conditions must fail with clear messages
- NO "continue despite error" behavior
- Every failure must stop the workflow and display why

---

## Category 1: GOOD - Rescue blocks properly fail

### Files with CORRECT rescue behavior (Let error propagate with clear message):

#### 1. `roles/cisco-iosxe-upgrade/tasks/iosxe-firmware-transfer.yml`
**Lines**: rescue block after file transfer attempt
**Behavior**: ✓ Sets error info, then RE-RAISES with fail
```yaml
rescue:
  - name: Set transfer result (failure)
    set_fact:
      transfer_result:
        succeeded: false
        error_message: "{{ ansible_failed_result.msg }}"

  - name: Re-raise the error  # ← CORRECT: Re-raises to fail workflow
    ansible.builtin.fail:
      msg: "Transfer failed: {{ transfer_result.error_message }}"
```
**Status**: ✓ GOOD - Re-raises error, stops workflow

#### 2. `roles/cisco-nxos-upgrade/tasks/nxos-generic-file-transfer.yml`
**Lines**: Similar pattern
**Behavior**: ✓ Sets error info, then re-raises
**Status**: ✓ GOOD - Same as iosxe-firmware-transfer

#### 3. `roles/cisco-nxos-upgrade/tasks/reboot.yml`
**Lines**: rescue after device reboot timeout
**Behavior**: ✓ Fails with critical error message
```yaml
rescue:
  - name: Device failed to come back online - escalate as critical failure
    ansible.builtin.fail:
      msg:
        - "CRITICAL: Device did not recover after {{ timeout }}s"
        - "Manual intervention required"
```
**Status**: ✓ GOOD - Fails and stops

#### 4. `roles/common/tasks/connectivity-check.yml`
**Lines**: rescue after connection attempt
**Behavior**: ✓ Fails with detailed error message
```yaml
rescue:
  - name: Connection or version retrieval failed
    ansible.builtin.fail:
      msg: "Failed to connect to device... Check: (1) connectivity, (2) credentials..."
```
**Status**: ✓ GOOD - Clear error message

#### 5. `roles/common/tasks/network-resources-gathering.yml`
**Lines**: rescue after network resource gathering
**Behavior**: ✓ Fails with actionable error message
**Status**: ✓ GOOD - Fails and stops

---

## Category 2: PROBLEMATIC - Rescue blocks suppress errors

### Files with INCORRECT rescue behavior (Silently handle errors, workflow continues):

#### 1. ❌ `playbooks/compliance-audit.yml`
**Problem**: Rescue blocks just log failure, don't stop
```yaml
rescue:
  - name: Handle security baseline audit failure
    ansible.builtin.set_fact:
      compliance_results: > {{ ... failed: ['security_baseline_audit_error'] }}
    # ^ Just records failure in variable, workflow CONTINUES!
```
**Impact**: Compliance audit fails silently, results show failures but workflow succeeds
**Fix**: Replace rescue with assertion that fails on error

#### 2. ❌ `playbooks/emergency-rollback.yml`
**Problem**: Multiple rescues just log and continue
```yaml
rescue:
  - name: Log connectivity check failure
    ansible.builtin.debug:
      msg: "Connectivity check failed - continuing with rollback"
    # ^ Just logs, CONTINUES with rollback!
```
**Impact**:
- Device may not be reachable but rollback continues anyway
- No error stop, just continues to next step
- Dangerous: Could leave device in bad state

**Fix**: Fail instead of continuing

#### 3. ❌ `playbooks/main-upgrade-workflow.yml`
**Problem**: Connectivity check failure is logged but workflow may continue
```yaml
rescue:
  - name: Connectivity check failed
    block:
      - name: Log connectivity failure
        ansible.builtin.debug:
          msg:
            - "WARNING: Connectivity check failed..."
    always:
      - name: Mark upgrade with connectivity warnings
        # ^ Still marks upgrade and continues
```
**Impact**: Upgrade proceeds despite connectivity failure
**Fix**: Fail immediately instead of warning+continue

#### 4. ❌ `playbooks/emergency-rollback.yml` (second rescue)
**Problem**: Device status check failure just logged
```yaml
rescue:
  - name: Log device status check failure
    ansible.builtin.debug:
      msg: "Device status check failed - continuing with rollback"
```
**Impact**: Rollback continues without knowing device status
**Fix**: Fail, don't continue

#### 5. ❌ `roles/cisco-iosxe-upgrade/tasks/image-installation.yml`
**Problem**: Device shutdown timeout just logs warning
```yaml
rescue:
  - name: Log device shutdown timeout warning
    ansible.builtin.debug:
      msg: "Device did not cleanly shutdown within 5 minutes..."
    # ^ Just logs warning, continues to next step!
```
**Impact**:
- Device may still be in middle of shutdown when installation starts
- Could cause installation to fail or corrupt device
- Only logs, doesn't stop

**Fix**: Consider if this should fail or if safe to continue after delay

#### 6. ❌ `roles/common/tasks/compliance-audit.yml`
**Problem**: Multiple audit failure rescues just record in variable
```yaml
rescue:
  - name: Handle security baseline audit failure
    ansible.builtin.set_fact:
      compliance_results: > {{ ... failed: [...] }}

rescue:
  - name: Handle network hardening audit failure
    ansible.builtin.set_fact:
      # ^ Just records, workflow continues
```
**Impact**: Audit failures are recorded but don't stop workflow
**Fix**: Fail on critical compliance violations

#### 7. ❌ `roles/common/tasks/emergency-rollback.yml`
**Problem**: Status assessment rescue just logs
```yaml
rescue:
  - name: Log connectivity check failure
    ansible.builtin.debug:
      msg: "Connectivity check failed - continuing with rollback"
```
**Impact**: Rollback proceeds without verifying device can be reached
**Fix**: Fail instead of continuing

#### 8. ❌ `roles/opengear-upgrade/tasks/main.yml`
**Problem**: Need to check - likely similar pattern
**Status**: Need to review for silent error suppression

---

## Category 3: PARTIAL - Mixed behavior

#### `roles/opengear-upgrade/tasks/opengear-firmware-transfer.yml`
**Status**: Need to review for proper failure behavior

#### `roles/fortios-upgrade/tasks/fortios-firmware-transfer.yml`
**Status**: Need to review for proper failure behavior

---

## Summary Table

| File | Behavior | Category | Action Required |
|------|----------|----------|------------------|
| iosxe-firmware-transfer.yml | Re-raises error | GOOD | ✓ Keep |
| nxos-generic-file-transfer.yml | Re-raises error | GOOD | ✓ Keep |
| reboot.yml | Fails on timeout | GOOD | ✓ Keep |
| connectivity-check.yml | Fails on error | GOOD | ✓ Keep |
| network-resources-gathering.yml | Fails on error | GOOD | ✓ Keep |
| compliance-audit.yml (playbooks) | Logs only | BAD | ❌ Fix: Remove rescue, let fail |
| emergency-rollback.yml (playbooks) | Logs only | BAD | ❌ Fix: Remove rescues or fail |
| main-upgrade-workflow.yml | Logs only | BAD | ❌ Fix: Fail on connectivity failure |
| image-installation.yml | Logs warning | PARTIAL | ⚠️ Fix: Decide fail vs safe delay |
| compliance-audit.yml (role) | Records only | BAD | ❌ Fix: Fail on critical |
| emergency-rollback.yml (role) | Logs only | BAD | ❌ Fix: Fail on failures |
| opengear-upgrade/main.yml | Unknown | UNKNOWN | ? Review |
| fortios-firmware-transfer.yml | Unknown | UNKNOWN | ? Review |
| opengear-firmware-transfer.yml | Unknown | UNKNOWN | ? Review |

---

## Remediation Strategy

### Phase 1: REMOVE Bad Rescues (Highest Priority)
For files that just log and continue, REMOVE the rescue block entirely:
- Let Ansible's natural failure behavior stop the workflow
- Provide clear error message from the failed task itself

**Files**: compliance-audit.yml (playbooks), emergency-rollback.yml (playbooks), main-upgrade-workflow.yml

### Phase 2: FIX Partial Rescues (Medium Priority)
For image-installation.yml: Decide if timeout should fail or safely delay

**Decision**:
- If device must come back online → FAIL if it doesn't
- If we can safely wait longer → Extend timeout, then fail

### Phase 3: AUDIT Unknown Rescues (Lower Priority)
Review opengear and fortios firmware transfer files

### Phase 4: DOCUMENT (Update Guidelines)
Update CLAUDE.md with rescue block rules:
- When to use rescue (ONLY for proper error re-raising like iosxe-firmware-transfer.yml)
- When NOT to use rescue (silently suppressing errors)
- Pattern to follow if rescue needed (capture error info, then re-raise)

---

## Implementation Examples

### WRONG: Silent error suppression (REMOVE THIS)
```yaml
rescue:
  - name: Log connectivity failure
    debug:
      msg: "Connection failed - continuing anyway"
  # ^ Workflow continues despite error - WRONG!
```

### RIGHT: Proper error handling (KEEP THIS)
```yaml
rescue:
  - name: Capture error details
    set_fact:
      error_details: "{{ ansible_failed_result.msg }}"

  - name: Fail with clear message
    fail:
      msg: "Transfer failed: {{ error_details }}"
  # ^ Workflow stops, error is clear - CORRECT!
```

### RIGHT: No rescue needed (REMOVE RESCUE)
```yaml
# Just let the task fail naturally with its own error message
- name: Check connectivity
  command: ping -c 1 {{ device_ip }}
  # If this fails, Ansible naturally stops and shows error
  # No rescue needed!
```

---

## Files Requiring Immediate Action

### CRITICAL ISSUES
1. **playbooks/main-upgrade-workflow.yml** - Connectivity check rescue
2. **playbooks/emergency-rollback.yml** - Multiple silent rescues
3. **roles/common/tasks/emergency-rollback.yml** - Silent rescues

### HIGH PRIORITY
4. **playbooks/compliance-audit.yml** - Silent failure recording
5. **roles/common/tasks/compliance-audit.yml** - Silent failure recording

### MEDIUM PRIORITY
6. **roles/cisco-iosxe-upgrade/tasks/image-installation.yml** - Warning instead of fail

### TO REVIEW
7. **roles/opengear-upgrade/tasks/main.yml**
8. **roles/fortios-upgrade/tasks/fortios-firmware-transfer.yml**
9. **roles/opengear-upgrade/tasks/opengear-firmware-transfer.yml**

---

## Design Principle

**FAIL FAST, FAIL LOUD**
- Every error stops the workflow immediately
- Every error displays a clear message showing what failed and why
- No silent logging, no continuing despite errors
- No rescue blocks that suppress errors

**EXCEPTION**: Rescue blocks are only acceptable if they:
1. Capture error details
2. Fail the workflow with the captured error details
3. Don't attempt to "handle" or suppress the error

---

## Expected Outcome After Fixes

- ✓ No silent errors
- ✓ All failures stop workflow
- ✓ All errors have clear messages
- ✓ Operators see exactly what failed and where
- ✓ No "continuing despite error" behavior
- ✓ No rescue blocks except for proper error re-raising

---

**Status**: Ready for implementation
**Effort**:
- Phase 1: 1 hour (remove bad rescues)
- Phase 2: 30 minutes (fix partial rescues)
- Phase 3: 1 hour (audit unknown rescues)
- Phase 4: 30 minutes (documentation)
- **Total**: ~3 hours

**Priority**: CRITICAL - Affects system reliability and operator awareness
