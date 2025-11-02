# Baseline Comparison Output for All Data Types

Complete reference showing example output for all 10 network data types collected and compared during baseline validation.

---

## 1. ARP Data (show ip arp vrf all)

### When Changes Detected

```
==========================================
BASELINE DELTA DETAILS FOR: ARP_DATA
==========================================
Pre-Upgrade Entries: 148
Post-Upgrade Entries: 151
Change Count: 5

added:
  - address: '192.168.1.250'
    incomplete: false
    interface: Ethernet1/1
    mac: '00:11:22:33:44:55'
    physical_interface: Ethernet1/1
    vrf: default
  - address: '192.168.1.251'
    incomplete: false
    interface: Ethernet1/1
    mac: '00:11:22:33:44:56'
    physical_interface: Ethernet1/1
    vrf: default
  - address: '10.50.50.100'
    incomplete: false
    interface: Vlan50
    mac: '00:aa:bb:cc:dd:ee'
    physical_interface: Vlan50
    vrf: management
removed:
  - address: '192.168.1.200'
    incomplete: false
    interface: Ethernet1/3
    mac: '00:11:22:33:44:88'
    physical_interface: Ethernet1/3
    vrf: default
  - address: '192.168.1.201'
    incomplete: false
    interface: Ethernet1/3
    mac: '00:11:22:33:44:89'
    physical_interface: Ethernet1/3
    vrf: default
post_entries: 151
pre_entries: 148
```

**Excluded fields:** age, time_stamp
**Interpretation:** Network hosts have changed; some hosts aged out, new hosts learned

---

## 2. MAC Address Table (show mac address-table)

### When Changes Detected

```
==========================================
BASELINE DELTA DETAILS FOR: MAC_DATA
==========================================
Pre-Upgrade Entries: 512
Post-Upgrade Entries: 523
Change Count: 18

added:
  - entry_type: dynamic
    interface: port-channel42
    mac: '00:50:f2:c1:a2:3b'
    vlan: '100'
  - entry_type: dynamic
    interface: port-channel42
    mac: '00:50:f2:c1:a2:3c'
    vlan: '100'
  - entry_type: dynamic
    interface: Ethernet1/48
    mac: '00:50:f2:c1:a2:3d'
    vlan: '200'
  - entry_type: dynamic
    interface: Ethernet1/48
    mac: '00:50:f2:c1:a2:3e'
    vlan: '200'
  - entry_type: dynamic
    interface: port-channel42
    mac: '00:50:f2:c1:a2:3f'
    vlan: '100'
removed:
  - entry_type: dynamic
    interface: port-channel1
    mac: '00:50:f2:c1:a2:00'
    vlan: '100'
  - entry_type: dynamic
    interface: Ethernet1/2
    mac: '00:50:f2:c1:a2:01'
    vlan: '200'
  - entry_type: dynamic
    interface: port-channel1
    mac: '00:50:f2:c1:a2:02'
    vlan: '300'
post_entries: 523
pre_entries: 512
```

**Excluded fields:** age
**Interpretation:** MAC table grew by 11 entries; normal learning activity; some hosts aged out

---

## 3. RIB Data (show ip route vrf all)

### When No Changes

```
==========================================
BASELINE DELTA DETAILS FOR: RIB_DATA
==========================================
Pre-Upgrade Entries: 8745
Post-Upgrade Entries: 8745
Change Count: 0

added: []
removed: []
post_entries: 8745
pre_entries: 8745
```

**Excluded fields:** uptime, time
**Interpretation:** Routing table is stable; excellent sign for upgrade success

### When Changes Detected

```
==========================================
BASELINE DELTA DETAILS FOR: RIB_DATA
==========================================
Pre-Upgrade Entries: 8745
Post-Upgrade Entries: 8756
Change Count: 16

added:
  - destination: '10.100.0.0'
    distance: 20
    interface: Ethernet1/1
    metric: 0
    next_hop: '10.1.1.1'
    protocol: bgp
    tag: '65001'
    vrf: default
  - destination: '10.101.0.0'
    distance: 20
    interface: Ethernet1/1
    metric: 0
    next_hop: '10.1.1.1'
    protocol: bgp
    tag: '65001'
    vrf: default
  - destination: '10.102.0.0'
    distance: 20
    interface: Ethernet1/1
    metric: 0
    next_hop: '10.1.1.1'
    protocol: bgp
    tag: '65001'
    vrf: default
removed:
  - destination: '10.200.0.0'
    distance: 20
    interface: Ethernet1/2
    metric: 0
    next_hop: '10.2.2.1'
    protocol: bgp
    tag: '65002'
    vrf: default
post_entries: 8756
pre_entries: 8745
```

**Excluded fields:** uptime, time
**Interpretation:** BGP routes changed (new remote prefixes, old ones withdrawn); normal after upgrade

---

## 4. FIB Data (show forwarding ipv4 route)

### When No Changes

```
==========================================
BASELINE DELTA DETAILS FOR: FIB_DATA
==========================================
Pre-Upgrade Entries: 8650
Post-Upgrade Entries: 8650
Change Count: 0

added: []
removed: []
post_entries: 8650
pre_entries: 8650
```

**Excluded fields:** uptime, time
**Interpretation:** Forwarding table matches RIB; routes are being programmed correctly

### When Changes Detected

```
==========================================
BASELINE DELTA DETAILS FOR: FIB_DATA
==========================================
Pre-Upgrade Entries: 8650
Post-Upgrade Entries: 8662
Change Count: 12

added:
  - adjacency: 10.1.1.1
    destination: '10.100.0.0'
    interface: Ethernet1/1
    load_sharing: false
    mask: 255.255.255.0
    metric: 0
    next_hop: '10.1.1.1'
    vrf: default
  - adjacency: 10.1.1.1
    destination: '10.101.0.0'
    interface: Ethernet1/1
    load_sharing: false
    mask: 255.255.255.0
    metric: 0
    next_hop: '10.1.1.1'
    vrf: default
removed:
  - adjacency: 10.2.2.1
    destination: '10.200.0.0'
    interface: Ethernet1/2
    load_sharing: false
    mask: 255.255.255.0
    metric: 0
    next_hop: '10.2.2.1'
    vrf: default
post_entries: 8662
pre_entries: 8650
```

**Excluded fields:** uptime, time
**Interpretation:** Hardware forwarding table programmed with new routes; matches RIB

---

## 5. BFD Data (show bfd neighbors vrf all)

### When All Sessions Stable

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

**Excluded fields:** up_time, last_state_change, state_change_count, remote_disc, local_disc, holddown
**Interpretation:** All BFD sessions recovered; excellent stability indicator

### When Sessions Changed

```
==========================================
BASELINE DELTA DETAILS FOR: BFD_DATA
==========================================
Pre-Upgrade Entries: 8
Post-Upgrade Entries: 7
Change Count: 1

added: []
removed:
  - diagnostic_code: '3'
    interface: Ethernet1/10
    neighbor_address: '10.10.10.1'
    remote_state: Down
    state: Down
    vrf: default
post_entries: 7
pre_entries: 8
```

**Excluded fields:** up_time, last_state_change, state_change_count, remote_disc, local_disc, holddown
**Interpretation:** One BFD session lost (likely peer removed or link down); requires investigation

---

## 6. PIM Interface Data (show ip pim interface)

### When Multicast Disabled (No Data)

```
==========================================
BASELINE DELTA DETAILS FOR: PIM_INTERFACE_DATA
==========================================
Pre-Upgrade Entries: 0
Post-Upgrade Entries: 0
Change Count: 0

added: []
removed: []
post_entries: 0
pre_entries: 0
```

**Excluded fields:** uptime, hello_interval_running, hello-sent, hello-rcvd
**Interpretation:** Multicast not enabled; no comparison needed

### When Multicast Enabled

```
==========================================
BASELINE DELTA DETAILS FOR: PIM_INTERFACE_DATA
==========================================
Pre-Upgrade Entries: 12
Post-Upgrade Entries: 12
Change Count: 0

added: []
removed: []
post_entries: 12
pre_entries: 12
```

**Excluded fields:** uptime, hello_interval_running, hello-sent, hello-rcvd
**Interpretation:** All PIM interfaces recovered; multicast control plane stable

### When Interface Changes

```
==========================================
BASELINE DELTA DETAILS FOR: PIM_INTERFACE_DATA
==========================================
Pre-Upgrade Entries: 12
Post-Upgrade Entries: 11
Change Count: 1

added: []
removed:
  - address: '10.50.50.1'
    dr_priority: 100
    hello_interval: 30
    interface: Ethernet1/47
    pim_enabled: true
post_entries: 11
pre_entries: 12
```

**Excluded fields:** uptime, hello_interval_running, hello-sent, hello-rcvd
**Interpretation:** One PIM interface down (possibly unplugged or shutdown)

---

## 7. PIM Neighbor Data (show ip pim neighbor)

### When All Neighbors Up

```
==========================================
BASELINE DELTA DETAILS FOR: PIM_NEIGHBOR_DATA
==========================================
Pre-Upgrade Entries: 18
Post-Upgrade Entries: 18
Change Count: 0

added: []
removed: []
post_entries: 18
pre_entries: 18
```

**Excluded fields:** uptime, expires
**Interpretation:** All PIM neighbors re-established; multicast topology recovered

### When Neighbor Lost

```
==========================================
BASELINE DELTA DETAILS FOR: PIM_NEIGHBOR_DATA
==========================================
Pre-Upgrade Entries: 18
Post-Upgrade Entries: 16
Change Count: 2

added: []
removed:
  - expiry_time: 105
    generation_id: '1234567890'
    interface: Ethernet1/10
    neighbor_address: '10.10.10.2'
  - expiry_time: 105
    generation_id: '1234567890'
    interface: Ethernet1/11
    neighbor_address: '10.11.11.1'
post_entries: 16
pre_entries: 18
```

**Excluded fields:** uptime, expires
**Interpretation:** Two PIM neighbors did not re-establish; possible link issue or neighbor device problem

---

## 8. IGMP Interface Data (show ip igmp interface)

### When All Interfaces Up

```
==========================================
BASELINE DELTA DETAILS FOR: IGMP_INTERFACE_DATA
==========================================
Pre-Upgrade Entries: 12
Post-Upgrade Entries: 12
Change Count: 0

added: []
removed: []
post_entries: 12
pre_entries: 12
```

**Excluded fields:** uptime, last_reporter, next-query, V2QueriesSent, V2ReportReceived, V2LeaveReceived
**Interpretation:** All IGMP interfaces functional; multicast receiver support intact

### When Interface Changes

```
==========================================
BASELINE DELTA DETAILS FOR: IGMP_INTERFACE_DATA
==========================================
Pre-Upgrade Entries: 12
Post-Upgrade Entries: 11
Change Count: 1

added: []
removed:
  - address: '10.50.50.1'
    interface: Vlan50
    querier: true
    query_interval: 125
    robustness_variable: 2
    version: 3
post_entries: 11
pre_entries: 12
```

**Excluded fields:** uptime, last_reporter, next-query, V2QueriesSent, V2ReportReceived, V2LeaveReceived
**Interpretation:** One VLAN interface lost IGMP function; check VLAN status

---

## 9. IGMP Groups Data (show ip igmp groups)

### When Groups Stable

```
==========================================
BASELINE DELTA DETAILS FOR: IGMP_GROUPS_DATA
==========================================
Pre-Upgrade Entries: 247
Post-Upgrade Entries: 247
Change Count: 0

added: []
removed: []
post_entries: 247
pre_entries: 247
```

**Excluded fields:** uptime, expires, last_reporter
**Interpretation:** All multicast groups recovered; receivers rejoined

### When Groups Change

```
==========================================
BASELINE DELTA DETAILS FOR: IGMP_GROUPS_DATA
==========================================
Pre-Upgrade Entries: 247
Post-Upgrade Entries: 243
Change Count: 6

added:
  - group_address: '239.100.100.5'
    group_source_if: Vlan100
    group_type: active
    interface: Vlan100
removed:
  - group_address: '239.200.200.1'
    group_source_if: Vlan200
    group_type: active
    interface: Vlan200
  - group_address: '239.200.200.2'
    group_source_if: Vlan200
    group_type: active
    interface: Vlan200
  - group_address: '239.200.200.3'
    group_source_if: Vlan200
    group_type: active
    interface: Vlan200
  - group_address: '239.200.200.4'
    group_source_if: Vlan200
    group_type: active
    interface: Vlan200
  - group_address: '239.200.200.5'
    group_source_if: Vlan200
    group_type: active
    interface: Vlan200
post_entries: 243
pre_entries: 247
```

**Excluded fields:** uptime, expires, last_reporter
**Interpretation:** Some receivers left/rejoined; VLAN200 receivers stopped; VLAN100 receiver started

---

## 10. Multicast Routes (show ip mroute)

### When All Routes Stable

```
==========================================
BASELINE DELTA DETAILS FOR: MROUTE_DATA
==========================================
Pre-Upgrade Entries: 42
Post-Upgrade Entries: 42
Change Count: 0

added: []
removed: []
post_entries: 42
pre_entries: 42
```

**Excluded fields:** uptime, expires, packet_count, last_packet_received, uptime_detailed, oif-uptime, oif-uptime-detailed
**Interpretation:** Multicast forwarding tree intact; traffic flowing on same tree

### When Routes Prune/Join

```
==========================================
BASELINE DELTA DETAILS FOR: MROUTE_DATA
==========================================
Pre-Upgrade Entries: 42
Post-Upgrade Entries: 39
Change Count: 4

added:
  - group: '224.1.1.1/32'
    incoming_interface: Ethernet1/1
    rpf_neighbor: '10.1.1.1'
    route_state: Active
    source: '192.168.1.100'
    vrf: default
removed:
  - group: '224.0.0.0/4'
    incoming_interface: Ethernet1/2
    rpf_neighbor: '10.2.2.1'
    route_state: Pruned
    source: '0.0.0.0'
    vrf: default
  - group: '225.1.1.0/24'
    incoming_interface: Ethernet1/2
    rpf_neighbor: '10.2.2.1'
    route_state: Pruned
    source: '10.0.0.1'
    vrf: default
  - group: '225.1.2.0/24'
    incoming_interface: Ethernet1/2
    rpf_neighbor: '10.2.2.1'
    route_state: Pruned
    source: '10.0.0.2'
    vrf: default
post_entries: 39
pre_entries: 42
```

**Excluded fields:** uptime, expires, packet_count, last_packet_received, uptime_detailed, oif-uptime, oif-uptime-detailed
**Interpretation:** Multicast tree adjusted; pruned routes removed (no receivers); new active route added

---

## Summary Table of All Data Types

| Data Type | Show Command | Entries | Time-Sensitive Fields | Expected Changes Post-Upgrade |
|-----------|--------------|---------|----------------------|-------------------------------|
| **ARP** | show ip arp vrf all | ~100-500 | age, time_stamp | Normal (hosts learn/age) |
| **MAC** | show mac address-table | ~100-1000 | age | Normal (learning activity) |
| **RIB** | show ip route vrf all | ~1000-10000 | uptime, time | Should be STABLE |
| **FIB** | show forwarding ipv4 route | ~1000-10000 | uptime, time | Should match RIB changes |
| **BFD** | show bfd neighbors vrf all | 0-50 | up_time, last_state_change, state_change_count, remote_disc, local_disc, holddown | Should be STABLE |
| **PIM Int** | show ip pim interface | 0-100 | uptime, hello_interval_running, hello-sent, hello-rcvd | Should be STABLE |
| **PIM Nbr** | show ip pim neighbor | 0-100 | uptime, expires | Should be STABLE |
| **IGMP Int** | show ip igmp interface | 0-100 | uptime, last_reporter, next-query, V2QueriesSent, V2ReportReceived, V2LeaveReceived | Should be STABLE |
| **IGMP Groups** | show ip igmp groups | 0-500 | uptime, expires, last_reporter | Variable (receivers join/leave) |
| **Mroute** | show ip mroute | 0-500 | uptime, expires, packet_count, last_packet_received, uptime_detailed, oif-uptime, oif-uptime-detailed | Variable (pruning/joining) |

---

## Output Analysis Quick Guide

### ✓ Healthy Upgrade
```
All Data Matches: true
Sections with Differences: None
```
- All RIB/FIB/BFD/PIM stable
- ARP/MAC/IGMP/Mroute changes are normal

### ⚠️ Review Needed
```
Sections with Differences: arp_data, mac_data, igmp_groups_data
```
- ARP/MAC changes expected
- IGMP groups expected after receivers reconnect
- Check count is reasonable

### 🚨 Critical Issues
```
Sections with Differences: rib_data, bfd_data, pim_neighbor_data
Change Count: 20+
```
- RIB changes indicate routing problems
- BFD/PIM changes indicate control plane issues
- Investigate immediately

---

## Operational Tips

1. **Run baseline comparison with `show_debug=true` to see detailed output**
   ```bash
   ansible-playbook main-upgrade-workflow.yml --tags step7 \
     -e target_hosts=switches -e show_debug=true
   ```

2. **Compare output between upgrade phases**
   - Pre-upgrade (step5): Creates baseline
   - Post-upgrade (step7): Compares and shows deltas
   - Review what changed and why

3. **Focus on critical stability metrics**
   - RIB/FIB should match
   - BFD/PIM/RIB should be stable
   - ARP/MAC/IGMP/Mroute natural changes expected

4. **Time-sensitive fields automatically excluded**
   - Prevents false alerts from timing differences
   - Focuses on structural changes only
   - All timing fields stripped before comparison
