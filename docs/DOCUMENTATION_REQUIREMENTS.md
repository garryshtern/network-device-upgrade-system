# Documentation Requirements and Updates Needed

## Overview

This document captures all documentation changes needed to ensure accuracy with the actual codebase implementation.

---

## Part 1: Step Descriptions and Implementation

### Actual Step Implementations (From Code)

These are the ACTUAL step descriptions found in `ansible-content/playbooks/steps/`:

| Step | Actual Description | File |
|------|-------------------|------|
| **Step 1** | Basic Connectivity Check | step-1-connectivity.yml |
| **Step 2** | Version Check and Image Verification | step-2-version-check.yml |
| **Step 3** | Storage Space Validation | step-3-space-check.yml |
| **Step 4** | Image Upload | step-4-image-upload.yml |
| **Step 5** | Config Backup and Pre-Upgrade Validation | step-5-pre-validation.yml |
| **Step 6** | Firmware Installation and Reboot | step-6-installation.yml |
| **Step 7** | Post-Upgrade Validation | step-7-post-validation.yml |
| **Step 8** | Emergency Rollback | step-8-emergency-rollback.yml |

### Documentation vs. Reality

#### ✅ CORRECT in workflow-steps-guide.md:
- Step 1 description
- Step 2 description
- Step 3 description
- Step 6 description
- Step 7 description
- Step 8 description

#### ❌ INCORRECT in workflow-steps-guide.md:

**Step 4 (WRONG)**:
```
### Step 4: Upload Image + Backup Config
**What it does:**
- Stages firmware image on device
- Backs up running configuration
```

**Should be**:
```
### Step 4: Image Upload
**What it does:**
- Uploads firmware image to devices
- Verifies SHA512 hash after upload (mandatory)
```

**Step 5 (WRONG PLACEMENT)**:
- Backup config is described in Step 4 section
- Pre-validation is described in Step 5 section
- But Step 5 actually does BOTH together

**Should be**:
```
### Step 5: Config Backup and Pre-Upgrade Validation
**What it does:**
- Backs up running configuration
- Captures pre-upgrade network state baseline
- Validates network is healthy before upgrade
```

---

## Part 2: Network Validation Task Reference

### Current Network Validation Tasks (From Recent Refactoring)

All network validation tasks follow the standardized multicast pattern:

| Task | Data Validated | Normalization | Format |
|------|----------------|----------------|--------|
| **network-resource-validation** | Entire network_resources tree (interfaces, L2/L3, VLANs, LAG, LACP, BFD config) | None (raw) | Comparison |
| **arp-validation** | ARP data + MAC data | ARP normalized, MAC raw | Comparison |
| **routing-validation** | RIB data + FIB data | Both normalized | Comparison |
| **bfd-validation** | BFD session data | Normalized | Comparison |
| **multicast-validation** | PIM interface, neighbor, RP + IGMP interface, groups + mroute | Normalized (as defined in defaults) | Comparison |

### Pattern Used

All validation tasks follow this structure:
1. Initialize comparison_status to "NOT_RUN"
2. Single main comparison block with when conditions
3. Data-type-specific nested blocks for each validation
4. Normalize (if needed) → Calculate deltas → Report (conditional)
5. Set status to PASS/FAIL only once at end

### Excluded Fields for Normalization

From `defaults/main.yml`, these fields are excluded when normalizing data:

- **arp_data**: time-stamp
- **mac_data**: age
- **rib_data**: uptime, time
- **fib_data**: uptime, time
- **bfd_data**: up_time, last_state_change, state_change_count, remote_disc, local_disc, holddown
- **pim_interface_data**: uptime, hello_interval_running, hello-sent, hello-rcvd
- **pim_neighbor_data**: uptime, expires
- **igmp_interface_data**: uptime, last_reporter, next-query, V2QueriesSent, V2ReportReceived, V2LeaveReceived
- **igmp_groups_data**: uptime, expires, last_reporter
- **mroute_data**: uptime, expires, packet_count, last_packet_received, uptime_detailed, oif-uptime, oif-uptime-detailed

---

## Part 3: Documentation Files That Need Updates

### HIGH PRIORITY - Accuracy Critical

#### File: `docs/workflow-steps-guide.md`

**Issues Found**:
1. Lines 46-53: Step 4 description wrong (consolidates upload + backup)
2. Lines 106-130: "Safe Full Upgrade" example has wrong step order (starts with step5)
3. Step 4 section doesn't match Step 5 description

**Required Changes**:
- [ ] Separate Step 4 and Step 5 descriptions
- [ ] Fix Step 4 to be "Image Upload" only
- [ ] Move config backup to Step 5 description
- [ ] Fix example workflow to start with step1, then step2, step3, step4, step5, step6, step7
- [ ] Update all references to consolidation of image+backup to show them as separate steps

---

#### File: `docs/user-guides/upgrade-workflow-guide.md`

**Status**: NEEDS VERIFICATION

**Actions**:
- [ ] Compare each step description with actual implementation
- [ ] Verify no consolidation of steps mentioned
- [ ] Check example workflows for correct order
- [ ] Verify all tags used (step1, step2... step8)
- [ ] Ensure prerequisites are correctly listed

---

### MEDIUM PRIORITY - Content Verification

#### File: `docs/baseline-comparison-all-datatypes.md`

**Status**: NEEDS VERIFICATION

**Actions**:
- [ ] Search for any references to BGP validation
- [ ] Verify all data types mentioned still exist in code
- [ ] Check if it references old validation patterns (before multicast refactor)
- [ ] Update if it describes old normalization patterns

---

#### File: `docs/README.md`

**Issues Found**:
- Dead links to 3 non-existent files

**Required Changes**:
- [ ] Remove links to missing files:
  - `user-guides/installation-guide.md`
  - `user-guides/inventory-parameters.md`
  - `user-guides/troubleshooting.md`

OR

- [ ] Create the missing documentation files

**Recommendation**: Remove links since these don't exist and full documentation exists in CLAUDE.md

---

### LOW PRIORITY - Reference Verification

#### File: `docs/architecture/main-upgrade-workflow.md`

**Status**: NEEDS VERIFICATION

**Actions**:
- [ ] Verify step descriptions match actual implementation
- [ ] Check workflow diagram if exists
- [ ] Verify dependency descriptions

---

#### File: `docs/platform-guides/platform-implementation-status.md`

**Status**: NEEDS VERIFICATION

**Actions**:
- [ ] Check if it references deprecated steps
- [ ] Verify platform coverage matches implementation

---

## Part 4: Documentation That IS Correct

### ✅ Files with Good Content (No Changes Needed)

- ✅ **CLAUDE.md** - Step descriptions are 100% correct and match implementation
- ✅ **docs/user-guides/ansible-module-usage-guide.md** - Correctly marks deprecated playbooks with guidance to use main-upgrade-workflow.yml
- ✅ **docs/user-guides/container-deployment.md** - Valid and current
- ✅ **docs/deployment/** - All deployment guides are current
- ✅ **docs/platform-guides/** - Platform-specific guides are consistent

---

## Part 5: Recent Changes That Affected Documentation

### Network Validation Refactoring (November 2025)

**Commit**: `fe41578` - "refactor: standardize all network validation tasks to multicast pattern"

**Changes**:
- All 5 validation tasks (network-resource, arp, routing, bfd, multicast) now follow consistent pattern
- Status variables properly initialized and aggregated
- Internal conditions handled correctly in each task file

**Documentation Impact**:
- ✅ CLAUDE.md already documents this correctly
- ✅ No user-facing documentation changes needed (implementation detail)
- ⚠️ May need to update baseline-comparison-all-datatypes.md if it describes old patterns

### No Other Recent Changes That Require Documentation Updates

---

## Part 6: Action Plan Summary

### Tasks in Priority Order

#### CRITICAL (Do First):
1. **workflow-steps-guide.md - Step 4/5 Fix**
   - Separate Step 4 (Image Upload) from Step 5 (Config Backup + Pre-Validation)
   - Fix "Safe Full Upgrade" example to start with step1
   - Estimated effort: 30 minutes

2. **workflow-steps-guide.md - Example Workflows**
   - Fix all example commands to use correct step order
   - Verify all tags match actual playbook tags
   - Estimated effort: 30 minutes

#### HIGH (Do Soon):
3. **Verify upgrade-workflow-guide.md**
   - Compare with actual step implementation
   - Fix any step descriptions that don't match
   - Estimated effort: 45 minutes

4. **Remove/Create Missing Docs**
   - Either create installation-guide.md, inventory-parameters.md, troubleshooting.md
   - Or remove references from README.md
   - Estimated effort: 1-2 hours depending on choice

#### MEDIUM (Do Before Release):
5. **Verify baseline-comparison-all-datatypes.md**
   - Check for stale BGP validation references
   - Update if describes old patterns
   - Estimated effort: 30 minutes

6. **Verify architecture documentation**
   - Check main-upgrade-workflow.md if exists
   - Check platform-implementation-status.md
   - Estimated effort: 45 minutes

---

## Part 7: Verification Checklist

Before marking documentation as "current and correct":

- [ ] All step descriptions match actual step implementations
- [ ] All step tags (step1, step2... step8) are used correctly
- [ ] No references to non-existent steps or tags
- [ ] No consolidation of separate steps mentioned
- [ ] Example workflows show steps in correct order
- [ ] All required variables listed for each step
- [ ] Dependencies accurately described
- [ ] Deprecated playbooks marked as such with migration path
- [ ] No dead links in README
- [ ] CLAUDE.md stays as source of truth for workflows
- [ ] Internal implementation details don't leak into user docs

---

## Part 8: Success Criteria

Documentation is "current and correct" when:

1. ✅ All step descriptions in workflow-steps-guide.md match actual implementation
2. ✅ All examples use correct step order and tags
3. ✅ No broken links in README or other docs
4. ✅ upgrade-workflow-guide.md verified against actual implementation
5. ✅ baseline-comparison-all-datatypes.md has no stale references
6. ✅ No user confusion between consolidated vs. separate steps
7. ✅ Architecture documentation consistent with implementation
8. ✅ Recent refactoring (network-validation) doesn't create stale docs

---

**Analysis Date**: November 2, 2025
**Status**: Ready for implementation
**Estimated Total Time**: 3-4 hours to complete all updates
