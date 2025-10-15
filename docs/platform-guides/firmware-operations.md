# Firmware Operations Documentation

## Image Transfer Direction: PUSH Operations

**CRITICAL: This system implements PUSH operations, NOT PULL operations.**

### What is PUSH vs PULL?

- **PUSH**: Images are transferred FROM the device TO a server/repository
- **PULL**: Images are transferred FROM a server/repository TO the device

### Our Implementation: PUSH Only

This network device upgrade system is designed around **PUSH operations** for security and operational reasons:

#### 1. Configuration Backup (PUSH)
```yaml
# Device pushes its configuration to backup server
- name: Backup configuration
  copy:
    src: "running-config"
    dest: "{{ backup_server }}/configs/{{ inventory_hostname }}-{{ ansible_date_time.iso8601 }}.cfg"
```

#### 2. Image Staging (Local Operations)
```yaml
# Local staging on device bootflash, NOT pulling from external server
- name: Stage firmware locally
  copy:
    src: "bootflash:firmware.bin"
    dest: "bootflash:staged-firmware.bin"
```

#### 3. Status Reports (PUSH)
```yaml
# Device pushes status updates to monitoring system
- name: Report upgrade status
  uri:
    url: "{{ monitoring_server }}/api/device-status"
    method: POST
    body: "{{ upgrade_status }}"
```

### Security Benefits of PUSH Operations

1. **Network Security**: Devices don't reach out to external servers
2. **Access Control**: Centralized control of what gets pushed where
3. **Audit Trail**: All outbound data transfers are logged and controlled
4. **Reduced Attack Surface**: No inbound file transfer services required on devices

### Testing Framework

The mock device framework tests PUSH operations by validating:

- ✅ Configuration backup to external systems
- ✅ Status reporting to monitoring systems
- ✅ Local file staging operations
- ❌ **NOT TESTED**: External firmware downloads (PULL operations)

### Platform-Specific PUSH Commands

#### Cisco NX-OS
```bash
# PUSH configuration
copy running-config scp://server/backup.cfg

# Local staging (not PULL)
copy bootflash:firmware.bin bootflash:staged-firmware.bin
```

#### Cisco IOS-XE
```bash
# PUSH via install mode
request platform software package install switch all file bootflash:firmware.bin

# PUSH configuration
copy running-config scp://server/backup.cfg
```

#### FortiOS
```bash
# PUSH configuration
execute backup config ftp server.com backup.cfg

# Local firmware operations
execute restore image local-firmware.bin
```

### Mock Device Testing

The comprehensive mock device tests validate PUSH operations across all 5 platforms:

- **cisco_nxos**: copy operations for local staging
- **cisco_iosxe**: install mode commands for managed deployment
- **fortios**: HA-aware configuration backup
- **opengear**: configuration management via API
- **metamako_mos**: application state management

**IMPORTANT**: Any test that attempts PULL operations (downloading from external servers) should FAIL as this is not the intended design.