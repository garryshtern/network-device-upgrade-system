# Platform-Specific File Transfer and Upgrade Mechanisms

## Overview

This guide provides comprehensive documentation of file transfer methods and upgrade mechanisms used by each supported platform in the Network Device Upgrade System. Understanding these differences is crucial for troubleshooting, security assessment, and platform-specific customizations.

> **🔐 Security First**: All platforms prioritize **SSH key authentication** and **API tokens** over password-based authentication. The system automatically prefers these secure methods when available, falling back to passwords only when necessary. This approach enhances security and enables automated operations without storing plaintext passwords.

## Table of Contents

1. [File Transfer Methods Summary](#file-transfer-methods-summary)
2. [Platform-Specific Details](#platform-specific-details)
3. [Security Implications](#security-implications)
4. [Implementation Code References](#implementation-code-references)
5. [Troubleshooting Guide](#troubleshooting-guide)

## File Transfer Methods Summary

| Platform | Primary Transfer Method | Secondary Method | Protocol | **Primary Authentication** | **Fallback Authentication** | File Size Limit | **Firmware Examples** |
|----------|------------------------|------------------|----------|---------------------------|----------------------------|------------------|----------------------|
| **Cisco NX-OS** | SCP | SFTP | SSH | **SSH Key** | Username/Password | ~8GB | `nxos64-cs.10.4.5.M.bin`, `nxos64-msll.10.4.6.M.bin` |
| **Cisco IOS-XE** | SCP | HTTP/HTTPS | SSH/HTTP | **SSH Key** | Username/Password | ~4GB | `cat9k_iosxe.17.15.03a.SPA.bin`, `c8000aes-universalk9.17.15.03a.SPA.bin` |
| **FortiOS** | **HTTPS API Upload** | **No SCP** | HTTPS | **API Token** | Username/Password | ~2GB | `FortiGate_600D_v7.0.12.build0523.out` |
| **Opengear** | CLI Commands + Local | SSH/SCP for staging | SSH | **SSH Key + API Token** | Username/Password | ~1GB | `cm71xx-5.2.4.flash`, `console_manager-25.07.0-production-signed.raucb` |
| **Metamako MOS** | SCP | HTTP | SSH/HTTP | **SSH Key** | Username/Password | ~500MB | `mos-0.39.9.iso` |

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

**Platform-Specific Firmware Patterns**:
- **Nexus 9000 Series**: `nxos64-cs.{version}.M.bin` (e.g., `nxos64-cs.10.4.5.M.bin`)
- **Nexus 92384/93180**: `nxos64-cs.{version}.M.bin` (e.g., `nxos64-cs.10.4.5.M.bin`)
- **Nexus 3548**: `nxos64-msll.{version}.M.bin` (e.g., `nxos64-msll.10.4.6.M.bin`)
- **Nexus 7000 Series**: `n7000-s2-dk9.{version}.bin` (e.g., `n7000-s2-dk9.9.3.12.bin`)
- **EPLD Images**: `n9000-epld.{version}.img` (e.g., `n9000-epld.9.3.16.img`)

**Automatic Platform Selection**:
The system automatically detects device models and selects appropriate firmware patterns:
```yaml
# Platform detection patterns in group_vars/cisco_nxos.yml
device_model_patterns:
  - { regex: "N9K-C923.*", platform: "nexus_9000", model_prefix: "N9K-C923" }
  - { regex: "N3K-C354.*", platform: "nexus_3000", model_prefix: "N3K-C354" }
  - { regex: "N7K-C70.*", platform: "nexus_7000", model_prefix: "N7K-C70" }

# Firmware filename resolution
firmware_filename_patterns:
  nexus_9000:
    N9K-C92384: "nxos64-cs.{{ target_version }}.M.bin"
    N9K-C93180: "nxos64-cs.{{ target_version }}.M.bin"
    default: "nxos64-cs.{{ target_version }}.M.bin"
  nexus_3000:
    N3K-C3548: "nxos64-msll.{{ target_version }}.M.bin"
    default: "n3000-uk9.{{ target_version }}.bin"
```

**Key Characteristics**:
- Uses standard SSH/SCP file transfer
- Supports large firmware files (up to 8GB)
- Files stored in bootflash: filesystem
- Verification via SHA512 hash comparison
- Requires SSH service enabled on device
- **Automatic platform-specific firmware selection** based on device model detection

**Upgrade Mechanism**:
- ISSU (In-Service Software Upgrade) for compatible models
- Traditional disruptive upgrade for older models
- Boot variable modification for next reboot
- **EPLD upgrade support** with disruptive/non-disruptive options

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

**Platform-Specific Firmware Patterns**:
- **Catalyst 9000 Series**: `cat9k_iosxe.{version}.SPA.bin` (e.g., `cat9k_iosxe.17.15.03a.SPA.bin`)
- **Catalyst 9200/9300**: `cat9k_lite_iosxe.{version}.SPA.bin` (e.g., `cat9k_lite_iosxe.17.15.03a.SPA.bin`)
- **Catalyst 8500L**: `c8000aes-universalk9.{version}.SPA.bin` (e.g., `c8000aes-universalk9.17.15.03a.SPA.bin`)
- **ISR 4000 Series**: `isr4300-universalk9_ias.{version}.SPA.bin` (e.g., `isr4300-universalk9_ias.17.15.03a.SPA.bin`)
- **ASR 1000 Series**: `asr1000rp3-adventerprisek9.{version}.SPA.bin`

**Automatic Platform Selection**:
The system detects hardware platforms and selects appropriate firmware:
```yaml
# Platform detection in group_vars/cisco_iosxe.yml
device_model_patterns:
  - { regex: "C92.*", platform: "catalyst_9000", model_prefix: "C92" }
  - { regex: "C85.*", platform: "catalyst_8000", model_prefix: "C85" }
  - { regex: "ISR43.*", platform: "isr_4000", model_prefix: "ISR43" }

# Hardware-specific firmware patterns
firmware_filename_patterns:
  catalyst_9000:
    C9200: "cat9k_lite_iosxe.{{ target_version }}.SPA.bin"
    C9400: "cat9k_iosxe.{{ target_version }}.SPA.bin"
  catalyst_8000:
    C8500L: "c8000aes-universalk9.{{ target_version }}.SPA.bin"
```

**Key Characteristics**:
- Primary: SCP for large files
- Fallback: HTTP/HTTPS for smaller files
- Install mode vs. bundle mode support
- Flash filesystem management
- Space validation before transfer
- **Hardware-specific firmware selection** based on device model detection

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

**Platform-Specific Firmware Patterns**:
- **CM7100 (Legacy Console Manager)**: `cm71xx-{version}.flash` (e.g., `cm71xx-5.2.4.flash`)
- **IM7200 (Legacy Infrastructure Manager)**: `im72xx-{version}.flash` (e.g., `im72xx-5.2.4.flash`)
- **CM8100 (Modern Console Manager)**: `console_manager-{version}-production-signed.raucb` (e.g., `console_manager-25.07.0-production-signed.raucb`)
- **OM2100/OM2200 (Operations Manager)**: `operations_manager-{version}-production-signed.raucb` (e.g., `operations_manager-25.07.0-production-signed.raucb`)

**Automatic Model Detection**:
The system detects device models and selects appropriate firmware patterns:
```yaml
# Platform detection in group_vars/opengear.yml
device_model_patterns:
  - { regex: "CM71.*", platform: "console_manager_legacy", model_prefix: "CM71" }
  - { regex: "CM81.*", platform: "console_manager_modern", model_prefix: "CM81" }
  - { regex: "OM2[12].*", platform: "operations_manager", model_prefix: "OM2" }
  - { regex: "IM72.*", platform: "infrastructure_manager", model_prefix: "IM72" }

# Model-specific firmware patterns
firmware_filename_patterns:
  console_manager_legacy:
    CM7100: "cm71xx-{{ target_version }}.flash"
  console_manager_modern:
    CM8100: "console_manager-{{ target_version }}-production-signed.raucb"
  operations_manager:
    OM2100: "operations_manager-{{ target_version }}-production-signed.raucb"
    OM2200: "operations_manager-{{ target_version }}-production-signed.raucb"
```

**Key Characteristics**:
- Legacy devices: `netflash` command (.flash files)
- Modern devices: `puginstall` command (.raucb files)
- Files must be pre-staged in `/tmp` or mounted storage
- Architecture-specific command sets
- **Model-specific firmware patterns** with different naming conventions

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

### Authentication Configuration Examples

#### SSH Key Configuration (Cisco Platforms, Metamako, Opengear)
```yaml
# In Ansible Vault (ansible-content/inventory/vault.yml)
vault_cisco_nxos_ssh_key: "/path/to/nxos-device-key"
vault_cisco_iosxe_ssh_key: "/path/to/iosxe-device-key"
vault_metamako_ssh_key: "/path/to/metamako-device-key"
vault_opengear_ssh_key: "/path/to/opengear-device-key"

# Group vars automatically prefer SSH keys over passwords
ansible_ssh_private_key_file: "{{ vault_cisco_nxos_ssh_key | default(omit) }}"
ansible_password: "{{ vault_cisco_nxos_password | default(omit) }}"
```

#### API Token Configuration (FortiOS, Opengear)
```yaml
# In Ansible Vault
vault_fortios_api_token: "your-fortios-api-token-here"
vault_opengear_api_token: "your-opengear-api-token-here"

# FortiOS HTTPS API configuration
ansible_httpapi_key: "{{ vault_fortios_api_token | default(omit) }}"
ansible_password: "{{ vault_fortios_password | default(omit) }}"

# Opengear API token for REST API calls
opengear_api_token: "{{ vault_opengear_api_token | default(omit) }}"
```

### Security Best Practices by Platform

| Platform | **Primary Security Configuration** | **Fallback Configuration** |
|----------|-----------------------------------|---------------------------|
| **Cisco NX-OS** | SSH keys, secure ciphers, public key authentication | Username/password with secure SSH |
| **Cisco IOS-XE** | SSH keys, secure file transfer settings | Username/password with secure SSH |
| **FortiOS** | API tokens, HTTPS admin access, secure API sessions | Username/password with HTTPS |
| **Opengear** | SSH keys + API tokens, secure CLI/API access | Username/password authentication |
| **Metamako MOS** | SSH keys, secure file transfer | Username/password with secure SSH |

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
scp nxos64-cs.10.4.5.M.bin admin@device-ip:bootflash:/
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
# Check device architecture and model
ssh root@device-ip "cat /etc/opengear-release"
ssh root@device-ip "show system info | grep Model"

# Verify available space
ssh root@device-ip "df -h /tmp"

# Test firmware staging (examples by model)
# For CM7100 legacy:
scp cm71xx-5.2.4.flash root@device-ip:/tmp/
# For CM8100 modern:
scp console_manager-25.07.0-production-signed.raucb root@device-ip:/tmp/
# For OM2100/OM2200:
scp operations_manager-25.07.0-production-signed.raucb root@device-ip:/tmp/
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

*This guide is part of the Network Device Upgrade System documentation. For related information, see [upgrade-workflow-guide.md](upgrade-workflow-guide.md) and [platform-implementation-status.md](platform-implementation-status.md).*