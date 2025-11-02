# Network Validation Data Types and Normalization Reference

**Date**: November 2, 2025
**Purpose**: Comprehensive reference for all network validation data types, normalization rules, and comparison logic
**Audience**: Developers and maintainers of the network-validation role

---

## Table of Contents

1. [Overview](#overview)
2. [Validation Tasks](#validation-tasks)
3. [Data Types Reference](#data-types-reference)
4. [Normalization Rules](#normalization-rules)
5. [Comparison Methods](#comparison-methods)
6. [Status Variables](#status-variables)
7. [Implementation Details](#implementation-details)

---

## Overview

The network-validation role performs baseline comparison by:

1. **Capturing baseline data** (pre-upgrade in Step 5)
2. **Collecting post-upgrade data** (post-upgrade in Step 7)
3. **Normalizing both datasets** (removing time-sensitive fields)
4. **Comparing normalized data** (using Ansible `difference()` filter)
5. **Reporting deltas** (added/removed/unchanged)
6. **Determining pass/fail** (PASS if pre==post, FAIL otherwise)

**Key Design Principle**: Only time-sensitive operational fields are excluded from comparison. Configuration and state information must match exactly between pre and post baseline.

---

## Validation Tasks

All 5 validation tasks follow the standardized pattern (refactored November 2025):

| # | Task Name | Data Type | Normalization | File |
|---|-----------|-----------|----------------|------|
| 1 | network-resource-validation | network_resources | None (raw) | network-resource-validation.yml |
| 2 | arp-validation | arp_data + mac_data | ARP normalized, MAC raw | arp-validation.yml |
| 3 | routing-validation | rib_data + fib_data | Both normalized | routing-validation.yml |
| 4 | bfd-validation | bfd_data | Normalized | bfd-validation.yml |
| 5 | multicast-validation | PIM + IGMP + mroute | All normalized | multicast-validation.yml |

---

## Data Types Reference

### 1. Network Resources Data

**Data Type**: `network_resources`
**Task**: network-resource-validation
**Source**: Ansible network facts gathering (interfaces, VLANs, LAG, etc.)
**Structure**: Complete tree of all network configuration

**What it validates**:
- Interfaces (physical and logical)
- Layer 2 configuration (VLANs, LAG/port-channels, LACP)
- Layer 3 configuration (IP addresses, routing)
- BGP configuration (if configured)
- BFD configuration (if configured)

**Normalization**: NONE (raw comparison)
**Fields Excluded**: NONE
**Comparison**: Direct equality check (pre == post)

**Why**: Network configuration should not change during firmware upgrade. Any differences indicate configuration drift.

---

### 2. ARP Data

**Data Type**: `arp_data`
**Task**: arp-validation
**Source**: `show ip arp vrf all` (NX-OS)
**Structure**: List of ARP table entries with protocol, interface, age, MAC, IP

**What it validates**:
- Learned ARP entries for all devices on network
- Which MAC addresses are active on which IPs
- Network reachability through ARP table

**Normalization**: YES
**Fields Excluded**:
- `time-stamp` - When entry was learned (changes constantly)

**Comparison**: Normalized equality check (pre_normalized == post_normalized)

**Why**: ARP entries age differently based on traffic patterns. The timestamp changes constantly but the actual neighbors remain stable. Removing timestamp allows comparison of actual learned entries.

---

### 3. MAC Data

**Data Type**: `mac_data`
**Task**: arp-validation
**Source**: `show mac address-table` (NX-OS)
**Structure**: MAC forwarding table entries with VLAN, port, type, age

**What it validates**:
- Which MAC addresses are known on which ports
- MAC learning and forwarding state
- Switch learning table consistency

**Normalization**: NONE (raw comparison)
**Fields Excluded**: NONE

**Comparison**: Raw equality check (pre == post)

**Why**: MAC table must be identical. No time-sensitive fields (though age changes, we don't normalize it - any MAC table change is significant).

---

### 4. RIB Data

**Data Type**: `rib_data`
**Task**: routing-validation
**Source**: `show ip route vrf all` (NX-OS)
**Structure**: Routing Information Base with routes, next-hops, metrics, uptime

**What it validates**:
- Routes learned from all sources (connected, static, dynamic)
- Next-hop information
- Route metrics and preferences
- All VRFs

**Normalization**: YES
**Fields Excluded**:
- `uptime` - How long route has been active
- `time` - Timestamp of route update

**Comparison**: Normalized equality check (pre_normalized == post_normalized)

**Why**: Routes should be identical after upgrade, but uptime will change (reboot resets times). Removing uptime/time allows comparing route topology without time-related changes.

---

### 5. FIB Data

**Data Type**: `fib_data`
**Task**: routing-validation
**Source**: `show forwarding ipv4 route` (NX-OS)
**Structure**: Forwarding Information Base with installed routes, interfaces, encapsulation

**What it validates**:
- Hardware-installed forwarding entries
- Which routes are actually being used for forwarding
- Next-hop interfaces for active routes

**Normalization**: YES
**Fields Excluded**:
- `uptime` - How long route has been active
- `time` - Timestamp of route update

**Comparison**: Normalized equality check (pre_normalized == post_normalized)

**Why**: FIB entries depend on RIB. After upgrade, FIB must be identical (same routes installed). Excluding uptime/time allows comparison without time-related changes.

---

### 6. BFD Data

**Data Type**: `bfd_data`
**Task**: bfd-validation
**Source**: `show bfd neighbors` (NX-OS)
**Structure**: BFD session information with state, timers, statistics

**What it validates**:
- BFD sessions with remote neighbors
- Session state (up/down)
- Detection times and multipliers
- Diagnostic codes

**Normalization**: YES
**Fields Excluded**:
- `up_time` - How long session has been up
- `last_state_change` - When state last changed
- `state_change_count` - Number of state transitions
- `remote_disc` - Remote discriminator (assigned by peer, may change)
- `local_disc` - Local discriminator (assigned locally, may change)
- `holddown` - Holddown timer state (temporary)

**Comparison**: Normalized equality check (pre_normalized == post_normalized)

**Why**: BFD sessions may flap during reboot. After device recovers, sessions re-establish. The peers, timers, and multipliers must be identical, but session timers and discriminators are transient. Removing these allows comparing BFD configuration/peers without transient state.

---

### 7. PIM Interface Data

**Data Type**: `pim_interface_data`
**Task**: multicast-validation
**Source**: `show ip pim interface` (NX-OS)
**Structure**: PIM configuration and statistics per interface

**What it validates**:
- Which interfaces have PIM enabled
- PIM mode (sparse, dense)
- Hello interval configuration
- DR priority

**Normalization**: YES
**Fields Excluded**:
- `uptime` - How long PIM has been running on interface
- `hello_interval_running` - Current hello interval timer
- `hello-sent` - Count of hello messages sent
- `hello-rcvd` - Count of hello messages received

**Comparison**: Normalized equality check

**Why**: PIM interfaces will have different uptimes and message counts after reboot. Configuration (enabled/mode/timers) must match, but statistics reset on reboot.

---

### 8. PIM Neighbor Data

**Data Type**: `pim_neighbor_data`
**Task**: multicast-validation
**Source**: `show ip pim neighbor` (NX-OS)
**Structure**: PIM neighbors with uptime, expiration time, priority

**What it validates**:
- Which devices are PIM neighbors
- Neighbor priorities
- Neighbor reachability

**Normalization**: YES
**Fields Excluded**:
- `uptime` - How long neighbor relationship has been up
- `expires` - When neighbor hello will expire

**Comparison**: Normalized equality check

**Why**: After reboot, neighbor relationships must re-establish with same peers. Uptime and expiration timers are transient; the neighbor list/priorities must be identical.

---

### 9. IGMP Interface Data

**Data Type**: `igmp_interface_data`
**Task**: multicast-validation
**Source**: `show ip igmp interface` (NX-OS)
**Structure**: IGMP configuration and statistics per interface

**What it validates**:
- IGMP version per interface
- Query interval configuration
- Robustness variable
- Query timer state

**Normalization**: YES
**Fields Excluded**:
- `uptime` - How long IGMP has been running
- `last_reporter` - Last host to report multicast group (changes with host activity)
- `next-query` - When next query will be sent (timer state)
- `V2QueriesSent` - Count of v2 queries sent
- `V2ReportReceived` - Count of v2 reports received
- `V2LeaveReceived` - Count of v2 leaves received

**Comparison**: Normalized equality check

**Why**: IGMP timers and statistics are transient. Configuration must match, but counters and timer states reset/restart after reboot.

---

### 10. IGMP Groups Data

**Data Type**: `igmp_groups_data`
**Task**: multicast-validation
**Source**: `show ip igmp groups` (NX-OS)
**Structure**: IGMP multicast group membership with sources and timers

**What it validates**:
- Which multicast groups are active
- Group membership on which interfaces
- Source specificity (if using SSM)

**Normalization**: YES
**Fields Excluded**:
- `uptime` - How long group has been active
- `expires` - When group membership expires
- `last_reporter` - Which host last reported this group

**Comparison**: Normalized equality check

**Why**: Active multicast groups depend on host behavior (applications). Group list must be identical to pre-upgrade, but membership timers change with host activity.

---

### 11. Multicast Route Data

**Data Type**: `mroute_data`
**Task**: multicast-validation
**Source**: `show ip mroute` (NX-OS)
**Structure**: Multicast routing table with sources, groups, interfaces, statistics

**What it validates**:
- Active multicast routes (source, group)
- Multicast tree topology (incoming/outgoing interfaces)
- Multicast forwarding state

**Normalization**: YES
**Fields Excluded**:
- `uptime` - How long route has been active
- `expires` - When route will expire
- `packet_count` - Number of packets forwarded
- `last_packet_received` - When last packet was received
- `uptime_detailed` - Detailed uptime string
- `oif-uptime` - Outgoing interface uptime
- `oif-uptime-detailed` - Detailed outgoing interface uptime

**Comparison**: Normalized equality check

**Why**: Multicast routes are dynamic and depend on active flows. The tree topology (which routes exist) must be identical, but activity counters and timers reset/change with traffic.

---

## Normalization Rules

### General Normalization Pattern

All normalization is performed by the `normalize-baseline-data.yml` task:

```yaml
- name: Normalize <data-type> pre-upgrade data
  ansible.builtin.include_tasks: normalize-baseline-data.yml
  vars:
    data_to_normalize: "{{ network_baseline_pre.<data_type> }}"
    fields_to_exclude: "{{ baseline_comparison_excluded_fields.<data_type> }}"

- name: Store normalized <data-type> pre data
  ansible.builtin.set_fact:
    <data_type>_pre_normalized: "{{ normalized_data }}"
```

### How Normalization Works

The `normalize-baseline-data.yml` task recursively removes specified fields from nested data structures. For each field in `fields_to_exclude`:
1. If it's in a dict, remove the key
2. If it's in a list of dicts, remove from each dict
3. Recursively apply to nested structures

### Why Specific Fields Are Excluded

**Time/Uptime Fields**: Reset or change after reboot
**Counters**: Accumulate activity (packets, messages), reset after reboot
**Timers**: Running timers change constantly
**Transient State**: Discriminators, expiration times, last-seen timestamps

**NOT Excluded**: Configuration, learned neighbors, topology, active features

---

## Comparison Methods

### Raw Comparison (No Normalization)

Used for: `network_resources`, `mac_data`

```yaml
network_resources_comparison_match: "{{ network_baseline_post.network_resources == network_baseline_pre.network_resources }}"
```

**When to use**: Data should be 100% identical (no transient fields)

### Normalized Comparison

Used for: `arp_data`, `rib_data`, `fib_data`, `bfd_data`, all multicast data

```yaml
# Pre-upgrade normalization
- include_tasks: normalize-baseline-data.yml
  vars:
    data_to_normalize: "{{ network_baseline_pre.arp_data }}"
    fields_to_exclude: "{{ baseline_comparison_excluded_fields.arp_data }}"
- set_fact:
    arp_pre_normalized: "{{ normalized_data }}"

# Post-upgrade normalization
- include_tasks: normalize-baseline-data.yml
  vars:
    data_to_normalize: "{{ network_baseline_post.arp_data }}"
    fields_to_exclude: "{{ baseline_comparison_excluded_fields.arp_data }}"
- set_fact:
    arp_post_normalized: "{{ normalized_data }}"

# Comparison
arp_comparison_match: "{{ normalized_data == arp_pre_normalized }}"
```

**When to use**: Data has transient fields that change with time/activity

### Delta Calculation

All tasks calculate added/removed entries:

```yaml
<data_type>_added: "{{ post_normalized | difference(pre_normalized) }}"
<data_type>_removed: "{{ pre_normalized | difference(post_normalized) }}"
```

**Ansible difference() filter**: Returns elements in first list but not in second

---

## Status Variables

### Initialization

All validation tasks initialize their status to "NOT_RUN":

```yaml
- name: Initialize <data_type> comparison status
  ansible.builtin.set_fact:
    <data_type>_comparison_status: "NOT_RUN"
```

**Why**: If conditions for validation aren't met (data missing, wrong phase, check mode), status remains "NOT_RUN" rather than failing.

### Determination

Status is set once at the end of each validation task:

```yaml
- name: Determine <data_type> comparison status
  ansible.builtin.set_fact:
    <data_type>_comparison_status: "{{ 'PASS' if <match_variable> else 'FAIL' }}"
```

**Values**:
- `NOT_RUN` - Validation didn't execute (data missing or wrong phase)
- `PASS` - Pre-upgrade baseline == post-upgrade data (with normalization)
- `FAIL` - Data differs between pre and post

### Aggregation

In `main.yml`, all status variables are aggregated:

```yaml
- name: Aggregate comparison validation results
  ansible.builtin.set_fact:
    validation_comparison_results:
      network_resources_status: "{{ network_resources_comparison_status }}"
      arp_mac_status: "{{ arp_mac_comparison_status }}"
      routing_status: "{{ routing_comparison_status }}"
      bfd_status: "{{ bfd_comparison_status }}"
      multicast_status: "{{ multicast_comparison_status }}"
      timestamp: "{{ lookup('pipe', 'date -u +%Y-%m-%dT%H:%M:%SZ') }}"
```

---

## Implementation Details

### Task Structure Pattern

All 5 validation tasks follow this pattern:

```yaml
# 1. Initialize status
- name: Initialize <data-type> comparison status
  ansible.builtin.set_fact:
    <data_type>_comparison_status: "NOT_RUN"

# 2. Main comparison block (runs only if conditions met)
- name: Compare <data-type> with baseline (post-upgrade only)
  when:
    - validation_phase is defined
    - validation_phase == 'post_upgrade'
    - platform == 'nxos'
    - not ansible_check_mode
    - network_baseline_pre is defined
    - network_baseline_post is defined
    - network_baseline_pre.<data_type> is defined
    - network_baseline_post.<data_type> is defined
  block:
    # 3. Data-type-specific block(s) (nested)
    - name: <Data-Type> Data Comparison
      when: <conditions-for-this-data-type>
      block:
        # 4. Normalize (if needed)
        - include_tasks: normalize-baseline-data.yml
          vars:
            data_to_normalize: "{{ network_baseline_pre.<data_type> }}"
            fields_to_exclude: "{{ baseline_comparison_excluded_fields.<data_type> }}"
        - set_fact:
            <data_type>_pre_normalized: "{{ normalized_data }}"

        # 5. Calculate deltas
        - set_fact:
            <data_type>_added: "{{ post_normalized | difference(pre_normalized) }}"
            <data_type>_removed: "{{ pre_normalized | difference(post_normalized) }}"
            <data_type>_match: "{{ post_normalized == pre_normalized }}"

        # 6. Report (conditional, only if changes)
        - name: Report <data-type> added entries
          ansible.builtin.debug:
            msg:
              - "=== <Data-Type> Comparison ==="
              - "Added/Modified entries:"
              - "{{ <data_type>_added | to_nice_json }}"
          when: <data_type>_added | length > 0

    # 7. Summary report
    - name: Report no <data-type> changes
      ansible.builtin.debug:
        msg:
          - "=== <Data-Type> Comparison ==="
          - "Status: No changes detected"
      when:
        - <data_type>_match | default(true)

    # 8. Set status (once at end)
    - name: Determine <data-type> comparison status
      ansible.builtin.set_fact:
        <data_type>_comparison_status: "{{ 'PASS' if <match_variables> else 'FAIL' }}"
```

### Conditions for Post-Upgrade Validation

All validation tasks check:

1. `validation_phase == 'post_upgrade'` - Only validate after upgrade (Step 7)
2. `platform == 'nxos'` - Only for NX-OS (other platforms have different approaches)
3. `not ansible_check_mode` - Skip in check mode (can't gather post-upgrade data in check mode)
4. Data exists in both baselines - Pre and post data must be present

These conditions prevent:
- Running pre-validation data collection during post-validation phase
- Failing when data isn't available
- Attempting validation in check mode (no actual device changes)

### Reporting Strategy

All debug messages are conditional:

```yaml
when: <data_type>_added | length > 0  # Only report if changes exist
```

This prevents empty "Added entries: []" messages in output.

---

## Example: Full ARP Validation Walkthrough

**Scenario**: Comparing ARP data pre and post upgrade

### Step 1: Initialization (always runs)
```yaml
arp_mac_comparison_status: "NOT_RUN"
```

### Step 2: Pre-Upgrade (in Step 5)
```yaml
# Network validation gathers this
network_baseline_pre.arp_data:
  - interface: "eth0"
    ip_address: "10.0.1.100"
    mac_address: "aa:bb:cc:dd:ee:ff"
    time-stamp: "2025-11-02T12:00:00Z"
  - interface: "eth1"
    ip_address: "10.0.2.100"
    mac_address: "11:22:33:44:55:66"
    time-stamp: "2025-11-02T12:00:01Z"
```

### Step 3: Normalization (removes time-stamp)
```yaml
arp_pre_normalized:
  - interface: "eth0"
    ip_address: "10.0.1.100"
    mac_address: "aa:bb:cc:dd:ee:ff"
  - interface: "eth1"
    ip_address: "10.0.2.100"
    mac_address: "11:22:33:44:55:66"
```

### Step 4: Post-Upgrade (in Step 7)
```yaml
# Device now has same ARP entries (devices still reachable)
network_baseline_post.arp_data:
  - interface: "eth0"
    ip_address: "10.0.1.100"
    mac_address: "aa:bb:cc:dd:ee:ff"
    time-stamp: "2025-11-02T13:00:00Z"  # Different time!
  - interface: "eth1"
    ip_address: "10.0.2.100"
    mac_address: "11:22:33:44:55:66"
    time-stamp: "2025-11-02T13:00:01Z"  # Different time!
```

### Step 5: Post-Normalization (removes time-stamp)
```yaml
arp_post_normalized:
  - interface: "eth0"
    ip_address: "10.0.1.100"
    mac_address: "aa:bb:cc:dd:ee:ff"
  - interface: "eth1"
    ip_address: "10.0.2.100"
    mac_address: "11:22:33:44:55:66"
```

### Step 6: Comparison
```yaml
# Raw comparison would FAIL (timestamps differ)
arp_pre_raw == arp_post_raw  # FALSE (time-stamp differs)

# Normalized comparison PASSES (timestamps removed)
arp_pre_normalized == arp_post_normalized  # TRUE (same entries)

# Deltas
arp_added: []    # No new entries
arp_removed: []  # No removed entries
arp_match: true  # Match!
```

### Step 7: Output
```
=== ARP and MAC Data Comparison ===
Status: No changes detected in ARP data
```

### Step 8: Status
```yaml
arp_mac_comparison_status: "PASS"
```

---

## Debugging Guide

### If validation shows FAIL but should PASS

1. **Check normalization**: Are the excluded fields actually being removed?
   ```yaml
   - name: Debug - show pre-normalized ARP
     ansible.builtin.debug:
       msg: "{{ arp_pre_normalized }}"
   ```

2. **Check excluded fields**: Are all time-sensitive fields listed in defaults?
   ```bash
   # In defaults/main.yml
   baseline_comparison_excluded_fields:
     arp_data:
       - time-stamp  # Is this present?
   ```

3. **Check device state**: Did device actually restart/reload all services?
   - After reboot, some services may take time to converge
   - Routes may not be learned yet
   - IGMP groups may not be reestablished

4. **Check comparison logic**: Are you comparing the right variables?
   ```yaml
   # Should be comparing normalized data, not raw
   arp_comparison_match: "{{ arp_post_normalized == arp_pre_normalized }}"  # RIGHT
   # NOT
   arp_comparison_match: "{{ network_baseline_post.arp_data == network_baseline_pre.arp_data }}"  # WRONG
   ```

### If validation shows PASS but unexpected

1. **Check that data was actually collected**: Was data present in baseline?
2. **Check conditions**: Did post-upgrade validation actually run? (check logs for when clauses)
3. **Check device platform**: Different platforms (IOS-XE, FortiOS) have different validations

---

## Related Files

- **Implementation**: `ansible-content/roles/network-validation/tasks/*.yml`
- **Configuration**: `ansible-content/roles/network-validation/defaults/main.yml`
- **Orchestration**: `ansible-content/roles/network-validation/tasks/main.yml`
- **Step 5 (Pre-validation)**: `ansible-content/playbooks/steps/step-5-pre-validation.yml`
- **Step 7 (Post-validation)**: `ansible-content/playbooks/steps/step-7-post-validation.yml`

---

**Document Version**: 1.0
**Last Updated**: November 2, 2025
**Maintainer**: Network Validation Task Owners
