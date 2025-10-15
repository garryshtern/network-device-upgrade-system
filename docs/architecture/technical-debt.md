# Technical Debt

This document tracks known technical debt items for future refactoring.

## Space Management Role Duplication

**Status**: Documented
**Priority**: Low
**Effort**: High (3-5 days)
**Risk**: Medium

### Issue
The `space-management` role has 5 platform-specific assessment files with significant code duplication (~575 total lines, ~70% duplication):

- `nxos-assessment.yml` (110 lines)
- `ios-assessment.yml` (95 lines)
- `fortios-assessment.yml` (106 lines)
- `metamako_mos-assessment.yml` (101 lines)
- `opengear-assessment.yml` (163 lines)

### Current State
Each file contains:
1. Platform-specific data gathering (lines 1-32) - **UNIQUE**
2. Cleanup decision logic (lines 34-45) - **DUPLICATED**
3. Cleanup execution block (lines 46-110) - **DUPLICATED with platform variations**

### Why Not Refactored Yet
After thorough analysis (2025-10-10), full refactoring was deferred because:

1. **Ansible architectural constraints**: No dynamic module selection (can't use `{{ module_name }}` as action)
2. **Complexity vs. benefit trade-off**: Refactoring would require:
   - Complex variable-driven command execution
   - Multiple small include files per platform
   - Increased indirection making debugging harder
3. **Current design advantages**:
   - Self-contained, independently testable files
   - Explicit platform behavior
   - Safe - changes don't cross-contaminate
   - Easy onboarding for new team members

### Future Refactoring Approach
If this becomes a maintenance burden, consider:

1. **Custom Action Plugin**: Create `storage_assessment` action plugin that handles all platforms
2. **Ansible Collection**: Package as reusable collection with proper abstraction
3. **External Script**: Python script called via `ansible.builtin.script` for all logic

### Recent Fixes
- 2025-10-10: Added `| float` filter to all cleanup_needed comparisons to fix type mismatch errors

### Related Files
- `ansible-content/roles/space-management/tasks/*-assessment.yml`
- `ansible-content/roles/space-management/tasks/storage-assessment.yml` (orchestrator)

