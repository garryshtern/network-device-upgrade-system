# Inventory Parameters Reference

Complete reference for all configuration parameters in the Network Device Upgrade System.

## Table of Contents

1. [Overview](#overview)
2. [Required Parameters](#required-parameters)
3. [Global Parameters (All Platforms)](#global-parameters-all-platforms)
4. [Cisco NX-OS Parameters](#cisco-nx-os-parameters)
5. [Cisco IOS-XE Parameters](#cisco-ios-xe-parameters)
6. [FortiOS Parameters](#fortios-parameters)
7. [Opengear Parameters](#opengear-parameters)
8. [Metamako MOS Parameters](#metamako-mos-parameters)
9. [Parameter Precedence](#parameter-precedence)
10. [Examples](#examples)

---

## Overview

Parameters are organized in a hierarchical structure:
- **group_vars/all.yml**: Global settings for all devices (112 lines)
- **group_vars/<platform>.yml**: Platform-specific defaults (120-200 lines each)
- **hosts.yml**: Per-host configuration and overrides
- **host_vars/<hostname>.yml**: Individual host overrides (optional)

**Parameter Precedence** (highest to lowest):
1. `--extra-vars` (command-line)
2. `host_vars/<hostname>.yml`
3. Host-specific settings in `hosts.yml`
4. `group_vars/<platform>.yml`
5. `group_vars/all.yml`
6. Role defaults

---

## Required Parameters

### Per-Device Parameters (in hosts.yml)

These parameters MUST be set for each device:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ansible_host` | string | **(required)** | IP address or FQDN of device (e.g., `192.168.1.10`) |
| `platform` | string | **(required)** | Platform identifier: `nxos`, `ios`, `fortios`, `opengear`, `metamako_mos` |

**Note**: `ansible_network_os` is automatically set by group_vars and should NOT be overridden.

### Required Runtime Parameters (--extra-vars)

These parameters MUST be provided as command-line extra-vars when running playbooks:

| Parameter | Type | Example | Description |
|-----------|------|---------|-------------|
| `target_hosts` | string | `switch-01` | Host pattern to target for upgrade |
| `target_firmware` | string | `nxos64-cs.10.4.5.M.bin` | Firmware filename to install |
| `max_concurrent` | int | `1` | Number of devices to upgrade concurrently |

**Usage Example**:
```bash
ansible-playbook ansible-content/playbooks/main-upgrade-workflow.yml \
  -i ansible-content/inventory/hosts.yml \
  --extra-vars "target_hosts=switch-01" \
  --extra-vars "target_firmware=nxos64-cs.10.4.5.M.bin" \
  --extra-vars "max_concurrent=1"
```

**Why extra-vars?** These runtime parameters are required at the play level (before group_vars are loaded) and must be passed via `--extra-vars` to ensure proper variable precedence.

---

## Global Parameters (All Platforms)

Defined in: `ansible-content/inventory/group_vars/all.yml`

### Connection Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ansible_connection_timeout` | int | `30` | Connection timeout in seconds |
| `ansible_command_timeout` | int | `300` | Command execution timeout in seconds |
| `ansible_connect_timeout` | int | `30` | Initial connection attempt timeout |

### Authentication

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ansible_user` | string | Platform-specific | SSH/API username (use vault) |
| `ansible_password` | string | Platform-specific | SSH/API password (use vault) |
| `ansible_ssh_private_key_file` | path | Platform-specific | Path to SSH private key (preferred) |

### Upgrade Workflow

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `target_firmware` | string | `""` | Firmware filename (MUST be set at runtime) |
| `target_hosts` | string | `all` | Host pattern for upgrades |
| `max_concurrent` | int | **REQUIRED** | **Serial execution limit - MUST be provided as extra_vars (`-e max_concurrent=N`)** - The 'serial' keyword is processed before group_vars are loaded |
| `max_retry_attempts` | int | `3` | Retry attempts on failure |
| `connectivity_timeout` | int | `300` | Post-reboot connectivity timeout (seconds) |
| `reboot_wait_time` | int | `600` | Wait time after reboot (seconds) |
| `validation_timeout` | int | `300` | Network validation timeout (seconds) |
| `required_space_gb` | int | `4` | Minimum free space required (GB) |
| `firmware_size_gb` | int | `2` | Expected firmware size (GB) |
| `maintenance_window` | bool | `false` | Enable maintenance mode (MUST be true for upgrades) |
| `platform_firmware` | dict | `{}` | Platform-specific firmware mappings |

### Phase Control

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `phase_1_timeout` | int | `3600` | Image loading phase timeout (seconds) |
| `phase_2_timeout` | int | `1800` | Installation phase timeout (seconds) |

### Backup and Rollback

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `backup_enabled` | bool | `true` | Enable config backup |
| `rollback_on_failure` | bool | `true` | Enable automatic rollback |
| `keep_backup_count` | int | `3` | Number of backups to retain |
| `backup_type` | string | `pre_upgrade` | Backup type: `pre_upgrade`, `post_upgrade`, `scheduled` |
| `include_startup_config` | bool | `true` | Include startup config in backups |
| `include_running_config` | bool | `true` | Include running config in backups |
| `restore_config` | bool | `true` | Restore config during rollback |
| `restore_firmware` | bool | `true` | Restore firmware during rollback |
| `emergency_mode` | bool | `false` | Emergency rollback mode |
| `rollback_reason` | string | `upgrade_failure` | Reason for rollback |

### Validation Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `skip_validation` | bool | `false` | Skip network validation |
| `network_state_comparison` | bool | `true` | Compare pre/post upgrade state |
| `baseline_capture_enabled` | bool | `true` | Capture baseline before upgrade |
| `convergence_monitoring` | bool | `true` | Monitor protocol convergence |
| `validation_type` | string | `post_upgrade` | Validation type: `pre_upgrade`, `post_upgrade` |

### Storage Paths

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `network_upgrade_base_path` | path | `/var/lib/network-upgrade` | Base path for all upgrade data |
| `firmware_base_path` | path | `<base>/firmware` | Firmware storage path |
| `backup_base_path` | path | `<base>/backups` | Backup storage path |
| `baseline_base_path` | path | `<base>/baselines` | Baseline storage path |
| `validation_results_path` | path | `<base>/validation` | Validation results path |
| `compliance_results_path` | path | `<base>/compliance` | Compliance results path |
| `log_base_path` | path | `/var/log/network-upgrade` | Log storage path |

### Timing Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `pre_upgrade_delay` | int | `30` | Delay before upgrade starts (seconds) |
| `post_upgrade_delay` | int | `60` | Delay after upgrade completes (seconds) |
| `interface_stabilization_wait` | int | `120` | Wait for interfaces to stabilize (seconds) |
| `protocol_convergence_timeout` | int | `300` | Protocol convergence timeout (seconds) |

### Security Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `hash_verification_enabled` | bool | `true` | Verify firmware SHA512 hash |
| `signature_validation_enabled` | bool | `false` | Verify firmware signature (vendor-dependent) |
| `cleanup_images_after_upgrade` | bool | `false` | Clean up old firmware after upgrade |

### Monitoring and Metrics

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `export_metrics` | bool | `true` | Export metrics to InfluxDB |
| `metrics_batch_size` | int | `100` | Metrics batch size |
| `metrics_export_interval` | int | `30` | Metrics export interval (seconds) |

### Notification Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `send_notifications` | bool | `true` | Send notifications |
| `notification_on_failure` | bool | `true` | Notify on failure |
| `notification_on_success` | bool | `false` | Notify on success |

### Environmental Validation

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `check_environmental_sensors` | bool | `true` | Check temperature/power sensors |
| `temperature_threshold_celsius` | int | `45` | Maximum temperature threshold |
| `power_threshold_percent` | int | `85` | Maximum power utilization threshold |

### Network Validation

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ping_test_enabled` | bool | `true` | Enable ping connectivity test |
| `ping_test_host` | string | `8.8.8.8` | Ping test target host |
| `ping_test_count` | int | `3` | Number of ping packets |
| `bgp_enabled` | bool | `true` | Enable BGP validation |
| `multicast_enabled` | bool | `true` | Enable multicast validation |

### Logging

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `log_level` | string | `info` | Log level: `debug`, `info`, `warning`, `error` |
| `structured_logging` | bool | `true` | Enable structured logging |
| `log_retention_days` | int | `30` | Log retention period (days) |

### Compliance and Reporting

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `generate_report` | bool | `true` | Generate compliance reports |
| `send_metrics` | bool | `true` | Send metrics to monitoring |
| `log_metrics_locally` | bool | `false` | Log metrics locally |
| `compliance_standards` | list | `[security_baseline, network_hardening]` | Compliance standards |
| `current_firmware_version` | string | `unknown` | Current firmware (detected at runtime) |
| `site_name` | string | `unknown` | Site/location name |
| `vendor` | string | `unknown` | Device vendor |
| `validation_score` | int | `0` | Validation score (calculated) |

---

## Cisco NX-OS Parameters

Defined in: `ansible-content/inventory/group_vars/cisco_nxos.yml`

### Connection Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ansible_network_os` | string | `cisco.nxos.nxos` | Ansible network OS identifier (DO NOT override) |
| `ansible_connection` | string | `ansible.netcommon.network_cli` | Connection plugin |
| `platform` | string | `nxos` | Platform identifier (use this in playbooks) |

### Platform Identification

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `vendor` | string | `cisco` | Vendor name |
| `device_family` | string | `nexus` | Device family |

### ISSU Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `enable_issu` | bool | `true` | Enable In-Service Software Upgrade |
| `issu_timeout` | int | `3600` | ISSU operation timeout (seconds) |
| `check_issu_compatibility` | bool | `true` | Check ISSU compatibility before upgrade |

### EPLD Upgrade Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `enable_epld_upgrade` | bool | `false` | Enable EPLD (Electronic Programmable Logic Device) upgrade |
| `install_combined_mode` | bool | `false` | Install firmware + EPLD in single operation (faster). If `false`, uses sequential mode (firmware first, then EPLD). Requires `enable_epld_upgrade=true` |
| `epld_upgrade_timeout` | int | `7200` | EPLD upgrade timeout (seconds) |
| `allow_disruptive_epld` | bool | `false` | Allow disruptive EPLD upgrades (on devices without dual supervisors) |
| `target_epld_firmware` | string | `""` | **REQUIRED** EPLD firmware filename (e.g., `n9000-epld.10.3.1.img`) - must be explicitly provided when `enable_epld_upgrade=true` |

### NX-OS Specific Timeouts

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `nxos_install_timeout` | int | `3600` | Install timeout (seconds) |
| `nxos_reboot_timeout` | int | `900` | Reboot timeout (seconds) |
| `nxos_copy_timeout` | int | `1800` | SCP/file copy timeout (seconds) |

### Storage Management

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `min_free_space_mb` | int | `2000` | Minimum free bootflash space (MB) |
| `cleanup_old_images` | bool | `true` | Clean up old firmware images |
| `keep_image_count` | int | `2` | Number of images to retain |

### Device Model Patterns

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `device_model_patterns` | list | Platform-specific | Device model detection patterns for platform identification |

**Example Device Model Patterns**:
```yaml
device_model_patterns:
  - regex: "N9K-C92.*"
    platform: "nexus_9000"
    model_prefix: "N9K-C92"
  - regex: "N9K-C93.*"
    platform: "nexus_9000"
    model_prefix: "N9K-C93"
```

**Note**: Firmware filenames are now passed directly via `target_firmware` parameter (e.g., `nxos.10.3.1.bin`). No automatic filename construction.

### Boot Variables

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `primary_boot_image` | string | `bootflash:///{{ target_firmware }}` | Primary boot image (uses target_firmware filename) |
| `secondary_boot_image` | string | `bootflash:///nxos64-cs.backup.bin` | Secondary boot image |

### Validation Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `validate_vdc_mode` | bool | `true` | Validate Virtual Device Context mode |
| `validate_feature_set` | bool | `true` | Validate enabled feature set |
| `check_license_usage` | bool | `true` | Check license usage |

### BGP Validation

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `validate_bgp` | bool | `true` | Validate BGP neighbors and state |
| `bgp_convergence_timeout` | int | `300` | BGP convergence timeout (seconds) |
| `expected_bgp_neighbors` | list | `[]` | Expected BGP neighbor IPs |

### OSPF Validation

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `validate_ospf` | bool | `true` | Validate OSPF neighbors and state |
| `ospf_convergence_timeout` | int | `180` | OSPF convergence timeout (seconds) |

### Interface Validation

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `validate_port_channels` | bool | `true` | Validate port-channel status |
| `validate_vpc` | bool | `true` | Validate Virtual Port Channel |
| `check_transceiver_status` | bool | `true` | Check transceiver/optics status |

### Multicast Validation

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `validate_pim` | bool | `true` | Validate PIM (Protocol Independent Multicast) |
| `validate_igmp` | bool | `true` | Validate IGMP |
| `check_rp_reachability` | bool | `true` | Check Rendezvous Point reachability |

### VDC Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `vdc_mode` | bool | `false` | Virtual Device Context mode |
| `target_vdc` | string | `{{ ansible_host }}-vdc` | Target VDC name |

### Feature Validation

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `required_features` | list | `[bgp, ospf, pim, igmp, vpc, lacp]` | Required NX-OS features |

### Error Thresholds

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `max_interface_errors` | int | `100` | Maximum interface errors |
| `max_crc_errors` | int | `50` | Maximum CRC errors |
| `max_late_collisions` | int | `10` | Maximum late collisions |

---

## Cisco IOS-XE Parameters

Defined in: `ansible-content/inventory/group_vars/cisco_iosxe.yml`

### Connection Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ansible_network_os` | string | `cisco.ios.ios` | Ansible network OS identifier (DO NOT override) |
| `ansible_connection` | string | `ansible.netcommon.network_cli` | Connection plugin |
| `platform` | string | `ios` | Platform identifier (use this in playbooks) |

### Platform Identification

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `vendor` | string | `cisco` | Vendor name |
| `device_family` | string | `catalyst` | Device family |

### Install Mode Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `prefer_install_mode` | bool | `true` | Prefer install mode over bundle mode |
| `install_mode_timeout` | int | `3600` | Install mode timeout (seconds) |
| `bundle_mode_timeout` | int | `1800` | Bundle mode timeout (seconds) |

### Firmware Specification

**Note**: Firmware filenames are now passed directly via `target_firmware` parameter. No automatic filename construction.

Example:
```bash
target_firmware="cat9k_iosxe.17.06.05.SPA.bin"
```

### Storage Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `min_bootflash_space_gb` | int | `2` | Minimum bootflash space (GB) |
| `cleanup_old_images` | bool | `true` | Clean up old images |
| `keep_image_count` | int | `2` | Number of images to retain |

### Boot System Management

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `manage_boot_system` | bool | `true` | Manage boot system statements |
| `clear_old_boot_entries` | bool | `true` | Clear old boot entries |
| `verify_boot_config` | bool | `true` | Verify boot configuration |

### Reboot Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `bundle_mode_reboot_delay` | int | `60` | Reboot delay for bundle mode (seconds) |
| `post_reboot_wait` | int | `180` | Post-reboot wait time (seconds) |
| `connectivity_test_retries` | int | `10` | Connectivity test retry attempts |

### Validation Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `validate_stack` | bool | `true` | Validate stack configuration |
| `validate_redundancy` | bool | `true` | Validate redundancy status |
| `check_power_supplies` | bool | `true` | Check power supply status |

### Interface Validation

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `validate_etherchannel` | bool | `true` | Validate EtherChannel status |
| `check_interface_utilization` | bool | `true` | Check interface utilization |
| `validate_switchport_config` | bool | `true` | Validate switchport configuration |

### Routing Validation

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `validate_eigrp` | bool | `true` | Validate EIGRP |
| `validate_ospf` | bool | `true` | Validate OSPF |
| `check_route_summarization` | bool | `true` | Check route summarization |
| `eigrp_convergence_timeout` | int | `240` | EIGRP convergence timeout (seconds) |
| `ospf_convergence_timeout` | int | `180` | OSPF convergence timeout (seconds) |

### QoS Validation

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `validate_qos_policies` | bool | `true` | Validate QoS policies |
| `check_queue_stats` | bool | `true` | Check queue statistics |

### Security Validation

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `validate_acl_policies` | bool | `true` | Validate ACL policies |
| `check_port_security` | bool | `true` | Check port security |
| `validate_dhcp_snooping` | bool | `true` | Validate DHCP snooping |

### SNMP Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `validate_snmp` | bool | `true` | Validate SNMP configuration |
| `snmp_community` | string | `{{ vault_snmp_community }}` | SNMP community string (vault) |

### Stacking

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `stack_mode` | bool | `false` | Enable stack mode |
| `validate_stack_members` | bool | `true` | Validate stack members |
| `stack_master_priority` | int | `15` | Stack master priority |

### Performance Thresholds

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `max_cpu_utilization` | int | `80` | Maximum CPU utilization (%) |
| `max_memory_utilization` | int | `85` | Maximum memory utilization (%) |
| `max_interface_errors` | int | `1000` | Maximum interface errors |

### Error Thresholds

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `max_input_errors` | int | `100` | Maximum input errors |
| `max_output_errors` | int | `100` | Maximum output errors |
| `max_buffer_failures` | int | `10` | Maximum buffer failures |

### License Validation

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `check_license_status` | bool | `true` | Check license status |
| `required_licenses` | list | `[]` | Required licenses |

---

## FortiOS Parameters

Defined in: `ansible-content/inventory/group_vars/fortios.yml`

### Connection Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ansible_network_os` | string | `fortinet.fortios.fortios` | Ansible network OS identifier (DO NOT override) |
| `ansible_connection` | string | `httpapi` | Connection plugin (HTTPS API) |
| `platform` | string | `fortios` | Platform identifier (use this in playbooks) |
| `ansible_httpapi_key` | string | `{{ vault_fortios_api_token }}` | API token (preferred) |
| `ansible_httpapi_use_ssl` | bool | `true` | Use HTTPS |
| `ansible_httpapi_validate_certs` | bool | `false` | Validate SSL certificates |
| `ansible_httpapi_port` | int | `443` | HTTPS API port |

### Platform Identification

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `vendor` | string | `fortinet` | Vendor name |
| `device_family` | string | `fortigate` | Device family |

### VDOM Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `vdom` | string | `root` | Virtual domain |
| `multi_vdom_mode` | bool | `false` | Multi-VDOM mode |
| `target_vdom` | string | `root` | Target VDOM for operations |

### HA Cluster Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ha_enabled` | bool | `false` | High Availability enabled |
| `ha_mode` | string | `standalone` | HA mode: `standalone`, `active-passive`, `active-active` |
| `ha_group_id` | int | `1` | HA cluster group ID |
| `ha_priority` | int | `128` | HA priority (higher = primary) |
| `check_ha_sync` | bool | `true` | Check HA synchronization |

### License and FortiCare

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `validate_forticare_license` | bool | `true` | Validate FortiCare license |
| `check_support_contract` | bool | `true` | Check support contract status |
| `license_grace_period_days` | int | `30` | License grace period (days) |

### Firmware Management

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `firmware_upload_method` | string | `server_push` | Firmware upload method (server-initiated only) |
| `local_firmware_path` | path | `{{ firmware_base_path }}` | Local firmware path |
| `verify_firmware_signature` | bool | `true` | Verify firmware signature |

### Security Service Validation

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `validate_security_services` | bool | `true` | Validate security services |
| `security_services` | dict | See below | Security service validation flags |

**Security Services**:
```yaml
security_services:
  antivirus: true
  ips: true
  web_filter: true
  application_control: true
  email_filter: false
  dlp: false
```

### Network Validation

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `validate_interfaces` | bool | `true` | Validate interface status |
| `validate_routing` | bool | `true` | Validate routing tables |
| `validate_firewall_policies` | bool | `true` | Validate firewall policies |
| `policy_validation_timeout` | int | `180` | Policy validation timeout (seconds) |

### VPN Validation

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `validate_ssl_vpn` | bool | `true` | Validate SSL VPN |
| `validate_ipsec_vpn` | bool | `true` | Validate IPsec VPN tunnels |
| `vpn_tunnel_recovery_timeout` | int | `300` | VPN tunnel recovery timeout (seconds) |

### Performance Thresholds

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `max_cpu_utilization` | int | `85` | Maximum CPU utilization (%) |
| `max_memory_utilization` | int | `90` | Maximum memory utilization (%) |
| `max_session_count` | int | `500000` | Maximum concurrent sessions |
| `max_policy_count` | int | `10000` | Maximum firewall policies |

### System Validation

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `validate_system_time` | bool | `true` | Validate system time |
| `ntp_sync_required` | bool | `true` | NTP sync required |
| `validate_dns_resolution` | bool | `true` | Validate DNS resolution |

### Backup and Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `backup_before_upgrade` | bool | `true` | Backup before upgrade |
| `backup_scope` | string | `global` | Backup scope: `global`, `vdom-specific` |
| `config_validation_enabled` | bool | `true` | Validate configuration |

### FortiGuard Services

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `fortiguard_services` | dict | See below | FortiGuard database validation |

**FortiGuard Services**:
```yaml
fortiguard_services:
  antivirus_db: true
  ips_db: true
  webfilter_db: true
  application_db: true
```

### Upgrade Process

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `upgrade_method` | string | `standard` | Upgrade method: `standard`, `coordinated` (for HA) |
| `pre_upgrade_backup` | bool | `true` | Backup before upgrade |
| `post_upgrade_validation_timeout` | int | `600` | Post-upgrade validation timeout (seconds) |

### HA Coordination

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ha_coordination.upgrade_sequence` | string | `secondary_first` | HA upgrade sequence |
| `ha_coordination.sync_timeout` | int | `1800` | HA sync timeout (seconds) |
| `ha_coordination.failover_test` | bool | `false` | Test failover during upgrade |

### Logging and Monitoring

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `log_validation` | bool | `true` | Validate logging |
| `log_disk_usage_threshold` | int | `85` | Log disk usage threshold (%) |
| `syslog_validation` | bool | `false` | Validate syslog configuration |

### Advanced Features

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `sd_wan_validation` | bool | `false` | Validate SD-WAN configuration |
| `security_fabric_validation` | bool | `false` | Validate Security Fabric |
| `outbreak_prevention` | bool | `true` | Outbreak prevention enabled |

### Recovery Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `auto_recovery` | bool | `true` | Enable auto-recovery |
| `recovery_timeout` | int | `900` | Recovery timeout (seconds) |
| `emergency_access_enabled` | bool | `true` | Emergency access enabled |

### Validation Timeouts

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `interface_recovery_timeout` | int | `120` | Interface recovery timeout (seconds) |
| `routing_recovery_timeout` | int | `300` | Routing recovery timeout (seconds) |
| `policy_recovery_timeout` | int | `180` | Policy recovery timeout (seconds) |
| `service_recovery_timeout` | int | `240` | Service recovery timeout (seconds) |

---

## Opengear Parameters

Defined in: `ansible-content/inventory/group_vars/opengear.yml`

### Connection Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ansible_network_os` | string | `opengear` | Ansible network OS identifier (DO NOT override) |
| `ansible_connection` | string | `ssh` | Connection plugin (overridden for modern API devices) |
| `platform` | string | `opengear` | Platform identifier (use this in playbooks) |
| `opengear_username` | string | `{{ vault_opengear_username }}` | Opengear username |
| `opengear_password` | string | `{{ vault_opengear_password }}` | Opengear password |
| `opengear_api_token` | string | `{{ vault_opengear_api_token }}` | API token (preferred for API) |

### Platform Identification

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `vendor` | string | `opengear` | Vendor name |
| `device_family` | string | `console_server` | Device family: `console_server`, `smart_pdu` |

### API Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `api_base_url` | string | `https://{{ ansible_host }}/api/v1` | API base URL |
| `api_timeout` | int | `60` | API timeout (seconds) |
| `api_retries` | int | `3` | API retry attempts |
| `validate_certs` | bool | `false` | Validate SSL certificates |

### Device Type Detection

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `auto_detect_device_type` | bool | `true` | Auto-detect device architecture |
| `supported_models` | dict | See group_vars | Supported device models by architecture |

**Supported Models**:
- **Legacy CLI**: CM7100, OM7200 (5.x.x versions)
- **Current CLI**: CM8100, OM2100, OM2200 (YY.MM.x versions)

### Firmware Management

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `firmware_upload_timeout` | int | `3600` | Firmware upload timeout (seconds) |
| `firmware_chunk_size` | int | `1048576` | Upload chunk size (1MB) |
| `verify_firmware_checksum` | bool | `true` | Verify firmware checksum |
| `local_firmware_path` | path | `{{ firmware_base_path }}` | Local firmware path |

### Firmware Filename Patterns

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `firmware_filename_patterns` | dict | Architecture-specific | Firmware patterns by device architecture |

**Note**: Firmware filenames are now passed directly via `target_firmware` parameter.

**Example Filenames**:
- Legacy CLI: `cm71xx-5.16.4.flash`
- Current CLI: `console_manager-24.10.1-production-signed.raucb`

### Version Formats

| Architecture | Pattern | Default | Example |
|-----------|------|---------|-------------|
| Legacy CLI | `5.x.x` | N/A | `5.16.4` |
| Current CLI | `YY.MM.x` | N/A | `25.07.0` |

### Upgrade Commands

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `upgrade_commands` | dict | Architecture-specific | Upgrade commands by architecture |

**Commands**:
- **Legacy CLI**: `netflash`
- **Current CLI**: `puginstall --reboot-after`

### Console Server Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `max_serial_ports` | int | `48` | Maximum serial ports |
| `notify_active_sessions` | bool | `true` | Notify active sessions before upgrade |
| `maintenance_mode_message` | string | Custom message | Maintenance mode message |
| `session_timeout_warning` | int | `300` | Session timeout warning (seconds) |
| `graceful_session_closure` | bool | `true` | Graceful session closure |

### Smart PDU Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `max_power_outlets` | int | `24` | Maximum power outlets |
| `power_safety_threshold` | int | `90` | Power safety threshold (%) |
| `critical_outlet_protection` | bool | `true` | Protect critical outlets |
| `environmental_monitoring` | bool | `true` | Monitor environmental sensors |
| `power_cycle_delay` | int | `5` | Power cycle delay (seconds) |

### Validation Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `serial_port_validation.test_connectivity` | bool | `true` | Test serial port connectivity |
| `serial_port_validation.test_timeout` | int | `30` | Test timeout (seconds) |
| `serial_port_validation.max_test_ports` | int | `5` | Max ports to test |
| `power_outlet_validation.test_non_critical_only` | bool | `true` | Test non-critical outlets only |
| `power_outlet_validation.max_test_outlets` | int | `3` | Max outlets to test |
| `power_outlet_validation.power_cycle_test` | bool | `false` | Power cycle test (risky) |

### Network Validation

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `network_connectivity_test.enabled` | bool | `true` | Enable connectivity test |
| `network_connectivity_test.test_host` | string | `8.8.8.8` | Test host |
| `network_connectivity_test.ping_count` | int | `3` | Ping count |
| `network_connectivity_test.timeout` | int | `10` | Timeout (seconds) |

### Configuration Management

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `backup_config_before_upgrade` | bool | `true` | Backup before upgrade |
| `config_validation_enabled` | bool | `true` | Validate configuration |
| `restore_config_on_failure` | bool | `true` | Restore config on failure |

### Environmental Monitoring

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `environmental_sensors.temperature` | bool | `true` | Monitor temperature |
| `environmental_sensors.humidity` | bool | `true` | Monitor humidity |
| `environmental_sensors.validate_thresholds` | bool | `true` | Validate thresholds |

### Boot Times

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `boot_times.modern_api.reboot_wait_time` | int | `120` | Modern device reboot time (seconds) |
| `boot_times.legacy_cli.reboot_wait_time` | int | `180` | Legacy device reboot time (seconds) |

### Legacy CLI Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `legacy_cli.upgrade_timeout` | int | `1800` | Legacy upgrade timeout (seconds) |
| `legacy_cli.progress_check_interval` | int | `30` | Progress check interval (seconds) |
| `legacy_cli.max_retries` | int | `60` | Max retry attempts |
| `legacy_cli.session_message_delay` | int | `60` | User warning delay (seconds) |
| `legacy_cli.cleanup_firmware_after_install` | bool | `true` | Clean up firmware after install |

### Security Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `change_default_passwords` | bool | `false` | Change default passwords (assume done) |
| `validate_ssl_certificates` | bool | `false` | Validate SSL certs (often self-signed) |
| `enable_audit_logging` | bool | `true` | Enable audit logging |

### Rollback Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `enable_automatic_rollback` | bool | `true` | Enable automatic rollback |
| `rollback_timeout` | int | `600` | Rollback timeout (seconds) |
| `preserve_user_data` | bool | `true` | Preserve user data during rollback |

---

## Metamako MOS Parameters

Defined in: `ansible-content/inventory/group_vars/metamako_mos.yml`

### Connection Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ansible_network_os` | string | `metamako_mos` | Ansible network OS identifier (DO NOT override) |
| `ansible_connection` | string | `ansible.netcommon.network_cli` | Connection plugin |
| `platform` | string | `metamako_mos` | Platform identifier (use this in playbooks) |

### Platform Identification

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `vendor` | string | `metamako` | Vendor name |
| `device_family` | string | `metamux` | Device family |

### Ultra-Low Latency Requirements

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `max_allowed_latency_ns` | int | `100` | Maximum allowed latency (nanoseconds) |
| `latency_degradation_threshold` | float | `1.1` | Latency degradation threshold (10% max increase) |
| `enable_latency_monitoring` | bool | `true` | Enable latency monitoring |

### Specialized Component Validation

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `check_metawatch` | bool | `true` | Check MetaWatch status |
| `check_metamux` | bool | `true` | Check MetaMux status |
| `validate_latency_performance` | bool | `true` | Validate latency performance |

### Image Management

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `image_verification_required` | bool | `true` | Require image verification |

### Performance Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `performance_mode` | string | `low_latency` | Performance mode |
| `enable_performance_benchmarks` | bool | `true` | Enable performance benchmarks |
| `benchmark_timeout` | int | `300` | Benchmark timeout (seconds) |

### Timing Validation (Critical)

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `validate_pps_sync` | bool | `true` | Validate Pulse Per Second synchronization |
| `validate_time_accuracy` | bool | `true` | Validate time accuracy |
| `max_time_drift_ms` | int | `1` | Maximum time drift (milliseconds) |

### Interface Validation

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `validate_fiber_optics` | bool | `true` | Validate fiber optic links |
| `check_signal_integrity` | bool | `true` | Check signal integrity |
| `validate_port_mapping` | bool | `true` | Validate port mapping |

### Environmental Monitoring

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `monitor_temperature` | bool | `true` | Monitor temperature |
| `temperature_alert_threshold` | int | `40` | Temperature alert threshold (Celsius) |
| `monitor_power_consumption` | bool | `true` | Monitor power consumption |

### Upgrade Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `mos_upgrade_method` | string | `staged` | MOS upgrade method |
| `verify_staged_image` | bool | `true` | Verify staged image |
| `staging_timeout` | int | `1800` | Staging timeout (seconds) |

### Latency Measurement

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `latency_measurement_interval` | int | `10` | Measurement interval (seconds) |
| `latency_sample_count` | int | `100` | Sample count per measurement |
| `continuous_monitoring` | bool | `true` | Continuous monitoring |

### Validation Thresholds

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `max_packet_loss_percent` | float | `0.01` | Maximum packet loss (%) |
| `max_jitter_ns` | int | `50` | Maximum jitter (nanoseconds) |
| `min_throughput_gbps` | int | `10` | Minimum throughput (Gbps) |

### Recovery Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `auto_recovery_enabled` | bool | `true` | Enable automatic recovery |
| `recovery_timeout` | int | `300` | Recovery timeout (seconds) |
| `rollback_on_latency_degradation` | bool | `true` | Rollback if latency degrades |

### Time Synchronization (Critical)

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ptp_enabled` | bool | `true` | Enable Precision Time Protocol |
| `ptp_domain` | int | `0` | PTP domain |
| `validate_ptp_sync` | bool | `true` | Validate PTP synchronization |

### Hardware Validation

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `validate_fpga_status` | bool | `true` | Validate FPGA status |
| `check_ddr_memory` | bool | `true` | Check DDR memory |
| `validate_pcie_links` | bool | `true` | Validate PCIe links |

### Application Management

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `manage_applications` | bool | `false` | Manage applications during upgrade |
| `application_action` | string | `""` | Action: `install`, `remove`, `enable`, `disable` |
| `application_name` | string | `""` | Application name |
| `application_source` | string | `""` | Application source (URL or path) |
| `applications_to_enable` | list | `[]` | Applications to enable |
| `applications_to_disable` | list | `[]` | Applications to disable |
| `applications_to_force_shutdown` | list | `[]` | Applications to force shutdown |

### EOS Extension Management

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `eos_extension_action` | string | `""` | Action: `install`, `remove` |
| `eos_extension_name` | string | `""` | EOS extension name |
| `eos_extension_source` | string | `""` | EOS extension source |

---

## Parameter Precedence

Parameters are resolved in the following order (highest to lowest priority):

1. **Command-line `--extra-vars`**: Runtime overrides
   ```bash
   ansible-playbook playbook.yml --extra-vars "target_firmware=test.bin maintenance=true"
   ```

2. **host_vars/<hostname>.yml**: Individual host variable files
   ```yaml
   # host_vars/nxos-switch-01.yml
   target_firmware_version: "10.4.5.M"
   enable_issu: true
   ```

3. **Host-specific in hosts.yml**: Inline host variables
   ```yaml
   hosts:
     nxos-switch-01:
       ansible_host: 192.168.1.10
   ```

   **Note**: `target_firmware` is passed as a runtime parameter, not defined in inventory.

4. **group_vars/<platform>.yml**: Platform-specific defaults
   ```yaml
   # group_vars/cisco_nxos.yml
   enable_issu: true
   issu_timeout: 3600
   ```

5. **group_vars/all.yml**: Global defaults
   ```yaml
   # group_vars/all.yml
   max_retry_attempts: 3
   backup_enabled: true
   ```

6. **Role defaults**: Defined in roles/*/defaults/main.yml

---

## Examples

### Minimal Configuration

```yaml
# ansible-content/inventory/hosts.yml
all:
  children:
    cisco_nxos:
      hosts:
        switch-01:
          ansible_host: 192.168.1.10
          platform: nxos
```

**Usage** (Required runtime parameters):
```bash
ansible-playbook ansible-content/playbooks/main-upgrade-workflow.yml \
  -i ansible-content/inventory/hosts.yml \
  --extra-vars "target_hosts=switch-01" \
  --extra-vars "target_firmware=nxos64-cs.10.4.5.M.bin" \
  --extra-vars "max_concurrent=1"
```

**Note**: `target_hosts`, `target_firmware`, and `max_concurrent` MUST be provided as extra-vars.

### Advanced Multi-Platform Configuration

```yaml
# ansible-content/inventory/hosts.yml
all:
  children:
    cisco_nxos:
      hosts:
        nxos-core-01:
          ansible_host: 10.0.1.10
          platform: nxos
          enable_issu: true
          validate_bgp: true
          expected_bgp_neighbors: ["10.0.0.1", "10.0.0.2"]
          site_name: "datacenter-east"
          device_role: "core-switch"
          # Note: target_firmware passed via --extra-vars at runtime

    cisco_iosxe:
      hosts:
        iosxe-access-01:
          ansible_host: 10.0.2.10
          platform: ios
          device_model: "C9300"
          target_version: "17.09.04a"
          stack_mode: true
          validate_stack_members: true

    fortios:
      hosts:
        fortigate-ha-primary:
          ansible_host: 10.0.3.10
          platform: fortios
          target_firmware: "7.4.1"
          ha_enabled: true
          ha_mode: "active-passive"
          ha_priority: 200
          upgrade_method: "coordinated"

        fortigate-ha-secondary:
          ansible_host: 10.0.3.11
          platform: fortios
          target_firmware: "7.4.1"
          ha_enabled: true
          ha_mode: "active-passive"
          ha_priority: 100

    opengear:
      hosts:
        console-server-01:
          ansible_host: 10.0.4.10
          platform: opengear
          device_model: "CM8100"
          target_version: "25.07.0"
          notify_active_sessions: true

    metamako_mos:
      hosts:
        metamako-trading-01:
          ansible_host: 10.0.5.10
          platform: metamako_mos
          target_firmware: "5.14.0"
          max_allowed_latency_ns: 100
          ptp_enabled: true
          validate_ptp_sync: true
```

### Per-Host Variables File

```yaml
# ansible-content/inventory/host_vars/nxos-core-01.yml
---
# Authentication
ansible_user: "{{ vault_nxos_core_01_username }}"
ansible_password: "{{ vault_nxos_core_01_password }}"

# Firmware
target_firmware_version: "10.4.5.M"

# ISSU Settings
enable_issu: true
issu_timeout: 3600

# EPLD Settings
enable_epld_upgrade: true
install_combined_mode: false  # Set to 'true' for faster firmware+EPLD upgrade in single operation
allow_disruptive_epld: false
# Note: target_epld_firmware (e.g., n9000-epld.10.3.1.img) passed via --extra-vars

# Validation
validate_bgp: true
expected_bgp_neighbors:
  - "10.0.0.1"
  - "10.0.0.2"
  - "10.0.0.3"
validate_vpc: true
validate_ospf: true

# Device Info
site_name: "datacenter-east"
device_role: "core-switch"
vendor: "cisco"
device_family: "nexus"
```

### Runtime Override Example

```bash
# Override multiple parameters at runtime
ansible-playbook ansible-content/playbooks/main-upgrade-workflow.yml \
  --inventory ansible-content/inventory/hosts.yml \
  --extra-vars "target_hosts=nxos-core-01" \
  --extra-vars "target_firmware=nxos64-cs.10.4.5.M.bin" \
  --extra-vars "maintenance=true" \
  --extra-vars "auto_rollback=true" \
  --extra-vars "skip_validation=false" \
  --extra-vars "max_retry_attempts=5"
```

---

## Best Practices

1. **Use Ansible Vault**: Store all credentials in Ansible Vault
   ```bash
   ansible-vault create ansible-content/inventory/group_vars/all/vault.yml
   ```

2. **Platform Identifier**: Always use `platform` (not `ansible_network_os`) in playbooks

3. **Version Formats**: Follow vendor-specific version formats
   - NX-OS: `X.Y.Z`, `X.Y.Z.M`, `X.Y.Z.F` (suffixes optional)
   - IOS-XE: `XX.YY.ZZa`
   - FortiOS: `X.Y.Z`
   - Opengear: `YY.MM.x` (modern) or `5.x.x` (legacy)
   - Metamako: `X.Y.Z`

4. **Group Variables**: Use group_vars for platform defaults, override per-host only when necessary

5. **Validation**: Always enable validation unless specifically required to skip

6. **Maintenance Window**: Set `maintenance=true` for production upgrades

7. **Rollback**: Enable `auto_rollback=true` for automatic recovery

8. **Documentation**: Document custom parameters in host_vars files

9. **Testing**: Test configuration with `--check` mode first
   ```bash
   ansible-playbook playbook.yml --check --diff
   ```

10. **Firmware Naming**: Follow firmware naming standards in `docs/firmware-naming-standards.md`

---

## Related Documentation

- [Firmware Naming Standards](firmware-naming-standards.md)
- [Testing Framework Guide](testing-framework-guide.md)
- [Container Deployment Guide](container-deployment.md)
- [Vendor-Specific Guides](vendor-specific/)
- [AWX Configuration Guide](awx-configuration-guide.md)

---

**Last Updated**: 2025-10-09
**Document Version**: 1.0
