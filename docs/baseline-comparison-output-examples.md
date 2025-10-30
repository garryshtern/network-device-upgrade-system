# Baseline Comparison Output Examples

## Overview

This document shows example output from the baseline comparison functionality when comparing pre-upgrade and post-upgrade network state.

## Summary Output

When baseline comparison completes, it displays a summary:

```
==========================================
BASELINE COMPARISON RESULTS
==========================================
Device: nxos-switch-01
Baseline Available: true
Comparison Performed: true
All Data Matches: false
Sections Checked: 10
Sections with Differences: arp_data, mac_data, mroute_data
==========================================
```

**Fields:**
- **Device**: Inventory hostname being validated
- **Baseline Available**: Pre-upgrade baseline was found and loaded
- **Comparison Performed**: Comparison ran successfully
- **All Data Matches**: Whether all checked sections match (true/false)
- **Sections Checked**: Total number of data type sections evaluated
- **Sections with Differences**: List of sections where pre/post state differs

## Detailed Delta Output

When differences are found, detailed delta information is displayed for each affected section:

### Example 1: ARP Data Changes

```
==========================================
BASELINE DELTA DETAILS FOR: ARP_DATA
==========================================
Pre-Upgrade Entries: 148
Post-Upgrade Entries: 151
Change Count: 5

added:
  - address: '192.168.1.250'
    interface: Ethernet1/1
    mac: '00:11:22:33:44:55'
    physical_interface: Ethernet1/1
    vrf: default
  - address: '192.168.1.251'
    interface: Ethernet1/1
    mac: '00:11:22:33:44:56'
    physical_interface: Ethernet1/1
    vrf: default
  - address: '192.168.1.252'
    interface: Ethernet1/2
    mac: '00:11:22:33:44:57'
    physical_interface: Ethernet1/2
    vrf: default
removed:
  - address: '192.168.1.200'
    interface: Ethernet1/3
    mac: '00:11:22:33:44:88'
    physical_interface: Ethernet1/3
    vrf: default
  - address: '192.168.1.201'
    interface: Ethernet1/3
    mac: '00:11:22:33:44:89'
    physical_interface: Ethernet1/3
    vrf: default
post_entries: 151
pre_entries: 148
```

**What This Shows:**
- **Pre-Upgrade Entries**: 148 ARP entries before upgrade
- **Post-Upgrade Entries**: 151 ARP entries after upgrade
- **Change Count**: 5 total changes (3 added + 2 removed)
- **Added**: 3 new ARP entries learned post-upgrade
- **Removed**: 2 ARP entries that aged out/disappeared post-upgrade

### Example 2: MAC Address Table Changes

```
==========================================
BASELINE DELTA DETAILS FOR: MAC_DATA
==========================================
Pre-Upgrade Entries: 512
Post-Upgrade Entries: 523
Change Count: 18

added:
  - mac: '00:50:f2:c1:a2:3b'
    vlan: '100'
    interface: port-channel42
    entry_type: dynamic
  - mac: '00:50:f2:c1:a2:3c'
    vlan: '100'
    interface: port-channel42
    entry_type: dynamic
removed:
  - mac: '00:50:f2:c1:a2:00'
    vlan: '100'
    interface: port-channel1
    entry_type: dynamic
post_entries: 523
pre_entries: 512
```

**What This Shows:**
- MAC table grew by 11 entries (523 - 512)
- Some old MAC entries were aged out
- Dynamic MAC learning is working correctly post-upgrade

### Example 3: Multicast Route Changes

```
==========================================
BASELINE DELTA DETAILS FOR: MROUTE_DATA
==========================================
Pre-Upgrade Entries: 42
Post-Upgrade Entries: 39
Change Count: 4

added: []
removed:
  - group: '224.0.0.0/4'
    source: '0.0.0.0'
    vrf: default
    state: Pruned
  - group: '225.1.1.0/24'
    source: '10.0.0.1'
    vrf: default
    state: Pruned
post_entries: 39
pre_entries: 42
```

**What This Shows:**
- 3 multicast routes were removed (pruned)
- No new routes were added
- Could indicate multicast tree adjustment or peer changes

### Example 4: BFD Session Changes

```
==========================================
BASELINE DELTA DETAILS FOR: BFD_DATA
==========================================
Pre-Upgrade Entries: 8
Post-Upgrade Entries: 8
Change Count: 0

added: []
removed: []
post_entries: 8
pre_entries: 8
```

**What This Shows:**
- All BFD sessions maintained their state
- No new sessions, no lost sessions
- Excellent stability indicator for control plane protocols

## Fields Excluded from Comparison

The following time-sensitive fields are automatically excluded from baseline comparison to prevent false positives:

### ARP Data
- `age` - Time ARP entry has been learned
- `time_stamp` - When entry was learned

### MAC Address Table
- `age` - Time MAC entry has been learned

### Routing (RIB/FIB)
- `uptime` - How long route has been learned
- `time` - Timestamp of route learning

### BFD
- `up_time` - How long session has been up
- `last_state_change` - Timestamp of last state change
- `state_change_count` - Number of state transitions
- `remote_disc` - Discriminator value (changes)
- `local_disc` - Local discriminator
- `holddown` - Holddown timer state

### PIM Interface
- `uptime` - How long interface has had PIM enabled
- `hello_interval_running` - Current hello timer
- `hello-sent` - Number of hellos sent
- `hello-rcvd` - Number of hellos received

### IGMP Interface
- `uptime` - How long IGMP has been on interface
- `last_reporter` - Most recent multicast group reporter
- `next-query` - When next query will be sent
- `V2QueriesSent` - Count of v2 queries sent
- `V2ReportReceived` - Count of v2 reports received
- `V2LeaveReceived` - Count of v2 leave messages received

### Multicast Routes
- `uptime` - How long route has been active
- `expires` - When route entry expires
- `packet_count` - Multicast packets received
- `last_packet_received` - Timestamp of last packet
- `uptime_detailed` - Detailed uptime string
- `oif-uptime` - Outgoing interface uptime
- `oif-uptime-detailed` - Detailed OIF uptime

## Interpretation Guide

### No Differences
```
All Data Matches: true
Sections with Differences: None
```
✓ Network state is stable post-upgrade - excellent indicator of successful upgrade

### Only Timing Changes
```
All Data Matches: true
Sections with Differences: None
```
✓ Small timing variations are expected and automatically excluded

### Structural Changes Detected
```
All Data Matches: false
Sections with Differences: arp_data, bgp_data
```
⚠️ Indicates actual network state changes - requires investigation

**Possible causes:**
- New devices on network
- Routing topology changes
- BGP peer changes
- Dynamic address assignment differences

### Critical Changes
```
Sections with Differences: interface_data, bgp_neighbors
Change Count: 25+
```
🚨 Significant network changes detected - may indicate upgrade issue

## Output Conditions

**Summary output displays when:**
- `show_debug` flag is enabled in playbook execution

**Detailed delta output displays when:**
- `show_debug` flag is enabled
- At least one section has differences
- `baseline_deltas` variable was successfully populated

## Usage

To enable detailed baseline comparison output during playbook run:

```bash
ansible-playbook main-upgrade-workflow.yml \
  --tags step7 \
  --extra-vars="target_hosts=nxos-switches show_debug=true" \
  -e target_firmware=nxos.10.3.3.bin \
  -e max_concurrent=5
```

Or in playbook variables:
```yaml
show_debug: true
```

## Troubleshooting

### No detailed delta output shown
**Symptoms:** Summary shows differences but no BASELINE_DELTA_DETAILS section appears

**Causes:**
1. `show_debug` is false - set to true to see output
2. `baseline_deltas` variable not populated - check generate-baseline-deltas.yml ran

**Resolution:** Run with `show_debug=true` and verify previous steps completed

### Missing data in deltas
**Symptoms:** Added/removed lists are empty even though change count is high

**Causes:**
1. Data format incompatibility - field names may not match JSON output
2. Normalization removed too much data - check excluded_fields config

**Resolution:** Verify field names match actual device JSON output

### All changes detected as differences
**Symptoms:** Every section shows as different even between consecutive runs

**Causes:**
1. Excluded fields list is incomplete or incorrect
2. Time-sensitive fields not being properly removed during normalization

**Resolution:** Verify baseline_comparison_excluded_fields contains all time-sensitive fields
