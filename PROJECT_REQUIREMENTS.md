# Network Device Upgrade Management System - Project Requirements

## Project Overview

Build a complete AWX-based network device upgrade management system for 1000+ heterogeneous network devices. The system must automate firmware upgrades across multiple vendor platforms while providing comprehensive reporting, security validation, and integration with existing monitoring infrastructure.

## System Architecture Requirements

### Single Server Deployment
- **Container Deploymnet**: Single Linux server (no clustering)
- **Database Backend**: SQLite only (no PostgreSQL clusters)
- **Service Management**: user systemd services for all components
- **High Availability**: Not required, but ensure graceful recovery from failures


### Core Components
1. **AWX**: Open source automation platform with web UI
2. **Netbox**: Device inventory and IPAM management
3. **Telegraf**: Metrics collection for existing InfluxDB v2
4. **Redis**: Job queuing and caching
5. **File Storage**: Local filesystem for configurations and firmware

## Supported Device Platforms

Build support for the following network device platforms:

### 1. Cisco NX-OS (Nexus Switches)
- **Collection**: `cisco.nxos`
- **Features**: image staging validation, EPLD upgrades
- **Validation**: interface & optics states, BGP, PIM, routing tables, ARP, IGMP, BFD

### 2. Cisco IOS-XE (Enterprise Routers/Switches)  
- **Collection**: `cisco.ios`
- **Features**: Install mode vs. bundle mode handling
- **Validation**: interface & optics states, BGP, routing tables, ARP

### 3. Metamako MOS (Ultra-Low Latency Switches)
- **Collection**: `ansible.netcommon` with custom CLI modules
- **Features**: Custom MOS command handling, latency-sensitive operations
- **Validation**: Interface states, metawatch status, metamux status (if equipped)

### 4. Opengear (Console Servers/Smart PDUs)
- **Collection**: `ansible.netcommon`
- **Features**: Web interface automation, serial port management
- **Models**: OM2200, CM8100, CM7100, IM7200
- **Validation**: Port status, connectivity, power management

### 5. FortiOS (Fortinet Firewalls)
- **Collection**: `fortinet.fortios`
- **Features**: license validation
- **Validation**: Security policies, routing, interface states

## Critical Security Requirements

### Cryptographic Integrity Verification
- **Hash Verification**: SHA512 hash validation for all firmware images
- **Pre-Transfer**: Verify source image integrity against <filename>.sha512 files
- **Post-Transfer**: Verify transferred image integrity on device
- **Signature Validation**: Cryptographic signature verification where supported
- **Audit Trail**: Log all hash verification results and discrepancies

### Storage Management and Validation
- **Pre-Upgrade Space Check**: Validate sufficient storage for new firmware
- **Automatic Cleanup**: Remove old/unused firmware images before upgrade
- **Rollback Safety**: Maintain minimum 2 firmware images for emergency recovery
- **Storage Monitoring**: Track available space and alert on low storage conditions

## Comprehensive Network State Validation

### Pre-Upgrade State Capture
Capture baseline network state before any upgrade operations:

#### BFD State Validation
- BFD session states and statistics
- BFD neighbor reachability

#### BGP Validation
- BGP neighbor states and session status
- Received and advertised route counts per neighbor
- BGP table size and convergence metrics
- Route-map and policy validation

#### Interface State Validation  
- Interface operational status (up/down)
- Interface error counters and utilization
- Interface descriptions and VLAN assignments
- Link aggregation (LACP/PAgP) status
- Optics status (SFP/QSFP diagnostics)

#### Routing Protocol Validation
- Static route presence and reachability
- Default route validation and next-hop verification

#### Multicast Protocol Validation
- PIM neighbor states and modes (sparse/dense)
- IGMP group memberships and version
- Multicast routing table entries
- Rendezvous Point (RP) reachability
- RP mapping and Anycast RP validation

#### ARP and Neighbor Discovery
- ARP table entries and MAC address mappings
- DHCP snooping binding table verification

### Post-Upgrade State Validation
- **State Comparison**: Compare pre/post upgrade states
- **Convergence Timing**: Measure protocol convergence times
- **Route Count Validation**: Ensure route counts match baseline
- **Interface Recovery**: Verify all interfaces return to operational state
- **Protocol Recovery**: Validate all routing protocols reconverge properly
- **Alerting**: Generate alerts for any discrepancies or failures
- **Reporting**: Detailed reports on validation results
- **Inventory Update**: Update Netbox with new firmware versions and validation results
- **Metrics Export**: Export validation results to InfluxDB for dashboarding

## Upgrade Workflow Requirements

### Phase 1: Image Loading (Business Hours Safe)
1. **Pre-Validation**
   - Device health check and reachability
   - Current firmware version identification
   - Storage space validation
   - Network state baseline capture

2. **Storage Preparation**
   - Cleanup old firmware images
   - Verify available storage space
   - Backup current running configuration
   - Log pre-loading steps and timing

3. **Image Transfer**
   - Transfer firmware image to device
   - Verify transfer integrity (hash comparison)
   - Stage image for installation
   - Log transfer results and timing

### Phase 2: Image Installation (Maintenance Window)
1. **Pre-Installation Validation**
   - Verify staged image integrity
   - Confirm rollback image availability
   - Final network state capture

2. **Installation Process**
   - Activate/install staged firmware
   - Set boot variables appropriately
   - Prepare for device reboot
   - Log installation steps and timing

3. **Reboot and Recovery**
   - Managed device reboot
   - Monitor boot process and connectivity
   - Verify successful firmware activation
   - Immediate post-reboot health check

4. **Post-Installation Validation**
   - Comprehensive network state validation
   - Compare against baseline state
   - Update inventory systems
   - Generate completion reports
   - Export metrics to InfluxDB

### Rollback Procedures
- **Automatic Rollback Triggers**: Health check failures, connectivity loss
- **Manual Rollback**: One-click rollback through AWX interface
- **Emergency Recovery**: Procedures for devices that become unreachable
- **Post-Rollback Validation**: Ensure device returns to pre-upgrade state
- **Reporting**: Document rollback events and outcomes
- **Inventory Update**: Reflect rollback in Netbox
- **Metrics Export**: Log rollback events to InfluxDB
- **Alerting**: Notify stakeholders of rollback events
- **Audit Trail**: Complete logging of rollback actions
- **Storage Management**: Ensure rollback image is retained

## Integration Requirements

### Existing System Integration
- **ITSM Integration**: Ticket creation and updates via REST API
- **Notification System**: InfluxDB/Grafana alerts and email notifications

#### Inventory System Integration
- **Bidirectional Updates**: Update inventory with firmware status changes
- **Conflict Resolution**: Handle inventory discrepancies automatically
- **Dynamic Inventory**: Use Netbox as dynamic inventory source for AWX

#### Monitoring System Integration
- **Health Data**: Pull device health metrics for pre-upgrade validation
- **Maintenance Mode**: Set devices to maintenance during upgrades
- **Alert Suppression**: Temporarily suppress monitoring alerts during maintenance
- **Post-Upgrade Alerts**: Re-enable alerts and validate monitoring post-upgrade

#### InfluxDB v2 Integration
- **Metrics Export**: Real-time upgrade progress and state metrics
- **Line Protocol**: Properly formatted InfluxDB line protocol output
- **Data Retention**: Configure appropriate retention policies
- **Tagging Strategy**: Consistent tagging for device type, site, vendor, etc.

#### Grafana Integration
- **Dashboard Provisioning**: Pre-built dashboards for different stakeholders
- **Alert Rules**: Comprehensive alerting for failures and compliance issues
- **Data Sources**: Automatic InfluxDB data source configuration

### Required Metrics and Measurements

#### InfluxDB Measurements
```
upgrade_progress:
  tags: device_id, device_type, site_location, batch_id, vendor, platform
  fields: state, progress_percent, duration_seconds, error_code

upgrade_state_transitions:
  tags: device_id, from_state, to_state, batch_id, operator_id
  fields: transition_duration_ms, automated, success, retry_count

network_validation:
  tags: device_id, validation_type, protocol
  fields: baseline_count, current_count, validation_success, convergence_time

device_compliance:
  tags: device_id, vendor, platform, site
  fields: current_firmware, target_firmware, compliant, last_upgraded

storage_management:
  tags: device_id, vendor, platform
  fields: total_space, available_space, cleanup_performed, images_removed
```

## AWX Configuration Requirements

### Job Template Structure
Create separate AWX job templates for granular control:

1. **Device Health Check**: Pre-upgrade validation and baseline capture
2. **Storage Cleanup**: Storage space validation and cleanup
3. **Image Loading**: Firmware transfer and staging
4. **Image Verification**: Hash validation and integrity checks
5. **Image Installation**: Firmware activation and boot variable setup
6. **Device Reboot**: Managed reboot with connectivity monitoring
7. **Post-Upgrade Validation**: Comprehensive network state validation
8. **Rollback Execution**: Emergency rollback procedures
9. **Compliance Audit**: Firmware compliance reporting
10. **Batch Operations**: Multi-device coordination and batch processing
11. **Metrics Export**: Export upgrade and validation metrics to InfluxDB
12. **Inventory Update**: Update Netbox with firmware and validation results

### Workflow Templates
- **Full Upgrade Workflow**: Orchestrates all phases with approval gates
- **Emergency Upgrade**: Fast-track workflow for critical security patches
- **Bulk Upgrade**: Coordinated upgrade of multiple devices
- **Validation Only**: Network state validation without upgrades
- **Rollback Workflow**: Dedicated rollback process with validation
- **Compliance Reporting**: Regular compliance audits and reporting

### Survey Specifications
Each job template must include appropriate surveys for:
- Target device selection (individual, groups, sites)
- Firmware version specification
- Maintenance window scheduling
- Approval requirements and notifications
- Rollback options and validation levels
- Batch size and concurrency controls

### Role-Based Access Control
- **Network Engineers**: Execute upgrades, view results
- **Senior Engineers**: Create/modify templates, manage workflows  
- **Network Managers**: View reports, approve changes
- **Change Approvers**: Approve/reject upgrade requests
- **Read-Only Users**: View status and reports only

## Ansible Playbook Requirements

### Required Ansible Collections
```yaml
# collections/requirements.yml
collections:
  - name: cisco.nxos
    version: ">=5.0.0"
  - name: cisco.ios  
    version: ">=5.0.0"
  - name: fortinet.fortios
    version: ">=2.0.0"
  - name: ansible.netcommon
    version: ">=5.0.0"
  - name: community.general
    version: ">=6.0.0"
```

### Vendor-Specific Role Requirements

#### Cisco NX-OS Role
- **ISSU Support**: In-Service Software Upgrade where applicable
- **EPLD Upgrades**: Handle EPLD firmware updates
- **Boot Variable Management**: Proper NXOS image activation

#### Cisco IOS-XE Role
- **Install Mode**: Handle install mode vs. traditional bundle mode
- **Boot System**: Proper boot system configuration

#### Metamako MOS Role
- **Ultra-Low Latency**: Latency-sensitive upgrade procedures
- **Custom Commands**: MOS-specific command handling
- **Timing Validation**: Latency measurement and validation
- **Metawatch/Metamux**: Validate status if equipped

#### Opengear Role
- **Console Server**: Serial port and console management during upgrades
- **Web Interface**: Automation of web-based upgrade procedures
- **Power Management**: Smart PDU upgrade coordination
- **Port Status**: Validate serial and network port states

#### FortiOS Role
- **HA Cluster**: High availability cluster upgrade coordination
- **License Management**: FortiCare license validation and activation
- **Security Policy**: Maintain security policies during upgrade
- **VPN Handling**: VPN tunnel management during reboot

### Validation Task Requirements

#### BFD State Validation
```yaml
required_bfd_checks:
  - session_states: "BFD session state verification"
  - neighbor_reachability: "BFD neighbor reachability checks"
```

#### BGP State Validation
```yaml
required_bgp_checks:
  - neighbor_states: "Established sessions count"
  - route_counts: "Received/advertised route comparison"
  - policy_validation: "Route-map and filter verification"
```

#### Interface Validation  
```yaml
required_interface_checks:
  - operational_status: "All interfaces up/down state"
  - vlan_assignments: "VLAN membership validation"
```

#### Multicast Validation
```yaml
required_multicast_checks:
  - pim_neighbors: "PIM neighbor adjacency states"
  - pim_interfaces: "PIM interface modes and states"
  - igmp_groups: "IGMP group membership validation"
  - rp_reachability: "Rendezvous Point accessibility"
  - rp_mapping: "RP mapping and Anycast RP validation"
  - anycast_rp: "Anycast RP consistency checks"
```

#### Routing Validation
```yaml
required_routing_checks:
  - static_routes: "Static route presence and reachability"
  - default_routes: "Default route and next-hop validation"
```

#### ARP Validation
```yaml
required_arp_checks:
  - arp_table: "ARP table completeness and accuracy"
  - dhcp_snooping: "DHCP snooping binding table verification"
```

## File Structure Requirements

Create the following complete project structure:

```
network-upgrade-system/
├── README.md                           # Project overview and quick start
├── PROJECT_REQUIREMENTS.md             # This requirements document
├── install/
│   ├── install-system.sh               # Base system preparation
│   ├── install-awx.sh                  # AWX installation (SQLite backend)
│   ├── install-netbox.sh               # Netbox installation (SQLite backend)
│   ├── configure-telegraf.sh           # Telegraf metrics collection setup
│   ├── configure-redis.sh              # Redis installation and configuration
│   ├── setup-ssl.sh                    # SSL certificate configuration
│   ├── create-services.sh              # systemd service creation
│   └── backup-scripts.sh               # Backup and recovery scripts
├── ansible-content/
│   ├── ansible.cfg                     # Ansible configuration
│   ├── playbooks/
│   │   ├── main-upgrade-workflow.yml   # Master workflow orchestrator
│   │   ├── image-loading.yml           # Phase 1: Image transfer and staging
│   │   ├── image-installation.yml      # Phase 2: Installation and activation
│   │   ├── health-check.yml            # Device health validation
│   │   ├── config-backup.yml           # Configuration backup
│   │   ├── storage-cleanup.yml         # Device storage management
│   │   ├── network-validation.yml      # Comprehensive network state checks
│   │   ├── compliance-audit.yml        # Firmware compliance reporting
│   │   ├── emergency-rollback.yml      # Rollback procedures
│   │   └── batch-operations.yml        # Multi-device coordination
│   ├── roles/
│   │   ├── cisco-nxos-upgrade/         # Cisco NX-OS specific procedures
│   │   │   ├── tasks/main.yml
│   │   │   ├── tasks/image-loading.yml
│   │   │   ├── tasks/image-installation.yml
│   │   │   ├── tasks/issu-procedures.yml
│   │   │   ├── tasks/validation.yml
│   │   │   ├── vars/main.yml
│   │   │   └── templates/
│   │   ├── cisco-iosxe-upgrade/        # Cisco IOS-XE specific procedures
│   │   │   ├── tasks/main.yml
│   │   │   ├── tasks/image-loading.yml
│   │   │   ├── tasks/image-installation.yml
│   │   │   ├── tasks/install-mode.yml
│   │   │   ├── tasks/validation.yml
│   │   │   ├── vars/main.yml
│   │   │   └── templates/
│   │   ├── metamako-mos-upgrade/       # Metamako MOS specific procedures
│   │   │   ├── tasks/main.yml
│   │   │   ├── tasks/image-loading.yml
│   │   │   ├── tasks/image-installation.yml
│   │   │   ├── tasks/latency-validation.yml
│   │   │   ├── vars/main.yml
│   │   │   └── templates/
│   │   ├── opengear-upgrade/           # Opengear specific procedures
│   │   │   ├── tasks/main.yml
│   │   │   ├── tasks/web-automation.yml
│   │   │   ├── tasks/serial-management.yml
│   │   │   ├── vars/main.yml
│   │   │   └── templates/
│   │   ├── fortios-upgrade/            # FortiOS specific procedures
│   │   │   ├── tasks/main.yml
│   │   │   ├── tasks/image-loading.yml
│   │   │   ├── tasks/image-installation.yml
│   │   │   ├── tasks/ha-coordination.yml
│   │   │   ├── tasks/license-validation.yml
│   │   │   ├── vars/main.yml
│   │   │   └── templates/
│   │   ├── image-validation/           # Cryptographic verification
│   │   │   ├── tasks/hash-verification.yml
│   │   │   ├── tasks/signature-validation.yml
│   │   │   └── tasks/integrity-audit.yml
│   │   ├── space-management/           # Storage validation and cleanup
│   │   │   ├── tasks/space-check.yml
│   │   │   ├── tasks/cleanup-images.yml
│   │   │   └── tasks/storage-monitoring.yml
│   │   ├── network-validation/         # Comprehensive state checks
│   │   │   ├── tasks/bgp-validation.yml
│   │   │   ├── tasks/interface-validation.yml
│   │   │   ├── tasks/routing-validation.yml
│   │   │   ├── tasks/multicast-validation.yml
│   │   │   ├── tasks/arp-validation.yml
│   │   │   └── tasks/protocol-convergence.yml
│   │   └── common/                     # Shared tasks and utilities
│   │       ├── tasks/connectivity-check.yml
│   │       ├── tasks/logging.yml
│   │       ├── tasks/error-handling.yml
│   │       └── tasks/metrics-export.yml
│   ├── inventory/
│   │   ├── group_vars/
│   │   │   ├── all.yml                 # Global variables
│   │   │   ├── cisco_nxos.yml          # NX-OS specific configurations
│   │   │   ├── cisco_iosxe.yml         # IOS-XE specific configurations
│   │   │   ├── metamako_mos.yml        # Metamako configurations
│   │   │   ├── opengear.yml            # Opengear configurations
│   │   │   └── fortios.yml             # FortiOS configurations
│   │   └── netbox_dynamic.yml          # Netbox dynamic inventory config
│   ├── collections/
│   │   └── requirements.yml            # Required Ansible collections
│   └── validation-templates/
│       ├── bfd-validation.j2           # BFD state validation templates
│       ├── bgp-validation.j2           # BGP state validation templates
│       ├── interface-validation.j2     # Interface state templates
│       ├── routing-validation.j2       # Routing validation templates
│       ├── multicast-validation.j2     # PIM/IGMP validation templates
│       └── arp-validation.j2           # ARP validation templates
├── netbox-config/
│   ├── import-scripts/
│   │   ├── import-from-csv.py          # CSV import utility
│   │   ├── sync-from-inventory.py      # External inventory sync
│   │   └── validate-import.py          # Import validation
│   └── api-integration/
│       ├── awx-dynamic-inventory.py    # AWX integration script
│       └── netbox-api-client.py        # Netbox API utilities
├── awx-config/
│   ├── job-templates/
│   │   ├── device-health-check.yml     # Health validation template
│   │   ├── storage-cleanup.yml         # Storage management template
│   │   ├── image-loading.yml           # Image loading template
│   │   ├── image-verification.yml      # Image integrity verification
│   │   ├── image-installation.yml      # Image installation template
│   │   ├── post-validation.yml         # Post-upgrade validation
│   │   ├── emergency-rollback.yml      # Rollback template
│   │   └── compliance-audit.yml        # Compliance reporting
│   ├── workflow-templates/
│   │   ├── full-upgrade-workflow.yml   # Complete upgrade orchestration
│   │   ├── emergency-upgrade.yml       # Fast-track security updates
│   │   ├── bulk-upgrade.yml            # Multiple device coordination
│   │   └── validation-workflow.yml     # Validation-only workflow
│   ├── inventories/
│   │   ├── netbox-dynamic.yml          # Dynamic inventory configuration
│   │   └── static-groups.yml           # Static device groupings
│   ├── credentials/
│   │   ├── network-ssh-keys.yml        # SSH credential configurations
│   │   ├── vendor-api-keys.yml         # Vendor API credentials
│   │   └── service-accounts.yml        # Service account credentials
│   ├── projects/
│   │   └── network-automation.yml      # SCM project configuration
│   ├── organizations/
│   │   └── network-operations.yml      # Organization and team setup
│   └── notifications/
│       ├── email-notifications.yml     # Email notification templates
│       ├── slack-integration.yml       # Slack notification setup
│       └── webhook-notifications.yml   # Webhook configurations
├── integration/
│   ├── telegraf/
│   │   ├── telegraf.conf               # Main Telegraf configuration
│   │   └── scripts/
│   │       ├── awx-metrics.py          # AWX job status metrics
│   │       ├── netbox-metrics.py       # Device compliance metrics
│   │       ├── network-state-metrics.py # BGP/routing state metrics
│   │       ├── validation-metrics.py   # Network validation results
│   │       └── storage-metrics.py      # Device storage monitoring
│   ├── influxdb/
│   │   ├── bucket-setup.sql            # InfluxDB bucket configuration
│   │   ├── retention-policies.sql      # Data retention policies
│   │   └── measurement-schemas/
│   │       ├── upgrade-progress.txt    # Upgrade tracking schema
│   │       ├── network-validation.txt  # Network state schema
│   │       ├── device-compliance.txt   # Compliance tracking schema
│   │       └── storage-management.txt  # Storage monitoring schema
│   ├── grafana/
│   │   ├── dashboards/
│   │   │   ├── executive-overview.json # High-level metrics dashboard
│   │   │   ├── operations-status.json  # Real-time operations dashboard
│   │   │   ├── network-validation.json # Network state monitoring
│   │   │   ├── vendor-specific.json    # Platform-specific metrics
│   │   │   └── compliance-tracking.json # Compliance monitoring
│   │   ├── alerts/
│   │   │   ├── upgrade-failures.yml    # Upgrade failure alerts
│   │   │   ├── validation-failures.yml # Network validation alerts
│   │   │   ├── compliance-alerts.yml   # Compliance threshold alerts
│   │   │   └── storage-alerts.yml      # Storage space alerts
│   │   └── data-sources/
│   │       └── influxdb-datasource.json # InfluxDB connection config
│   └── external-apis/
│       ├── inventory-sync.py           # External inventory integration
│       ├── monitoring-integration.py   # Monitoring system integration
│       └── itsm-integration.py         # ITSM system integration
├── scripts/
│   ├── system-health.sh                # System health monitoring
│   ├── backup-system.sh                # Complete system backup
│   ├── restore-system.sh               # System restoration
│   ├── log-rotation.sh                 # Log management
│   └── maintenance/
│       ├── daily-maintenance.sh        # Daily maintenance tasks
│       ├── weekly-reports.sh           # Weekly reporting
│       └── cleanup-old-data.sh         # Data cleanup procedures
├── tests/
│   ├── unit-tests/                     # Ansible playbook unit tests
│   ├── integration-tests/              # End-to-end integration tests
│   ├── vendor-tests/                   # Vendor-specific test cases
│   └── validation-tests/               # Network state validation tests
├── docs/
│   ├── installation-guide.md          # Complete installation instructions
│   ├── user-guide.md                  # AWX web interface usage
│   ├── administrator-guide.md         # System administration procedures
│   ├── vendor-guides/
│   │   ├── cisco-nxos-procedures.md    # NX-OS specific procedures
│   │   ├── cisco-iosxe-procedures.md   # IOS-XE specific procedures
│   │   ├── metamako-procedures.md     # Metamako specific procedures
│   │   ├── opengear-procedures.md     # Opengear specific procedures
│   │   └── fortios-procedures.md      # FortiOS specific procedures
│   ├── integration-guide.md           # External system integration
│   ├── security-guide.md              # Security procedures and validation
│   ├── troubleshooting.md             # Common issues and solutions
│   ├── backup-recovery.md             # Disaster recovery procedures
│   └── api-reference.md               # API documentation
└── examples/
    ├── sample-configurations/         # Example device configurations
    ├── test-inventories/              # Sample inventory data
    └── demo-workflows/                # Demonstration workflows
```

## Implementation Standards

### Security Standards
- **Ansible Vault**: All sensitive data encrypted with Ansible Vault
- **SSH Key Management**: Centralized SSH key storage and rotation
- **API Token Security**: Secure storage and rotation of API tokens
- **Image Integrity**: Mandatory hash verification for all firmware
- **Audit Logging**: Complete audit trail of all operations
- **Access Control**: Role-based access with principle of least privilege

### Error Handling Standards
- **Comprehensive Error Handling**: Every task must include error handling
- **Graceful Degradation**: System continues operating with partial failures
- **Automatic Retry Logic**: Configurable retry mechanisms with exponential backoff
- **Rollback Triggers**: Automatic rollback on critical failure conditions
- **Manual Intervention**: Clear procedures for manual intervention scenarios

### Logging and Monitoring Standards
- **Structured Logging**: JSON-formatted logs for easy parsing
- **Correlation IDs**: Track operations across multiple systems
- **Performance Metrics**: Timing and performance data for optimization
- **Health Metrics**: System and application health monitoring
- **Alert Integration**: Integration with existing alert management systems

### Code Quality Standards
- **Ansible Best Practices**: Follow official Ansible development guidelines
- **Idempotency**: All tasks must be idempotent and support check mode
- **Documentation**: Comprehensive inline documentation for all code
- **Testing**: Unit tests for all custom modules and comprehensive integration tests
- **Version Control**: Git-based version control with proper branching strategy

## Integration Specifications

### InfluxDB v2 Integration
- **Line Protocol**: Properly formatted metrics using InfluxDB line protocol
- **Bucket Management**: Automatic bucket creation and retention policy setup
- **Tag Strategy**: Consistent tagging strategy across all measurements
- **Batch Writing**: Efficient batch writing for high-volume metrics
- **Error Handling**: Robust error handling for metrics transmission failures

### Grafana Integration  
- **Dashboard Provisioning**: Automatic dashboard deployment via API
- **Alert Rule Management**: Programmatic alert rule creation and management
- **Data Source Configuration**: Automatic InfluxDB data source setup
- **User Management**: Integration with existing Grafana user management
- **Custom Variables**: Dashboard variables for filtering and customization

### External System Integration
- **REST API Clients**: Robust API clients for external system integration
- **Data Synchronization**: Bidirectional data sync with conflict resolution
- **Webhook Support**: Webhook endpoints for real-time notifications
- **File-Based Integration**: CSV/JSON import/export capabilities
- **Error Recovery**: Automatic recovery from integration failures

## Success Criteria

### Functional Requirements
- **Complete Installation**: System deployable in under 4 hours on fresh server
- **Vendor Support**: Full support for all 6 specified device platforms
- **Phase Separation**: Clear separation between image loading and installation
- **Security Validation**: Cryptographic verification of all firmware images
- **State Validation**: Comprehensive network state validation and comparison
- **Integration Success**: Seamless integration with existing InfluxDB v2 and Grafana

### Performance Requirements
- **Device Capacity**: Support 1000+ devices with single server
- **Concurrent Operations**: 50+ concurrent device operations
- **Response Time**: Web interface response under 2 seconds
- **Job Execution**: Upgrade jobs complete within expected timeframes
- **Metric Delivery**: Real-time metrics delivered to InfluxDB within 30 seconds

### Operational Requirements
- **Zero Development**: Implementation requires only configuration, no custom coding
- **Standard Skills**: Maintainable by staff with basic Linux and Ansible knowledge
- **Comprehensive Documentation**: Complete user and administrator documentation
- **Testing Suite**: Comprehensive test suite for validation
- **Backup/Recovery**: Complete backup and disaster recovery procedures

## Deliverable Quality Standards

### Code Quality
- **Ansible Lint**: All playbooks must pass ansible-lint validation
- **YAML Lint**: All YAML files must pass yamllint validation
- **Shell Check**: All shell scripts must pass shellcheck validation
- **Documentation**: Every component must include comprehensive documentation
- **Examples**: Working examples for all major use cases

### Security Requirements
- **No Hardcoded Secrets**: All secrets managed through Ansible Vault or external systems
- **SSH RSA Keys**: Use SSH RSA keys for all device access
- **Input Validation**: All user inputs validated and sanitized
- **Secure Defaults**: Secure configuration defaults for all components
- **Regular Updates**: Procedures for keeping all components updated
- **Vulnerability Management**: Process for handling security vulnerabilities

Build this system as a complete, production-ready solution that can be deployed immediately and operated with minimal technical expertise beyond standard Linux administration and basic Ansible knowledge.