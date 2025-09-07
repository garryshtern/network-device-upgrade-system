# Network Device Upgrade Management System - Project Requirements

> **📋 Project Requirements Document**  
> Last Updated: September 7, 2025  
> This document defines the complete requirements for the network device upgrade management system. For implementation status and completion analysis, see [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) and [TESTING_COMPLIANCE_ANALYSIS.md](TESTING_COMPLIANCE_ANALYSIS.md).

## Project Overview

Build a complete AWX-based network device upgrade management system for 1000+ heterogeneous network devices. The system must automate firmware upgrades across multiple vendor platforms while providing comprehensive reporting, security validation, and integration with existing monitoring infrastructure.

## System Architecture Requirements

### Single Server Deployment
- **Unprivileged Deployment**: All services run as unprivileged user with systemd --user services
- **Deployment Strategy**: Native installation with systemd user services (non-containerized)
- **Minimal Coding**: Configuration only, no custom development
- **Maximum Simplicity**: Easy to maintain by staff with basic Linux/Ansible skills
- **Ansible-Based**: All automation via Ansible playbooks and AWX job templates
- **Database Backend**: SQLite only (no PostgreSQL clusters)
- **Service Management**: Use systemd user services for unprivileged deployment
- **High Availability**: Not required, but ensure graceful recovery from failures


### Core Components
1. **AWX**: Native Django installation with uWSGI and systemd services (port 8443)
2. **NetBox**: Device inventory and IPAM management (pre-existing)
3. **Telegraf**: User service for metrics collection to existing InfluxDB v2
4. **Redis**: User service for job queuing and caching
5. **Nginx**: User service for SSL termination and reverse proxy
6. **File Storage**: User home directory for configurations and firmware

## Supported Device Platforms

Build support for the following network device platforms:

### 1. Cisco NX-OS (Nexus Switches)
- **Collection**: `cisco.nxos`
- **Features**: image staging validation, EPLD upgrades, ISSU support
- **Validation**: interface & optics states, BGP, PIM, routing tables, ARP, IGMP, enhanced BFD

### 2. Cisco IOS-XE (Enterprise Routers/Switches)
- **Collection**: `cisco.ios`
- **Features**: Install mode vs. bundle mode handling, boot system management
- **Validation**: interface & optics states, BGP, routing tables, ARP, IPSec tunnels, BFD sessions

### 3. Metamako MOS (Ultra-Low Latency Switches)
- **Collection**: `ansible.netcommon` with custom CLI modules
- **Features**: Custom MOS command handling, latency-sensitive operations, post-upgrade application management
- **Version Support**: MOS firmware versions 0.39.x (current production: 0.39.11)
- **Applications**: MetaWatch 4.2.0, MetaMux 3.8.0 (mutually exclusive - only one can be enabled)
- **Post-Upgrade Requirements**: Applications must be installed after MOS upgrade completion
- **Validation**: Interface states, metawatch status, metamux status (if equipped)

### 4. Opengear (Console Servers/Smart PDUs)
- **Collection**: `ansible.netcommon`
- **Features**: Web interface automation, serial port management
- **Models**: OM2200, CM8100, CM7100, IM7200
- **Validation**: Port status, connectivity, power management

### 5. FortiOS (Fortinet Firewalls)
- **Collection**: `fortinet.fortios`
- **Features**: HA cluster coordination, license validation, VDOM handling
- **Validation**: Security policies, routing, interface states, VPN tunnel management

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
- **Dashboard Provisioning**: Automated dashboard deployment with environment-specific customization
- **Alert Rules**: Comprehensive alerting configuration for failures and compliance issues  
- **Data Sources**: Automatic InfluxDB v2 data source configuration with Flux queries
- **Multi-Environment Support**: Development, staging, and production deployment automation
- **Validation Framework**: Comprehensive deployment validation and health monitoring

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
- **Custom Commands**: MOS-specific command handling for 0.39.x firmware
- **Application Management**: Post-upgrade installation of MetaWatch 4.2.0 or MetaMux 3.8.0
- **Mutual Exclusivity**: Ensure only one application (MetaWatch/MetaMux) is active at a time
- **Timing Validation**: Latency measurement and validation
- **Application State Management**: Enable/disable applications safely during transitions

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

Create the following simplified, unprivileged deployment project structure optimized for configuration-only deployment:

```
network-upgrade-system/
├── README.md                           # Project overview and quick start
├── PROJECT_REQUIREMENTS.md             # This requirements document
│
├── install/                           # Native service installation
│   ├── setup-system.sh                # System preparation and dependencies
│   ├── setup-awx.sh                   # AWX native installation
│   ├── setup-netbox.sh                # NetBox native installation
│   ├── configure-redis.sh             # Redis configuration optimization
│   ├── configure-telegraf.sh         # Telegraf metrics collection setup
│   ├── create-services.sh            # Service orchestration and startup
│   └── configs/                       # Service configuration templates
│       ├── nginx/                    # Nginx virtual host configs
│       │   ├── awx.conf              # AWX reverse proxy config
│       │   └── netbox.conf           # NetBox reverse proxy config
│       ├── systemd/                  # Systemd service templates
│       │   ├── awx-web.service       # AWX web service
│       │   ├── awx-task.service      # AWX task service
│       │   └── netbox.service        # NetBox service
│       └── ssl/                      # SSL certificate configs
│   ├── backup-scripts.sh              # Backup and recovery scripts
│   └── setup-ssl.sh                   # SSL certificate configuration
│
├── ansible-content/                   # **PRIMARY FOCUS** - Pure Ansible
│   ├── ansible.cfg                    # Ansible configuration
│   ├── collections/
│   │   └── requirements.yml           # Required Ansible collections
│   ├── playbooks/                     # **CORE DELIVERABLE**
│   │   ├── main-upgrade-workflow.yml  # Master workflow orchestrator
│   │   ├── image-loading.yml          # Phase 1: Image transfer and staging
│   │   ├── image-installation.yml     # Phase 2: Installation and activation
│   │   ├── health-check.yml           # Device health validation
│   │   ├── config-backup.yml          # Configuration backup
│   │   ├── storage-cleanup.yml        # Device storage management
│   │   ├── network-validation.yml     # Comprehensive network state checks
│   │   ├── compliance-audit.yml       # Firmware compliance reporting
│   │   ├── emergency-rollback.yml     # Rollback procedures
│   │   └── batch-operations.yml       # Multi-device coordination
│   ├── roles/                         # **VENDOR-SPECIFIC LOGIC**
│   │   ├── cisco-nxos-upgrade/        # Cisco NX-OS specific procedures
│   │   │   ├── tasks/main.yml
│   │   │   ├── tasks/image-loading.yml
│   │   │   ├── tasks/image-installation.yml
│   │   │   ├── tasks/issu-procedures.yml
│   │   │   ├── tasks/validation.yml
│   │   │   ├── vars/main.yml
│   │   │   └── templates/
│   │   ├── cisco-iosxe-upgrade/       # Cisco IOS-XE specific procedures
│   │   │   ├── tasks/main.yml
│   │   │   ├── tasks/image-loading.yml
│   │   │   ├── tasks/image-installation.yml
│   │   │   ├── tasks/install-mode.yml
│   │   │   ├── tasks/validation.yml
│   │   │   ├── vars/main.yml
│   │   │   └── templates/
│   │   ├── metamako-mos-upgrade/      # Metamako MOS specific procedures
│   │   │   ├── tasks/main.yml
│   │   │   ├── tasks/image-loading.yml
│   │   │   ├── tasks/image-installation.yml
│   │   │   ├── tasks/latency-validation.yml
│   │   │   ├── vars/main.yml
│   │   │   └── templates/
│   │   ├── opengear-upgrade/          # Opengear specific procedures
│   │   │   ├── tasks/main.yml
│   │   │   ├── tasks/web-automation.yml
│   │   │   ├── tasks/serial-management.yml
│   │   │   ├── vars/main.yml
│   │   │   └── templates/
│   │   ├── fortios-upgrade/           # FortiOS specific procedures
│   │   │   ├── tasks/main.yml
│   │   │   ├── tasks/image-loading.yml
│   │   │   ├── tasks/image-installation.yml
│   │   │   ├── tasks/ha-coordination.yml
│   │   │   ├── tasks/license-validation.yml
│   │   │   ├── vars/main.yml
│   │   │   └── templates/
│   │   ├── image-validation/          # Cryptographic verification
│   │   │   ├── tasks/hash-verification.yml
│   │   │   ├── tasks/signature-validation.yml
│   │   │   └── tasks/integrity-audit.yml
│   │   ├── space-management/          # Storage validation and cleanup
│   │   │   ├── tasks/space-check.yml
│   │   │   ├── tasks/cleanup-images.yml
│   │   │   └── tasks/storage-monitoring.yml
│   │   ├── network-validation/        # Comprehensive state checks
│   │   │   ├── tasks/bgp-validation.yml
│   │   │   ├── tasks/interface-validation.yml
│   │   │   ├── tasks/routing-validation.yml
│   │   │   ├── tasks/multicast-validation.yml
│   │   │   ├── tasks/arp-validation.yml
│   │   │   └── tasks/protocol-convergence.yml
│   │   └── common/                    # Shared tasks and utilities
│   │       ├── tasks/connectivity-check.yml
│   │       ├── tasks/logging.yml
│   │       ├── tasks/error-handling.yml
│   │       └── tasks/metrics-export.yml
│   ├── inventory/
│   │   ├── group_vars/
│   │   │   ├── all.yml                # Global variables
│   │   │   ├── cisco_nxos.yml         # NX-OS specific configurations
│   │   │   ├── cisco_iosxe.yml        # IOS-XE specific configurations
│   │   │   ├── metamako_mos.yml       # Metamako configurations
│   │   │   ├── opengear.yml           # Opengear configurations
│   │   │   └── fortios.yml            # FortiOS configurations
│   │   └── netbox_dynamic.yml         # NetBox dynamic inventory config
│   └── validation-templates/
│       ├── bfd-validation.j2          # BFD state validation templates
│       ├── bgp-validation.j2          # BGP state validation templates
│       ├── interface-validation.j2    # Interface state templates
│       ├── routing-validation.j2      # Routing validation templates
│       ├── multicast-validation.j2    # PIM/IGMP validation templates
│       └── arp-validation.j2          # ARP validation templates
│
├── awx-config/                        # AWX Configuration (YAML only)
│   ├── job-templates/
│   │   ├── device-health-check.yml    # Health validation template
│   │   ├── storage-cleanup.yml        # Storage management template
│   │   ├── image-loading.yml          # Image loading template
│   │   ├── image-verification.yml     # Image integrity verification
│   │   ├── image-installation.yml     # Image installation template
│   │   ├── post-validation.yml        # Post-upgrade validation
│   │   ├── emergency-rollback.yml     # Rollback template
│   │   └── compliance-audit.yml       # Compliance reporting
│   ├── workflow-templates/
│   │   ├── full-upgrade-workflow.yml  # Complete upgrade orchestration
│   │   ├── emergency-upgrade.yml      # Fast-track security updates
│   │   ├── bulk-upgrade.yml           # Multiple device coordination
│   │   └── validation-workflow.yml    # Validation-only workflow
│   ├── inventories/
│   │   ├── netbox-dynamic.yml         # NetBox dynamic inventory configuration
│   │   └── static-groups.yml          # Static device groupings
│   ├── credentials/
│   │   ├── network-ssh-keys.yml       # SSH credential configurations
│   │   ├── vendor-api-keys.yml        # Vendor API credentials
│   │   └── service-accounts.yml       # Service account credentials
│   ├── projects/
│   │   └── network-automation.yml     # SCM project configuration
│   ├── organizations/
│   │   └── network-operations.yml     # Organization and team setup
│   └── notifications/
│       ├── email-notifications.yml    # Email notification templates
│       ├── slack-integration.yml      # Slack notification setup
│       └── webhook-notifications.yml  # Webhook configurations
│
├── integration/                       # External system integration
│   ├── netbox/                        # NetBox integration (existing deployment)
│   │   ├── dynamic-inventory.py       # AWX dynamic inventory script
│   │   └── sync-scripts/              # Data synchronization utilities
│   │       ├── device-import.sh       # Device data import
│   │       └── firmware-sync.sh       # Firmware version sync
│   ├── grafana/                        # ✅ COMPLETE - Dashboard automation system
│   │   ├── dashboards/                 # ✅ Three comprehensive dashboards implemented
│   │   │   ├── network-upgrade-overview.json    # ✅ Executive dashboard with system metrics
│   │   │   ├── platform-specific-metrics.json   # ✅ Platform-focused technical monitoring
│   │   │   └── real-time-operations.json        # ✅ Live operational dashboard (15s refresh)
│   │   ├── config-templates/           # ✅ Environment-specific configuration templates
│   │   │   ├── development.env         # ✅ Development environment configuration
│   │   │   ├── staging.env             # ✅ Staging environment configuration  
│   │   │   └── production.env          # ✅ Production environment configuration
│   │   ├── provision-dashboards.sh    # ✅ Main automated provisioning script
│   │   ├── deploy-to-environment.sh    # ✅ Environment-specific deployment automation
│   │   ├── validate-deployment.sh      # ✅ Comprehensive deployment validation
│   │   ├── README.md                   # ✅ Complete integration documentation
│   │   └── DEPLOYMENT_GUIDE.md         # ✅ Comprehensive deployment procedures
│   ├── influxdb/
│   │   ├── bucket-setup.flux          # InfluxDB bucket configuration
│   │   ├── retention-policies.flux    # Data retention policies
│   │   └── measurement-schemas/
│   │       ├── upgrade-progress.txt   # Upgrade tracking schema
│   │       ├── network-validation.txt # Network state schema
│   │       ├── device-compliance.txt  # Compliance tracking schema
│   │       └── storage-management.txt # Storage monitoring schema
│   └── scripts/                       # **MINIMAL** utility scripts
│       ├── metrics-export.sh          # Basic metrics export
│       └── health-check.sh            # System health monitoring
│
├── configs/                           # Configuration templates and examples
│   ├── system/                        # System configuration files
│   │   ├── environment.template       # Environment variables template
│   │   └── firewall-rules.sh         # Firewall configuration
│   ├── systemd/                      # Systemd service configurations
│   │   ├── service-templates/        # Service unit templates
│   │   └── environment/              # Environment configurations
│   └── examples/                      # Example configurations
│       ├── sample-inventory.yml      # Sample device inventory
│       ├── sample-credentials.yml    # Sample credential configuration
│       └── sample-workflow.yml       # Sample workflow configuration
│
├── tests/                            # **MANDATORY COMPREHENSIVE TESTING**
│   ├── run-all-tests.sh              # **MASTER TEST RUNNER** - Executes all test categories
│   ├── unit-tests/                   # Unit testing framework
│   │   ├── variable-validation.yml   # Variable constraint and type testing
│   │   ├── template-rendering.yml    # Jinja2 template validation
│   │   ├── workflow-logic.yml        # Decision path and conditional testing
│   │   ├── error-handling.yml        # Error condition and recovery testing
│   │   └── validate_scenario.yml     # Shared validation task file
│   ├── vendor-tests/                 # **PLATFORM-SPECIFIC COMPREHENSIVE TESTING**
│   │   ├── cisco-nxos-tests.yml      # NX-OS: ISSU, EPLD, Enhanced BFD, IGMP testing
│   │   ├── cisco-iosxe-tests.yml     # IOS-XE: Install/Bundle mode, IPSec, Optics testing
│   │   ├── fortios-tests.yml         # FortiOS: Multi-step upgrades, HA, VDOM testing
│   │   ├── opengear-tests.yml        # Opengear: API vs SSH, Console vs PDU testing
│   │   ├── metamako-tests.yml        # Metamako: MetaWatch/MetaMux, Ultra-low latency testing
│   │   ├── validate_nxos_scenario.yml     # NX-OS scenario validation tasks
│   │   ├── validate_iosxe_scenario.yml    # IOS-XE scenario validation tasks
│   │   ├── validate_fortios_scenario.yml  # FortiOS scenario validation tasks
│   │   ├── validate_opengear_scenario.yml # Opengear scenario validation tasks
│   │   └── validate_metamako_scenario.yml # Metamako scenario validation tasks
│   ├── integration-tests/            # End-to-end integration testing
│   │   ├── check-mode-tests.yml      # Check mode workflow validation
│   │   ├── cross-platform-tests.yml # All 5 platform validation
│   │   ├── workflow-orchestration.yml # End-to-end workflow testing
│   │   ├── state-validation-tests.yml # Network state comparison testing
│   │   └── rollback-scenario-tests.yml # Emergency rollback testing
│   ├── performance-tests/            # Performance and load testing
│   │   ├── run-performance-tests.sh  # Performance test execution
│   │   ├── memory-profiler.py        # Memory usage validation
│   │   ├── execution-timing.yml      # Performance benchmarking
│   │   ├── concurrent-operations.yml # Multi-device testing
│   │   └── scalability-tests.yml     # 1000+ device simulation
│   ├── security-tests/               # Security and compliance testing
│   │   ├── hash-verification-tests.yml # Cryptographic integrity testing
│   │   ├── vault-security-tests.yml  # Ansible Vault testing
│   │   ├── access-control-tests.yml  # Role-based permission testing
│   │   └── audit-trail-tests.yml     # Logging and audit validation
│   ├── mock-inventories/             # **REALISTIC** Mock device inventories for testing
│   │   ├── all-platforms.yml         # Complete mock inventory (all 5 platforms with realistic configs)
│   │   │                             # - NX-OS: 3 devices (ISSU/non-ISSU, EPLD scenarios)
│   │   │                             # - IOS-XE: 3 devices (install/bundle mode scenarios)  
│   │   │                             # - FortiOS: 4 devices (HA, standalone, multi-step upgrades)
│   │   │                             # - Opengear: 4 devices (API vs SSH, console vs PDU)
│   │   │                             # - Metamako: 4 devices (all metawatch/metamux combinations)
│   │   ├── single-platform.yml       # Single platform testing
│   │   ├── cisco-nxos-mock.yml       # NX-OS realistic mock devices with EPLD
│   │   ├── cisco-iosxe-mock.yml      # IOS-XE realistic mock devices with install/bundle
│   │   ├── fortios-mock.yml          # FortiOS realistic mock devices with multi-step
│   │   ├── opengear-mock.yml         # Opengear realistic mock devices with API/SSH
│   │   └── metamako-mock.yml         # Metamako realistic mock devices with 2.x versions
│   ├── validation-scripts/           # Validation and syntax checking
│   │   ├── yaml-validator.py         # YAML/JSON structure validation
│   │   ├── run-yaml-tests.sh         # YAML validation test runner
│   │   ├── ansible-syntax-check.sh   # Ansible syntax validation
│   │   └── lint-validation.sh        # Code quality validation
│   ├── ci-cd/                        # CI/CD pipeline testing
│   │   ├── github-actions/           # GitHub Actions workflows
│   │   │   ├── test-pipeline.yml     # Comprehensive test pipeline
│   │   │   ├── syntax-validation.yml # Syntax validation workflow
│   │   │   └── security-testing.yml  # Security validation workflow
│   │   ├── gitlab-ci/                # GitLab CI configurations
│   │   └── jenkins/                  # Jenkins pipeline configurations
│   ├── molecule-tests/               # Molecule container-based testing
│   │   ├── molecule.yml              # Molecule configuration
│   │   ├── requirements.yml          # Container testing requirements
│   │   └── scenarios/                # Test scenarios for containers
│   ├── test-data/                    # Sample data for validation testing
│   │   ├── sample-configurations/    # Mock device configurations
│   │   ├── firmware-samples/         # Sample firmware metadata
│   │   └── network-states/           # Sample network state data
│   ├── TEST_FRAMEWORK_GUIDE.md       # **COMPREHENSIVE TESTING DOCUMENTATION**
│   └── test-reports/                 # Automated test reporting
│       ├── coverage-reports/         # Test coverage analysis
│       ├── performance-reports/      # Performance benchmarking results
│       └── security-reports/         # Security validation results
│
├── docs/                             # Documentation
│   ├── installation-guide.md         # Container installation guide
│   ├── user-guide.md                 # AWX web interface usage
│   ├── administrator-guide.md        # System administration procedures
│   ├── vendor-guides/
│   │   ├── cisco-nxos-procedures.md  # NX-OS specific procedures
│   │   ├── cisco-iosxe-procedures.md # IOS-XE specific procedures
│   │   ├── metamako-procedures.md    # Metamako specific procedures
│   │   ├── opengear-procedures.md    # Opengear specific procedures
│   │   └── fortios-procedures.md     # FortiOS specific procedures
│   ├── integration-guide.md          # External system integration
│   ├── security-guide.md             # Security procedures and validation
│   ├── troubleshooting.md            # Common issues and solutions
│   ├── backup-recovery.md            # Disaster recovery procedures
│   └── api-reference.md              # API documentation
│
└── examples/                         # Working examples and demos
    ├── sample-configurations/        # Example device configurations
    ├── demo-workflows/               # Demonstration workflows
    └── test-data/                    # Sample test data for validation
```

## Comprehensive Testing Requirements

### **MANDATORY TESTING FRAMEWORK**
The project **MUST** include comprehensive tests that validate ALL functionality and complete without warnings and/or errors. Testing is not optional - it is a core requirement for production deployment.

#### **Test Coverage Requirements**
- **100% Functionality Coverage**: Every playbook, role, task, and template must be tested
- **Zero Error Tolerance**: All tests must complete successfully with no errors or warnings
- **Comprehensive Validation**: Tests must validate syntax, logic, variable scoping, and integration points
- **Mock Environment Testing**: Full testing capability without requiring physical devices
- **Platform-Specific Testing**: All 5 supported platforms must have dedicated comprehensive test suites
- **Realistic Mock Inventories**: Platform-specific mock devices with accurate configurations and scenarios
- **Automated Execution**: All tests must be executable through automated CI/CD pipelines

#### **Required Test Categories**

##### **1. Syntax and Structure Validation**
```bash
# All YAML files must pass syntax validation
find . -name "*.yml" -exec python -c "import yaml; yaml.safe_load(open('{}').read())" \;

# All Ansible playbooks must pass syntax check
ansible-playbook --syntax-check playbooks/*.yml

# All YAML files must pass yamllint validation  
yamllint ansible-content/ awx-config/ tests/
```

##### **2. Unit Testing Framework**
- **Variable Validation**: Test all variable constraints and type checking
- **Template Rendering**: Validate all Jinja2 templates render correctly
- **Workflow Logic**: Test decision paths and conditional logic
- **Error Handling**: Validate error conditions and recovery procedures
- **Mock Inventory Testing**: Complete testing with simulated device inventories

##### **3. Integration Testing Framework**
- **Check Mode Testing**: Full workflow validation using `--check --diff` modes
- **Cross-Platform Testing**: Validate all 5 supported device platforms
- **Workflow Orchestration**: End-to-end workflow testing with mock devices
- **State Validation**: Network state comparison and validation testing
- **Rollback Procedures**: Emergency rollback scenario testing

##### **3a. Platform-Specific Testing Framework - MANDATORY**
**All 5 supported platforms MUST have comprehensive, realistic test coverage:**

###### **Cisco NX-OS Testing Requirements**
- **ISSU Support Testing**: In-Service Software Upgrade validation for capable devices
- **EPLD Upgrade Testing**: Embedded Programmable Logic Device upgrade scenarios
- **Multiple EPLD Images**: Support for n9000-epld.img and n9000-module-epld.img
- **EPLD Version Tracking**: current_epld_version → target_epld_version progression
- **Enhanced BFD Validation**: BFD session state and statistics validation
- **IGMP Group Testing**: IGMP group membership and version validation
- **NXAPI Support**: API-enabled vs CLI-only device differentiation
- **Mock Devices Required**: Minimum 3 NX-OS devices covering ISSU/non-ISSU and EPLD scenarios

###### **Cisco IOS-XE Testing Requirements**
- **Install Mode Detection**: Automatic detection of install mode vs bundle mode capability
- **Boot System Management**: Proper boot system configuration validation
- **IPSec Tunnel Validation**: IPSec tunnel state and connectivity testing
- **Optics Validation**: SFP/QSFP diagnostics and status checking
- **Install vs Bundle Scenarios**: Test both upgrade methods comprehensively
- **Mock Devices Required**: Minimum 3 IOS-XE devices covering install/bundle mode scenarios

###### **FortiOS Testing Requirements**
- **Multi-Step Upgrade Validation**: MANDATORY testing of multi-version upgrade paths
- **HA Cluster Coordination**: Primary/Secondary firewall upgrade coordination
- **VDOM Handling**: Virtual Domain management during upgrades
- **Security Policy Preservation**: Validate security policies maintain during upgrade
- **VPN Tunnel Management**: VPN connectivity preservation testing
- **License Validation**: FortiCare license verification and activation
- **Upgrade Path Testing**: Test complex paths like 6.4.8 → 6.4.14 → 7.0.12 → 7.2.4
- **Mock Devices Required**: Minimum 4 FortiOS devices covering HA, standalone, multi-step scenarios

###### **Opengear Testing Requirements**
- **API vs SSH Differentiation**: MANDATORY testing of both modern API and legacy SSH methods
- **Web Interface Automation**: Modern devices (IM7200, CM8100) with HTTPS API
- **Legacy CLI Support**: Older devices (OM2200, CM7100) with SSH CLI automation
- **Console Server vs PDU**: Different device types with appropriate upgrade methods
- **Connection Method Validation**: ansible_connection: local vs ssh differentiation
- **Version-Specific Methods**: API-capable (4.8+) vs Legacy (3.x) firmware handling
- **Mock Devices Required**: Minimum 4 Opengear devices covering API/SSH and console/PDU types

###### **Metamako MOS Testing Requirements**
- **Ultra-Low Latency Handling**: Latency-sensitive upgrade procedures for critical devices
- **Version Testing**: MOS upgrade scenarios from 0.39.1/0.39.3/0.39.5 to 0.39.11
- **MetaWatch Support Testing**: MetaWatch 4.2.0 installation and management post-upgrade
- **MetaMux Support Testing**: MetaMux 3.8.0 installation and management post-upgrade
- **Application Mutual Exclusivity**: Validate only one application (MetaWatch/MetaMux) can be active
- **Post-Upgrade Application Management**: Test application installation after MOS upgrade completion
- **Application Switching**: Test transitioning between MetaWatch and MetaMux applications
- **Latency Threshold Validation**: Test various thresholds (25ns, 50ns, 100ns, 500ns)
- **Performance Impact**: Validate upgrade procedures don't affect latency-critical operations
- **Mock Devices Required**: Minimum 4 Metamako devices covering all application combinations

##### **4. Performance and Load Testing**
- **Memory Profiling**: Memory usage validation during large-scale operations
- **Execution Timing**: Performance benchmarking and optimization validation
- **Concurrent Operations**: Multi-device operation testing and resource management
- **Scalability Testing**: 1000+ device simulation and performance validation

##### **5. Security and Compliance Testing**
- **Hash Verification**: Cryptographic integrity testing
- **Vault Security**: Ansible Vault encryption/decryption testing
- **Access Control**: Role-based permission validation
- **Audit Trail**: Logging and audit trail validation

#### **CI/CD Pipeline Requirements**

##### **Mandatory Pipeline Components**
The CI/CD pipeline **MUST** include execution of ALL tests and cannot proceed with deployment unless all tests pass:

```yaml
# Required CI/CD Pipeline Stages
stages:
  - syntax-validation      # YAML/Ansible syntax checks
  - unit-testing          # Variable validation, template testing
  - integration-testing   # Check mode and workflow testing  
  - performance-testing   # Memory and execution profiling
  - security-testing      # Hash verification and vault testing
  - comprehensive-validation # Full test suite execution
  - deployment-approval   # Manual approval gate (production only)
  - deployment           # Automated deployment (only after all tests pass)
```

##### **Test Execution Standards**
- **Pre-Commit Hooks**: Syntax validation before code commits
- **Automated Testing**: Full test suite execution on every pull request
- **Quality Gates**: No code merges without 100% test pass rate
- **Performance Regression**: Automated performance regression detection
- **Documentation Updates**: Tests must validate documentation accuracy

##### **Test Environment Requirements**
- **Mock Device Inventories**: Comprehensive mock inventories for all platforms
- **Container-Based Testing**: Isolated test environments using containers
- **Parallel Execution**: Tests must support parallel execution for efficiency
- **Cross-Platform Support**: Tests must run on Linux, macOS, and Windows
- **Resource Monitoring**: Memory and CPU usage monitoring during tests

##### **Mock Inventory Specifications - MANDATORY REALISTIC CONFIGURATIONS**

**All mock inventories MUST include realistic, platform-specific configurations:**

```yaml
# REQUIRED Mock Device Specifications

cisco_nxos: # Minimum 3 devices
  nxos-switch-01: # ISSU + EPLD Required
    platform_type: cisco_nxos
    device_model: "N9K-C93180YC-EX"
    firmware_version: "9.3.10" → target_version: "10.1.2"
    issu_capable: true
    epld_upgrade_required: true
    current_epld_version: "1.2.3" → target_epld_version: "1.3.1"
    epld_images: ["n9000-epld.10.1.2.img"]
    nxapi_enabled: true

  nxos-switch-02: # Non-ISSU, No EPLD
    device_model: "N9K-C9336C-FX2"
    issu_capable: false
    epld_upgrade_required: false
    nxapi_enabled: false

  nxos-switch-03: # ISSU + Multiple EPLD Images
    device_model: "N9K-C93240YC-FX2"
    issu_capable: true
    epld_upgrade_required: true
    epld_images: ["n9000-epld.10.2.3.img", "n9000-module-epld.10.2.3.img"]

cisco_iosxe: # Minimum 3 devices  
  iosxe-router-01: # Install Mode Capable
    device_model: "ISR4431"
    install_mode: true
    boot_mode: "install"
    
  iosxe-switch-01: # Bundle Mode Only
    device_model: "C9300-48U"  
    install_mode: false
    boot_mode: "bundle"

fortios: # Minimum 4 devices
  fortigate-fw-01: # HA Primary with Multi-Step
    firmware_version: "6.4.8" → target_version: "7.2.4"
    ha_enabled: true, ha_role: "primary"
    multi_step_upgrade_required: true
    upgrade_path: ["6.4.14", "7.0.12", "7.2.4"]
    vdom_enabled: true, vdom_count: 3

  fortigate-fw-02: # HA Secondary with Multi-Step
    ha_role: "secondary"
    # Same multi-step path as primary

  fortigate-fw-standalone: # Standalone Multi-Step
    ha_enabled: false
    upgrade_path: ["7.0.12", "7.2.4"]

  fortigate-fw-direct: # Direct Upgrade (Single Step)
    firmware_version: "7.2.1" → target_version: "7.2.4"
    multi_step_upgrade_required: false
    upgrade_path: ["7.2.4"]

opengear: # Minimum 4 devices
  opengear-im7200-api: # Modern API Device
    device_model: "IM7200-2-DAC"
    ansible_connection: local
    api_capable: true
    upgrade_method: "web_api"
    firmware_version: "4.8.2" # API-capable version

  opengear-cm8100-api: # Modern API Console Server
    device_model: "CM8100"
    api_capable: true, cli_legacy_support: true

  opengear-om2200-legacy: # Legacy SSH PDU
    device_model: "OM2200"
    ansible_connection: ssh
    api_capable: false
    upgrade_method: "ssh_cli"
    firmware_version: "3.14.2" # Legacy version

  opengear-cm7100-legacy: # Legacy SSH Console Server
    device_model: "CM7100"
    api_capable: false

metamako: # Minimum 4 devices
  metamako-mc48-full: # MetaWatch + MetaMux
    device_model: "MetaConnect-48"
    firmware_version: "2.14.3" # Realistic 2.x version
    metawatch_enabled: true, metawatch_version: "1.2.1"
    metamux_enabled: true, metamux_version: "2.1.4"
    latency_threshold_ns: 50, ultra_low_latency: true

  metamako-mc24-watch-only: # MetaWatch Only
    device_model: "MetaConnect-24"
    metawatch_enabled: true, metawatch_version: "1.1.8"
    metamux_enabled: false, metamux_version: null
    latency_threshold_ns: 100

  metamako-mc12-basic: # Neither MetaWatch nor MetaMux
    device_model: "MetaConnect-12"
    metawatch_enabled: false, metamux_enabled: false
    latency_threshold_ns: 500, ultra_low_latency: false

  metamako-mc64-enterprise: # Both + Ultra Low Latency
    device_model: "MetaConnect-64"
    metawatch_enabled: true, metamux_enabled: true
    latency_threshold_ns: 25, ultra_low_latency: true
```

#### **Test Documentation Standards**
- **Test Framework Guide**: Complete documentation of testing procedures
- **Test Execution Instructions**: Step-by-step test execution guidelines
- **Troubleshooting Guide**: Common test failure resolution procedures
- **Performance Benchmarks**: Documented performance expectations and limits

#### **Quality Assurance Standards**
- **Zero-Warning Policy**: No warnings allowed in test output
- **Error-Free Execution**: All tests must complete without errors
- **Consistent Results**: Tests must produce consistent, repeatable results
- **Clear Failure Messages**: Test failures must provide actionable error messages
- **Automated Reporting**: Test results must be automatically collected and reported

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
- **Vendor Support**: Full support for all 5 specified device platforms
- **Phase Separation**: Clear separation between image loading and installation
- **Security Validation**: Cryptographic verification of all firmware images
- **State Validation**: Comprehensive network state validation and comparison
- **Integration Success**: Seamless integration with existing InfluxDB v2 and Grafana
- **Dashboard Automation**: Complete Grafana dashboard provisioning with multi-environment support
- **Monitoring Visualization**: Real-time operational dashboards with comprehensive metrics

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
- **Comprehensive Testing Suite**: **MANDATORY** - All tests must pass without errors or warnings
- **CI/CD Integration**: Automated testing pipeline with quality gates
- **Backup/Recovery**: Complete backup and disaster recovery procedures

### Testing and Quality Assurance Requirements
- **100% Test Coverage**: Every component must be tested and validated
- **Zero-Error Policy**: All tests must complete successfully without any errors
- **Zero-Warning Policy**: All tests must complete without generating warnings
- **Mock Environment Testing**: Full functionality testing without physical devices
- **Platform-Specific Testing**: MANDATORY comprehensive testing for all 5 supported platforms
- **Realistic Mock Inventories**: Platform-accurate mock devices with proper configurations
- **EPLD Testing**: NX-OS EPLD upgrade scenarios with multiple image support
- **Multi-Step Upgrades**: FortiOS multi-version upgrade path testing
- **API/SSH Differentiation**: Opengear modern API vs legacy SSH testing
- **MetaWatch/MetaMux**: Metamako application testing with MetaWatch 4.2.0 and MetaMux 3.8.0 versions
- **Automated CI/CD Testing**: All tests must be integrated into continuous integration pipeline
- **Performance Validation**: Memory usage and execution time validation
- **Security Testing**: Cryptographic verification and access control testing
- **Cross-Platform Validation**: Complete validation across all 5 supported device platforms

## Deliverable Quality Standards

### Code Quality
- **Ansible Lint**: All playbooks must pass ansible-lint validation
- **YAML Lint**: All YAML files must pass yamllint validation
- **Shell Check**: All shell scripts must pass shellcheck validation
- **Documentation**: Every component must include comprehensive documentation
- **Examples**: Working examples for all major use cases

### **MANDATORY TESTING STANDARDS**
- **Comprehensive Test Suite**: **REQUIRED** - Complete testing framework covering all functionality
- **Zero-Error Requirement**: All tests must execute successfully without any errors
- **Zero-Warning Requirement**: All tests must complete without generating any warnings
- **CI/CD Integration**: All tests must be integrated into automated CI/CD pipelines
- **Mock Environment Testing**: Complete testing capability without physical devices
- **Test Documentation**: Comprehensive testing documentation and execution guides
- **Automated Test Execution**: Tests must be executable through automated scripts
- **Performance Benchmarking**: Memory usage and execution time validation
- **Cross-Platform Validation**: Testing across all 5 supported device platforms
- **Security Testing**: Hash verification, vault security, and access control testing

### Security Requirements
- **No Hardcoded Secrets**: All secrets managed through Ansible Vault or external systems
- **SSH RSA Keys**: Use SSH RSA keys for all device access
- **Input Validation**: All user inputs validated and sanitized
- **Secure Defaults**: Secure configuration defaults for all components
- **Regular Updates**: Procedures for keeping all components updated
- **Vulnerability Management**: Process for handling security vulnerabilities

Build this system as a complete, production-ready solution that can be deployed immediately and operated with minimal technical expertise beyond standard Linux administration and basic Ansible knowledge.