# Main Upgrade Workflow Architecture

## Overview

The `main-upgrade-workflow.yml` implements a comprehensive 7-step upgrade process designed for fail-fast validation and operational safety. Each step must pass before proceeding to the next, with the exception of STEP 7 which can trigger optional rollback.

**Key Feature**: The workflow implements **automatic dependency resolution** through tag inheritance. When you run any step, all prerequisite steps execute automatically. This ensures safety (prerequisites cannot be skipped) while providing flexibility (run any step independently).

## Table of Contents

- [Automatic Dependency Resolution](#automatic-dependency-resolution)
  - [Tag Inheritance Mechanism](#tag-inheritance-mechanism)
  - [Dependency Chain](#dependency-chain)
  - [Valid Execution Patterns](#valid-execution-patterns)
  - [Network Baseline Persistence](#network-baseline-persistence)
  - [Benefits](#benefits-of-automatic-dependency-resolution)
- [Workflow Steps](#workflow-steps)
  - [STEP 1: Connectivity Check](#step-1-connectivity-check)
  - [STEP 2: Version Check and Image Verification](#step-2-version-check-and-image-verification)
  - [STEP 3: Storage Space Validation](#step-3-storage-space-validation)
  - [STEP 4: Image Upload and Config Backup](#step-4-image-upload-and-config-backup)
  - [STEP 5: Network Resources Gathering and Pre-Upgrade Validation](#step-5-network-resources-gathering-and-pre-upgrade-validation)
  - [STEP 6: Firmware Installation](#step-6-firmware-installation)
  - [STEP 7: Post-Upgrade Validation](#step-7-post-upgrade-validation)
- [Workflow Characteristics](#workflow-characteristics)
- [Testing and Validation](#testing-and-validation)
- [References](#references)

## Automatic Dependency Resolution

### Tag Inheritance Mechanism

The workflow implements **automatic dependency resolution** through tag inheritance. Each step includes tags for all its prerequisites, ensuring dependencies are automatically satisfied when you run any step.

#### How It Works

When you specify a step to run (e.g., `--tags step5`), Ansible executes **all tasks** that match that tag. Since each step includes tags for its prerequisites, those prerequisites run automatically.

**Example**: Running `--tags step5` executes tasks tagged with:
- `step1` (basic connectivity)
- `step2` (version check)
- `step3` (space check)
- `step4` (image upload)
- `step5` (pre-validation)

This ensures STEP 5 cannot run without its dependencies being satisfied first.

### Dependency Chain

```
STEP 1: Basic Connectivity Check
└─ No prerequisites (can run standalone)

STEP 2: Version Check
├─ Requires: STEP 1
└─ Tags: [step1, step2, version_check]

STEP 3: Storage Space Validation
├─ Requires: STEP 1, STEP 2
└─ Tags: [step1, step2, step3, space_check]

STEP 4: Image Upload and Config Backup
├─ Requires: STEP 1, STEP 2, STEP 3
└─ Tags: [step1, step2, step3, step4, image_upload, config_backup]

STEP 5: Pre-Upgrade Validation
├─ Requires: STEP 1, STEP 2, STEP 3, STEP 4
└─ Tags: [step1, step2, step3, step4, step5, pre_validation, network_validation]

STEP 6: Firmware Installation
├─ Requires: STEP 1, STEP 2, STEP 3, STEP 4, STEP 5
└─ Tags: [step1, step2, step3, step4, step5, step6, install, reboot]

STEP 7: Post-Upgrade Validation
├─ Requires: STEP 1 (assumes STEP 5/6 completed previously)
└─ Tags: [step1, step7, post_validation, network_validation]
```

### Visual Dependency Flow

```
┌──────────────────────────────────────────────────────────────────────────┐
│                           DEPENDENCY FLOW                                │
│          (Arrows show what each step automatically includes)             │
└──────────────────────────────────────────────────────────────────────────┘

  ┌─────────────────┐
  │    STEP 1       │  ← Can run standalone
  │  Connectivity   │  ← No prerequisites
  │    Check        │  ← Tags: [step1, connectivity]
  └────────┬────────┘
           │
           │ Required by all other steps
           │
           ├──────────────────────────────────────────────────────┐
           │                                                      │
           ▼                                                      │
  ┌─────────────────┐                                            │
  │    STEP 2       │  ← Auto-includes: STEP 1                   │
  │ Version Check & │  ← Tags: [step1, step2, version_check]     │
  │ Image Verify    │                                            │
  └────────┬────────┘                                            │
           │                                                      │
           │ Required by: STEP 3, 4, 5, 6                        │
           │                                                      │
           ▼                                                      │
  ┌─────────────────┐                                            │
  │    STEP 3       │  ← Auto-includes: STEP 1, 2                │
  │ Storage Space   │  ← Tags: [step1, step2, step3,             │
  │   Validation    │     space_check]                           │
  └────────┬────────┘                                            │
           │                                                      │
           │ Required by: STEP 4, 5, 6                           │
           │                                                      │
           ▼                                                      │
  ┌─────────────────┐                                            │
  │    STEP 4       │  ← Auto-includes: STEP 1, 2, 3             │
  │  Image Upload & │  ← Tags: [step1, step2, step3, step4,      │
  │  Config Backup  │     image_upload, config_backup]           │
  └────────┬────────┘                                            │
           │                                                      │
           │ Required by: STEP 5, 6                              │
           │                                                      │
           ▼                                                      │
  ┌─────────────────┐                                            │
  │    STEP 5       │  ← Auto-includes: STEP 1, 2, 3, 4          │
  │  Pre-Upgrade    │  ← Tags: [step1, step2, step3, step4,      │
  │   Validation    │     step5, pre_validation,                 │
  └────────┬────────┘     network_validation]                    │
           │              SAVES BASELINE TO FILESYSTEM           │
           │              (/tmp/network_baseline_*.json)         │
           │                                                      │
           │ Required by: STEP 6                                 │
           │                                                      │
           ▼                                                      │
  ┌─────────────────┐                                            │
  │    STEP 6       │  ← Auto-includes: STEP 1, 2, 3, 4, 5       │
  │    Firmware     │  ← Tags: [step1, step2, step3, step4,      │
  │  Installation   │     step5, step6, install, reboot]         │
  └─────────────────┘                                            │
                                                                 │
                                                                 │
  ┌─────────────────┐                                            │
  │    STEP 7       │  ← Auto-includes: STEP 1 only ─────────────┘
  │  Post-Upgrade   │  ← LOADS BASELINE FROM FILESYSTEM
  │   Validation    │  ← (from previous STEP 5 run)
  └─────────────────┘  ← Tags: [step1, step7, post_validation,
                          network_validation]

┌──────────────────────────────────────────────────────────────────────────┐
│                      EXECUTION EXAMPLES                                  │
└──────────────────────────────────────────────────────────────────────────┘

Run: --tags step1        Executes: [STEP 1]
Run: --tags step2        Executes: [STEP 1 → STEP 2]
Run: --tags step3        Executes: [STEP 1 → STEP 2 → STEP 3]
Run: --tags step4        Executes: [STEP 1 → STEP 2 → STEP 3 → STEP 4]
Run: --tags step5        Executes: [STEP 1 → STEP 2 → STEP 3 → STEP 4 → STEP 5]
Run: --tags step6        Executes: [STEP 1 → STEP 2 → STEP 3 → STEP 4 → STEP 5 → STEP 6]
Run: --tags step7        Executes: [STEP 1 → STEP 7]  (requires prior STEP 5)
Run: (no tags)           Executes: [STEP 1 → ... → STEP 7]  (full workflow)

┌──────────────────────────────────────────────────────────────────────────┐
│                      BASELINE PERSISTENCE                                │
└──────────────────────────────────────────────────────────────────────────┘

  DAY 1: Full Upgrade                    DAY 2: Post-Validation
  ───────────────────                    ──────────────────────

  --tags step6                           --tags step7
       │                                      │
       ├─ STEP 1-4 execute                   ├─ STEP 1 executes
       │                                      │
       ├─ STEP 5 executes                    ├─ STEP 7 executes
       │  └─ Saves baseline ─────────────────┼─ Loads baseline
       │     to filesystem                    │  from filesystem
       │                                      │
       └─ STEP 6 executes                    └─ Compares current
          (installs firmware)                    state to baseline

  Result: Device upgraded                Result: Network validated
          Baseline saved                        against Day 1 baseline
```

### Valid Execution Patterns

#### Full Upgrade Workflow
```bash
# Run all steps (default - no tags needed)
ansible-playbook main-upgrade-workflow.yml \
  --extra-vars="target_hosts=mydevice target_firmware=nxos.10.2.3.bin maintenance_window=true max_concurrent=1"

# Equivalent: explicitly specify step6 (all prerequisites run automatically)
--tags step6
# Executes: step1 → step2 → step3 → step4 → step5 → step6
```

#### Pre-Validation Only
```bash
# Prepare for upgrade without installing
--tags step5
# Executes: step1 → step2 → step3 → step4 → step5
# Result: Image staged, baseline saved, ready for installation
```

#### Post-Validation Only
```bash
# Validate after upgrade (assumes step5 baseline exists from previous run)
--tags step7
# Executes: step1 → step7
# Requires: STEP 5 baseline file from previous run
```

#### Image Upload Only
```bash
# Upload firmware without validation or installation
--tags step4
# Executes: step1 → step2 → step3 → step4
# Result: Image on device, config backed up
```

#### Version Check Only
```bash
# Check if upgrade needed
--tags step2
# Executes: step1 → step2
# Result: Determines if device needs upgrade
```

#### Connectivity Check Only
```bash
# Test basic connectivity
--tags step1
# Executes: step1 only
# Result: Verify device reachable, gather basic facts
```

### Function-Specific Tags

Additional tags allow running specific functions (still include dependencies):

```bash
--tags connectivity       # step1 only
--tags version_check      # step1 + step2
--tags space_check        # step1 + step2 + step3
--tags image_upload       # step1 + step2 + step3 + step4
--tags config_backup      # step1 + step2 + step3 + step4
--tags pre_validation     # step1 + step2 + step3 + step4 + step5
--tags install            # step1 + step2 + step3 + step4 + step5 + step6
--tags reboot             # step1 + step2 + step3 + step4 + step5 + step6
--tags post_validation    # step1 + step7
--tags network_validation # step1 + step2 + step3 + step4 + step5 + step7
```

### Special Case: STEP 7 Independence

STEP 7 (Post-Upgrade Validation) can run independently **IF** the STEP 5 baseline file exists from a previous run:

```bash
# Day 1: Run pre-validation and installation
--tags step6  # Saves baseline in STEP 5, installs in STEP 6

# Day 2: Run post-validation separately
--tags step7  # Loads baseline from STEP 5 run, compares to current state
```

**Why this works**:
- STEP 5 saves `network_baseline` to filesystem (persistent across runs)
- STEP 7 loads `network_baseline_pre` from filesystem (not from memory)
- STEP 7 only requires connectivity (STEP 1) to gather current state
- Comparison logic works with saved baseline from any previous STEP 5 run

**Use case**:
- Run upgrade during maintenance window (STEP 6)
- Validate network health hours/days later (STEP 7)
- Allows time for network to stabilize before validation

### Network Baseline Persistence

```yaml
# STEP 5: Pre-Upgrade Validation
- name: Capture pre-upgrade network state
  ansible.builtin.include_role:
    name: network-validation
  vars:
    validation_phase: "pre_upgrade"
    save_baseline: true  # Saves to filesystem

# STEP 7: Post-Upgrade Validation
- name: Capture post-upgrade network state
  ansible.builtin.include_role:
    name: network-validation
  vars:
    validation_phase: "post_upgrade"
    compare_to_baseline: true  # Loads from filesystem
```

**Baseline storage location**:
- `/tmp/network_baseline_{{ inventory_hostname }}.json`
- Persists across playbook runs
- Removed on successful validation or manual cleanup

### Benefits of Automatic Dependency Resolution

1. **Safety**: Impossible to skip required prerequisites by accident
2. **Simplicity**: Just specify what you want, dependencies run automatically
3. **Clarity**: No need to remember prerequisite chains
4. **Flexibility**: Run any step independently or in combination
5. **Consistency**: Dependencies always resolved the same way
6. **Maintainability**: Add new dependencies by updating tags

### Common Use Cases

| Scenario | Command | Steps Executed | Result |
|----------|---------|----------------|--------|
| Full upgrade | `--tags step6` | 1→2→3→4→5→6 | Device upgraded |
| Prepare only | `--tags step5` | 1→2→3→4→5 | Ready to install |
| Upload only | `--tags step4` | 1→2→3→4 | Image on device |
| Check version | `--tags step2` | 1→2 | Know if upgrade needed |
| Post-validation | `--tags step7` | 1→7 | Validate after upgrade |
| Full workflow | (no tags) | 1→2→3→4→5→6→7 | Complete upgrade |

### Invalid Execution Patterns

These patterns **will NOT work** as expected:

```bash
# WRONG: Cannot skip dependencies with --skip-tags
--tags step6 --skip-tags step5
# Problem: Breaks dependency chain, STEP 6 requires STEP 5 baseline

# WRONG: Cannot run STEP 7 without prior STEP 5
--tags step7  # (if no baseline file exists)
# Problem: No baseline to compare against

# WRONG: Cannot run STEP 6 without STEP 4
# (Not possible with tag inheritance - step6 includes step4 tag)
```

## Workflow Steps

### STEP 1: Connectivity Check

**Purpose**: Verify basic device connectivity and gather minimal device facts

**Tasks**:
- Gather basic device facts (hardware, min subset)
- NX-OS: `cisco.nxos.nxos_facts` (gather_subset: hardware, min)
- IOS-XE: `cisco.ios.ios_facts` (gather_subset: hardware, min)
- Other platforms: `wait_for_connection` with timeout
- Extract current firmware version and image filename
- Verify ansible_net_version, ansible_net_hostname, ansible_net_model, ansible_net_image

**Exit Condition**: FAIL → Workflow STOPS
**Rationale**: No point proceeding if device is unreachable

**Facts Gathered**:
- `current_firmware_version`: Device's current OS version
- `current_firmware_image`: Full path to current image (e.g., "bootflash://nxos.10.3.1.bin")
- `current_firmware_image_filename`: Just the filename (e.g., "nxos.10.3.1.bin")

---

### STEP 2: Version Check and Image Verification

**Purpose**: Determine if upgrade is needed and verify local image file exists

**Tasks**:
- Check if device is already running target firmware
- Compare current_firmware_image_filename == target_firmware (Cisco platforms)
- Compare current_firmware_version == target_firmware (non-Cisco platforms)
- If already running target firmware: Display message and `meta: end_host` (skip this device)
- If upgrade needed: Proceed with local image file verification
- Call `image-validation/integrity-audit` to verify local firmware file exists and passes hash check

**Exit Condition**: FAIL → Workflow STOPS
**Rationale**: Must verify image availability before checking space or uploading

**Why Before Space Check**:
- Need to know image size before determining required space
- Fail fast if image file doesn't exist or is corrupt
- Prevents wasted time on space management if image unavailable

---

### STEP 3: Storage Space Validation

**Purpose**: Ensure sufficient device storage space, cleanup if needed

**Tasks**:
- Call `space-management/storage-assessment` with minimum_free_space_gb
- Automatically triggers cleanup if insufficient space
- Verify storage_info.free_space_gb >= required_space_gb
- Cleanup process removes old firmware images and temporary files

**Exit Condition**: FAIL → Workflow STOPS
**Rationale**: Cannot upload image without sufficient space

**Why After Image Verification**:
- Now know exact image size from STEP 2
- Can accurately calculate required_space_gb
- Prevents unnecessary cleanup if image doesn't exist

---

### STEP 4: Image Upload and Config Backup

**Purpose**: Transfer firmware image to device and backup current configuration

**Tasks**:
- Call `common/image-loading` to upload image to device
  - Checks if image already exists on bootflash
  - Uses SCP (server-initiated PUSH) if upload needed
  - NX-OS: Enables SCP server, pushes via nxos_file_copy
- Call `image-validation/hash-verification` to verify uploaded image integrity
- Call `common/config-backup` to save current device configuration

**Exit Condition**: FAIL → Workflow STOPS
**Rationale**: Must have valid image on device and config backup before proceeding

**Why Separate from STEP 3**:
- Space check is validation, upload is operation
- Clear separation of concerns
- Allows recovery if upload fails partway

---

### STEP 5: Network Resources Gathering and Pre-Upgrade Validation

**Purpose**: Capture comprehensive network state baseline and validate health

**Tasks**:
- Call `common/network-resources-gathering`:
  - NX-OS: Gathers all network resources (BGP, interfaces, VLANs, routing, etc.)
  - Uses `cisco.nxos.nxos_facts` with comprehensive gather_network_resources list
  - Uses `cisco.nxos.nxos_command` for operational state (ARP, routes, BFD, multicast)
- Call `network-validation` role with validation_phase: "pre_upgrade"
  - Validates BGP neighbors, interface states, routing tables
  - Saves baseline data for post-upgrade comparison
  - Runs interface-validation, routing-validation, ARP-validation, etc.
- Verify network_validation_results.overall_status == "healthy"

**Exit Condition**: FAIL → Workflow STOPS
**Rationale**: Do not proceed with unhealthy network

**Why After Image Staging**:
- Image is confirmed safe and available
- Comprehensive gathering is expensive (time/resources)
- Only gather facts once we know upgrade will proceed

**Network Resources Gathered** (NX-OS):
- Configuration resources: interfaces, l2_interfaces, l3_interfaces, vlans, lag_interfaces, lacp_interfaces, bfd_interfaces, bgp_global, bgp_address_family, bgp_neighbor_address_family, route_maps, prefix_lists, static_routes, lldp_global, lldp_interfaces, ntp_global, snmp_server, logging_global, hostname
- Operational state: ARP tables, MAC tables, routing tables, forwarding tables, BFD neighbors, PIM interfaces/neighbors/RP, IGMP interfaces/groups

---

### STEP 6: Firmware Installation

**Purpose**: Install firmware and reboot device

**Tasks**:
- Call platform-specific role (e.g., `cisco-nxos-upgrade/image-installation`)
- Platform determines installation method:
  - NX-OS: ISSU (non-disruptive) or disruptive upgrade based on platform capabilities
  - IOS-XE: Install mode or bundle mode based on platform support
- Reboot device and wait for connectivity
- Use `wait_for_connection` with timeout and delay

**Exit Condition**: FAIL → Workflow STOPS
**Rationale**: Critical step - installation or connectivity failure requires investigation

**Platform-Specific Behavior**:
- NX-OS: Checks ISSU capability, may include EPLD upgrade
- IOS-XE: Auto-detects install vs bundle mode
- FortiOS: Multi-step upgrade if version gap too large
- Opengear: Web UI automation for older firmware
- Metamako: Direct image loading to device

---

### STEP 7: Post-Upgrade Validation

**Purpose**: Verify upgrade success and network health, optionally rollback on failure

**Tasks**:
- Call `common/network-resources-gathering` again (post-upgrade state)
- Call `network-validation` role with validation_phase: "post_upgrade", compare_to_baseline: true
  - Compares BGP neighbor counts, interface states, routing tables
  - Detects new down neighbors, missing routes, degraded services
- Verify network_validation_results.comparison_status == "passed"
- On failure: Optionally execute `common/emergency-rollback` if rollback_on_failure is true
- Mark upgrade_completed_with_warnings if validation fails

**Exit Condition**: FAIL → Optional rollback, workflow CONTINUES
**Rationale**: Post-validation failure doesn't stop workflow, allows observation and manual decision

**Validation Checks**:
- BGP: Neighbor count match, established sessions match, prefix variance < 10%
- Interfaces: No new down interfaces, up interface count match
- Routing: Route count stable, no major variance
- ARP: Entry count stable
- BFD: All sessions up

---

## Workflow Characteristics

### Fail-Fast Design

- **Steps 1-6**: MUST PASS or workflow STOPS
- **Step 7**: Failure triggers optional rollback but doesn't stop workflow
- Each step has clear success criteria and exit conditions
- No proceeding to next step until current step validates

### Role Dependency Management

- **NO role dependencies** in meta/main.yml
- All role calls are explicit via `include_role`
- Workflow orchestration controls execution order
- Prevents duplicate execution and unexpected auto-loading

### Fact Gathering Strategy

- **Basic facts** in STEP 1: Minimal overhead, connectivity verification
- **Comprehensive resources** in STEP 5: After confirming upgrade will proceed
- **Post-upgrade resources** in STEP 7: Compare against baseline
- Each fact gathered exactly ONCE per phase
- No duplicate gathering across roles

### Platform Support

- **Cisco NX-OS**: Full support with ISSU detection
- **Cisco IOS-XE**: Install mode vs bundle mode auto-detection
- **FortiOS**: Multi-step upgrade support
- **Opengear**: Legacy web UI automation
- **Metamako MOS**: Direct image loading

### Variables and Configuration

- All operational variables in `group_vars/all.yml`
- Platform-specific firmware in `group_vars/<platform>.yml`
- No local variable overrides in playbook
- SSH authentication from group_vars based on platform

## Error Handling

### Block/Rescue Pattern

Each major step uses:
```yaml
block:
  - name: Primary tasks
rescue:
  - name: Failure handler
    ansible.builtin.fail:
      msg: "STEP X FAILED: Reason. Workflow stopped."
```

### Conditional Execution

- Most steps include `when: not ansible_check_mode or inventory_hostname != 'localhost'`
- Allows check mode testing on localhost
- Real execution requires actual devices

### Rollback Trigger

STEP 7 rescue block:
```yaml
rescue:
  - name: Execute rollback procedure
    ansible.builtin.include_role:
      name: common
      tasks_from: emergency-rollback
    when: rollback_on_failure | bool
```

## Execution Flow Diagram

```
┌─────────────────────────────────────────────────────────┐
│ STEP 1: Connectivity Check                              │
│ - Gather basic facts (version, hostname, model, image)  │
│ - FAIL → STOP                                           │
└──────────────────┬──────────────────────────────────────┘
                   │ PASS
                   ▼
┌─────────────────────────────────────────────────────────┐
│ STEP 2: Version Check & Image Verification              │
│ - Already running target? → end_host                    │
│ - Verify local image file exists                        │
│ - FAIL → STOP                                           │
└──────────────────┬──────────────────────────────────────┘
                   │ PASS
                   ▼
┌─────────────────────────────────────────────────────────┐
│ STEP 3: Storage Space Validation                        │
│ - Check available space (cleanup if needed)             │
│ - FAIL → STOP                                           │
└──────────────────┬──────────────────────────────────────┘
                   │ PASS
                   ▼
┌─────────────────────────────────────────────────────────┐
│ STEP 4: Image Upload & Config Backup                    │
│ - Upload image to device (if not already there)         │
│ - Verify uploaded image hash                            │
│ - Backup current configuration                          │
│ - FAIL → STOP                                           │
└──────────────────┬──────────────────────────────────────┘
                   │ PASS
                   ▼
┌─────────────────────────────────────────────────────────┐
│ STEP 5: Network Resources Gathering & Pre-Validation    │
│ - Gather comprehensive network resources                │
│ - Validate network health (BGP, interfaces, routing)    │
│ - Save baseline for comparison                          │
│ - FAIL → STOP                                           │
└──────────────────┬──────────────────────────────────────┘
                   │ PASS
                   ▼
┌─────────────────────────────────────────────────────────┐
│ STEP 6: Firmware Installation                           │
│ - Install firmware (platform-specific method)           │
│ - Reboot device                                         │
│ - Wait for connectivity                                 │
│ - FAIL → STOP                                           │
└──────────────────┬──────────────────────────────────────┘
                   │ PASS
                   ▼
┌─────────────────────────────────────────────────────────┐
│ STEP 7: Post-Upgrade Validation                         │
│ - Gather network resources again                        │
│ - Compare to baseline                                   │
│ - FAIL → Optional rollback, workflow CONTINUES          │
└──────────────────┬──────────────────────────────────────┘
                   │ PASS
                   ▼
              ┌─────────┐
              │ SUCCESS │
              └─────────┘
```

## Key Differences from Old Design

### Previous Issues

1. **Role dependencies auto-executed**: network-validation ran automatically as dependency
2. **Duplicate fact gathering**: space-management ran twice (STEP 2 + dependency)
3. **Wrong order**: Space check before image verification
4. **Scattered validation**: No clear pre/post validation separation

### Current Design

1. **Explicit orchestration**: All role calls explicit in workflow
2. **Single execution**: Each role called exactly when needed
3. **Correct order**: Image verification → space check → upload
4. **Clear phases**: Pre-validation (STEP 5), Post-validation (STEP 7)

## Testing and Validation

### Syntax Validation

```bash
# Full workflow syntax check
ansible-playbook --syntax-check ansible-content/playbooks/main-upgrade-workflow.yml \
  --extra-vars="target_hosts=localhost target_firmware=test.bin maintenance_window=true max_concurrent=1"

# Specific step syntax check (e.g., pre-validation only)
ansible-playbook --syntax-check ansible-content/playbooks/main-upgrade-workflow.yml \
  --extra-vars="target_hosts=localhost target_firmware=test.bin maintenance_window=true max_concurrent=1" \
  --tags step5
```

### Check Mode Testing

```bash
# Full workflow check mode
ansible-playbook --check --diff ansible-content/playbooks/main-upgrade-workflow.yml \
  --extra-vars="target_hosts=localhost target_firmware=test.bin maintenance_window=true max_concurrent=1"

# Test specific steps with tag inheritance
ansible-playbook --check --diff ansible-content/playbooks/main-upgrade-workflow.yml \
  --extra-vars="target_hosts=localhost target_firmware=test.bin maintenance_window=true max_concurrent=1" \
  --tags step4  # Tests: step1 → step2 → step3 → step4
```

### Mock Inventory Testing

All 23 test suites in `tests/` validate workflow behavior with mock inventories.

### Tag-Based Testing Examples

```bash
# Test connectivity only
ansible-playbook main-upgrade-workflow.yml \
  --extra-vars="target_hosts=test-device target_firmware=test.bin maintenance_window=true max_concurrent=1" \
  --tags step1 --check

# Test image upload workflow (no installation)
ansible-playbook main-upgrade-workflow.yml \
  --extra-vars="target_hosts=test-device target_firmware=test.bin maintenance_window=true max_concurrent=1" \
  --tags step4 --check

# Test pre-validation workflow
ansible-playbook main-upgrade-workflow.yml \
  --extra-vars="target_hosts=test-device target_firmware=test.bin maintenance_window=true max_concurrent=1" \
  --tags step5 --check

# Test post-validation independently (requires prior step5 run)
ansible-playbook main-upgrade-workflow.yml \
  --extra-vars="target_hosts=test-device target_firmware=test.bin maintenance_window=true max_concurrent=1" \
  --tags step7 --check
```

## References

- Workflow file: `ansible-content/playbooks/main-upgrade-workflow.yml`
- Network resources gathering: `ansible-content/roles/common/tasks/network-resources-gathering.yml`
- Network validation: `ansible-content/roles/network-validation/tasks/main.yml`
- Platform roles: `ansible-content/roles/{cisco-nxos-upgrade,cisco-iosxe-upgrade,fortios-upgrade,opengear-upgrade,metamako-mos-upgrade}/`
