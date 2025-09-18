# Platform-Specific File Transfer and Upgrade Mechanisms

## Overview

This guide provides comprehensive documentation of file transfer methods and upgrade mechanisms used by each supported platform in the Network Device Upgrade System. Understanding these differences is crucial for troubleshooting, security assessment, and platform-specific customizations.

## Table of Contents

1. [File Transfer Methods Summary](#file-transfer-methods-summary)
2. [Platform-Specific Details](#platform-specific-details)
3. [Security Implications](#security-implications)
4. [Implementation Code References](#implementation-code-references)
5. [Troubleshooting Guide](#troubleshooting-guide)

## File Transfer Methods Summary

| Platform | Primary Transfer Method | Secondary Method | Protocol | Authentication | File Size Limit |
|----------|------------------------|------------------|----------|----------------|------------------|
| **Cisco NX-OS** | SCP | SFTP | SSH | Username/Password | ~8GB |
| **Cisco IOS-XE** | SCP | HTTP/HTTPS | SSH/HTTP | Username/Password | ~4GB |
| **FortiOS** | **HTTPS API Upload** | **No SCP** | HTTPS | API Token/Session | ~2GB |
| **Opengear** | CLI Commands + Local | SSH/SCP for staging | SSH | Username/Password | ~1GB |
| **Metamako MOS** | SCP | HTTP | SSH/HTTP | Username/Password | ~500MB |

## Platform-Specific Details

### 1. Cisco NX-OS
**Transfer Method**: SCP (Secure Copy Protocol)

```yaml
# Implementation: ansible-content/roles/cisco-nxos-upgrade/tasks/image-loading.yml
- name: Transfer firmware image via SCP
  cisco.nxos.nxos_file_copy:
    local_file: "{{ local_firmware_path }}"
    remote_file: "{{ target_firmware_filename }}"
    file_system: "bootflash:"
    timeout: 1800
```

**Key Characteristics**:
- Uses standard SSH/SCP file transfer
- Supports large firmware files (up to 8GB)
- Files stored in bootflash: filesystem
- Verification via SHA512 hash comparison
- Requires SSH service enabled on device

**Upgrade Mechanism**:
- ISSU (In-Service Software Upgrade) for compatible models
- Traditional disruptive upgrade for older models
- Boot variable modification for next reboot

### 2. Cisco IOS-XE
**Transfer Method**: SCP with HTTP fallback

```yaml
# Implementation: ansible-content/roles/cisco-iosxe-upgrade/tasks/image-loading.yml
- name: Transfer firmware via SCP
  cisco.ios.ios_file_copy:
    local_file: "{{ local_firmware_path }}"
    remote_file: "{{ target_firmware_filename }}"
    file_system: "flash:"
```

**Key Characteristics**:
- Primary: SCP for large files
- Fallback: HTTP/HTTPS for smaller files
- Install mode vs. bundle mode support
- Flash filesystem management
- Space validation before transfer

**Upgrade Mechanism**:
- Install mode: `install add file` commands
- Bundle mode: Traditional boot variable modification
- Software management commands for newer IOS-XE

### 3. FortiOS (Fortinet)
**Transfer Method**: HTTPS API Upload (NO SCP)

```yaml
# Implementation: ansible-content/roles/fortios-upgrade/tasks/image-loading.yml
- name: Push firmware image from server to FortiOS device
  fortinet.fortios.fortios_monitor:
    vdom: "root"
    selector: "system_firmware_upload"
    params:
      file_content: "{{ lookup('file', local_firmware_path) | b64encode }}"
      filename: "{{ fortios_upgrade_state.target_version }}.out"
```

**Key Characteristics**:
- **NO SCP support** - API-only file transfer
- HTTPS REST API with base64 encoding
- Server-initiated PUSH transfer
- Built-in integrity verification
- Session-based authentication

**Why No SCP?**:
- FortiOS has limited SSH access (configuration only)
- No traditional filesystem access via SSH
- Purpose-built firmware upload API
- Integrated with FortiOS security model
- More secure than enabling additional protocols

**Upgrade Mechanism**:
- API-based installation commands
- Automatic reboot coordination
- HA-aware upgrade procedures
- Multi-step upgrade support for major version jumps

### 4. Opengear
**Transfer Method**: CLI Commands with SSH staging

```yaml
# Implementation: ansible-content/roles/opengear-upgrade/tasks/image-loading.yml
- name: Upload firmware via CLI commands
  ansible.builtin.raw: |
    {{ upgrade_command }} -f {{ firmware_filename }}
  vars:
    upgrade_command: "{{ 'puginstall' if device_architecture == 'current_cli'
                        else 'netflash' }}"
```

**Key Characteristics**:
- Legacy devices: `netflash` command (.flash files)
- Modern devices: `puginstall` command (.raucb files)
- Files must be pre-staged in `/tmp` or mounted storage
- Architecture-specific command sets
- Limited to specific file extensions

**Upgrade Mechanism**:
- Architecture-dependent upgrade commands
- Automatic reboot handling
- Version-specific file format support

### 5. Metamako MOS
**Transfer Method**: SCP with HTTP fallback

```yaml
# Implementation: ansible-content/roles/metamako-mos-upgrade/tasks/image-loading.yml
- name: Transfer MOS firmware via SCP
  ansible.posix.scp:
    src: "{{ local_firmware_path }}"
    dest: "/tmp/{{ mos_firmware_filename }}"
    host: "{{ ansible_host }}"
    username: "{{ ansible_user }}"
    password: "{{ ansible_password }}"
```

**Key Characteristics**:
- Standard SCP for MOS firmware
- HTTP for application packages (MetaWatch, MetaMux)
- Ultra-low latency requirements
- Application management post-upgrade
- Smaller firmware files (~500MB max)

**Upgrade Mechanism**:
- MOS upgrade with automatic reboot
- Post-upgrade application installation
- Latency-critical validation procedures

## Security Implications

### Most Secure: FortiOS HTTPS API
**Advantages**:
- Uses established HTTPS management session
- No additional protocols to secure
- Built-in upload validation
- Integrated permission model
- Session-based authentication

**Disadvantages**:
- File size encoding overhead (base64)
- Single transfer method (no fallback)

### Standard Security: SCP-based Platforms
**Advantages**:
- Well-established secure protocol
- Built on SSH encryption
- Standard file verification methods
- Multiple authentication options

**Disadvantages**:
- Requires SSH service enabled
- Additional protocol surface area
- Potential for configuration errors

### Security Best Practices by Platform

| Platform | Required Security Configuration |
|----------|--------------------------------|
| **Cisco NX-OS** | SSH enabled, secure ciphers, key-based auth preferred |
| **Cisco IOS-XE** | SSH enabled, secure file transfer settings |
| **FortiOS** | HTTPS admin access, secure API sessions |
| **Opengear** | SSH enabled, secure CLI access |
| **Metamako MOS** | SSH enabled, secure file transfer |

## Implementation Code References

### File Transfer Implementation Locations
```
ansible-content/roles/
├── cisco-nxos-upgrade/tasks/image-loading.yml        # SCP transfer
├── cisco-iosxe-upgrade/tasks/image-loading.yml       # SCP/HTTP transfer
├── fortios-upgrade/tasks/image-loading.yml           # HTTPS API upload
├── opengear-upgrade/tasks/image-loading.yml          # CLI commands
└── metamako-mos-upgrade/tasks/image-loading.yml      # SCP transfer
```

### Upgrade Implementation Locations
```
ansible-content/roles/
├── cisco-nxos-upgrade/tasks/image-installation.yml   # ISSU/traditional
├── cisco-iosxe-upgrade/tasks/image-installation.yml  # Install/bundle mode
├── fortios-upgrade/tasks/image-installation.yml      # API installation
├── opengear-upgrade/tasks/image-installation.yml     # CLI upgrade
└── metamako-mos-upgrade/tasks/image-installation.yml # MOS upgrade
```

## Troubleshooting Guide

### Common Transfer Issues by Platform

#### Cisco Platforms (NX-OS/IOS-XE)
```bash
# Check SSH connectivity
ssh admin@device-ip "show version"

# Verify filesystem space
ssh admin@device-ip "dir bootflash: | include free"

# Test SCP manually
scp firmware.bin admin@device-ip:bootflash:/
```

#### FortiOS
```bash
# Verify HTTPS API access
curl -k https://device-ip/api/v2/monitor/system/status

# Check storage space via API
# (API call examples in role documentation)
```

#### Opengear
```bash
# Check device architecture
ssh root@device-ip "cat /etc/opengear-release"

# Verify available space
ssh root@device-ip "df -h /tmp"
```

#### Metamako MOS
```bash
# Check MOS version
ssh admin@device-ip "cat /etc/mos-release"

# Verify application status
ssh admin@device-ip "systemctl status metawatch"
```

### Transfer Failure Diagnostic Steps

1. **Connectivity Issues**:
   - Verify network connectivity to device
   - Check firewall rules for required ports
   - Validate authentication credentials

2. **Space Issues**:
   - Check available filesystem space
   - Clean up old firmware files if needed
   - Verify file size vs. available space

3. **Permission Issues**:
   - Validate user permissions for file operations
   - Check SSH/API service status
   - Verify authentication method compatibility

4. **Platform-Specific Issues**:
   - FortiOS: Check API session limits and timeouts
   - Cisco: Verify SCP service configuration
   - Opengear: Check CLI command availability by architecture

## Integration with Network Upgrade System

The main upgrade workflow (`ansible-content/playbooks/main-upgrade-workflow.yml`) automatically selects the appropriate transfer method based on the platform type detected in the inventory. The system handles all platform-specific differences transparently while providing detailed logging for troubleshooting.

### Workflow Integration Points
1. **Platform Detection**: Inventory variable `platform_type`
2. **Method Selection**: Role-specific task includes
3. **Error Handling**: Platform-aware error recovery
4. **Validation**: Method-specific verification procedures

---

*This guide is part of the Network Device Upgrade System documentation. For related information, see [UPGRADE_WORKFLOW_GUIDE.md](UPGRADE_WORKFLOW_GUIDE.md) and [PLATFORM_IMPLEMENTATION_STATUS.md](PLATFORM_IMPLEMENTATION_STATUS.md).*