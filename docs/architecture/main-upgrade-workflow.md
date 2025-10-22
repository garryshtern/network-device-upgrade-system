# Main Upgrade Workflow Architecture

## Overview

The `main-upgrade-workflow.yml` implements a comprehensive 7-step upgrade process designed for fail-fast validation and operational safety. Each step must pass before proceeding to the next, with the exception of STEP 7 which can trigger optional rollback.

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
ansible-playbook --syntax-check ansible-content/playbooks/main-upgrade-workflow.yml \
  --extra-vars="target_hosts=localhost target_firmware=test.bin maintenance_window=true max_concurrent=1"
```

### Check Mode Testing

```bash
ansible-playbook --check --diff ansible-content/playbooks/main-upgrade-workflow.yml \
  --extra-vars="target_hosts=localhost target_firmware=test.bin maintenance_window=true max_concurrent=1"
```

### Mock Inventory Testing

All 23 test suites in `tests/` validate workflow behavior with mock inventories.

## References

- Workflow file: `ansible-content/playbooks/main-upgrade-workflow.yml`
- Network resources gathering: `ansible-content/roles/common/tasks/network-resources-gathering.yml`
- Network validation: `ansible-content/roles/network-validation/tasks/main.yml`
- Platform roles: `ansible-content/roles/{cisco-nxos-upgrade,cisco-iosxe-upgrade,fortios-upgrade,opengear-upgrade,metamako-mos-upgrade}/`
