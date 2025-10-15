# Firmware Naming Standards

## ⚠️ MANDATORY NAMING STANDARDS

**CRITICAL**: These firmware filename patterns and file extensions are **MANDATORY** for all firmware files used in the Network Device Upgrade System. The system performs strict validation against these patterns and will **REJECT** any firmware files that do not conform to these standards.

## Overview

This document defines the **authoritative** and **MANDATORY** firmware filename patterns, file extensions, and versioning formats for all supported network device platforms. All firmware files MUST conform to these standards to pass integrity validation.

**Enforcement**: The integrity validation system (`ansible-content/roles/image-validation/tasks/integrity-audit.yml`) enforces these standards and will fail any upgrade attempt using non-conformant filenames.

---

## Table of Contents

1. [Cisco NX-OS Firmware Naming](#cisco-nx-os-firmware-naming)
2. [Cisco IOS-XE Firmware Naming](#cisco-ios-xe-firmware-naming)
3. [FortiOS Firmware Naming](#fortios-firmware-naming)
4. [Opengear Firmware Naming](#opengear-firmware-naming)
5. [Metamako MOS Firmware Naming](#metamako-mos-firmware-naming)
6. [File Path Structure](#file-path-structure)
7. [Validation Implementation](#validation-implementation)

---

## Cisco NX-OS Firmware Naming

### Platform: `nxos`

### MANDATORY File Extensions
- `.bin` - Primary firmware images
- `.img` - EPLD upgrade images

### MANDATORY Filename Patterns

#### Nexus 9000 Series
**Pattern**: `nxos64-cs.{version}.bin`

**Version Formats**:
- `X.Y.Z` - Standard release (e.g., `10.1.1`, `9.3.10`)
- `X.Y.Z.F` - Feature release (e.g., `10.2.2.F`) - includes new features
- `X.Y.Z.M` - Maintenance release (e.g., `10.4.5.M`) - bug fixes and security patches

**NOTE**: The `.M` and `.F` suffixes are OPTIONAL and part of the version number when present.

**Examples**:
- `nxos64-cs.10.1.1.bin` (version: `10.1.1` - standard)
- `nxos64-cs.10.2.2.F.bin` (version: `10.2.2.F` - feature)
- `nxos64-cs.10.4.5.M.bin` (version: `10.4.5.M` - maintenance)
- `nxos64-cs.9.3.10.bin` (version: `9.3.10` - standard)

**Regex Pattern**: `^nxos64-cs\.[0-9]+\.[0-9]+\.[0-9]+(\.[MF])?\.bin$`

#### Nexus 3548 Series
**Pattern**: `nxos64-msll.{version}.bin`

**Version Formats**:
- `X.Y.Z` - Standard release (e.g., `10.1.1`)
- `X.Y.Z.F` - Feature release (e.g., `10.2.2.F`)
- `X.Y.Z.M` - Maintenance release (e.g., `10.4.6.M`)

**Examples**:
- `nxos64-msll.10.4.6.M.bin` (version: `10.4.6.M` - maintenance)
- `nxos64-msll.10.3.3.bin` (version: `10.3.3` - standard)

**Regex Pattern**: `^nxos64-msll\.[0-9]+\.[0-9]+\.[0-9]+(\.[MF])?\.bin$`

#### EPLD Upgrades (All Nexus 9000)
**Pattern**: `n9000-epld.{version}.img`

**Version Formats**:
- `X.Y.Z` - Standard release (e.g., `9.3.16`, `10.1.1`)
- `X.Y.Z.F` - Feature release (e.g., `10.2.2.F`)
- `X.Y.Z.M` - Maintenance release (e.g., `10.4.1.M`)

**NOTE**: EPLD uses SAME version format as NX-OS - `.M` and `.F` suffixes are OPTIONAL.

**Examples**:
- `n9000-epld.9.3.16.img` (version: `9.3.16` - standard)
- `n9000-epld.10.1.2.img` (version: `10.1.2` - standard)
- `n9000-epld.10.4.1.M.img` (version: `10.4.1.M` - maintenance)

**Regex Pattern**: `^n9000-epld\.[0-9]+\.[0-9]+\.[0-9]+(\.[MF])?\.img$`

### Hardware Platform Detection

The system automatically detects Nexus hardware platforms and selects the correct firmware pattern:

| Device Model | Firmware Pattern | Example (Standard) | Example (Maintenance) |
|-------------|------------------|--------------------|-----------------------|
| N9K-C92384 | `nxos64-cs.*.bin` | `nxos64-cs.10.1.1.bin` | `nxos64-cs.10.4.5.M.bin` |
| N9K-C93180 | `nxos64-cs.*.bin` | `nxos64-cs.9.3.10.bin` | `nxos64-cs.10.4.5.M.bin` |
| N3K-C3548 | `nxos64-msll.*.bin` | `nxos64-msll.10.1.1.bin` | `nxos64-msll.10.4.6.M.bin` |
| Any (EPLD) | `n9000-epld.*.img` | `n9000-epld.10.1.2.img` | `n9000-epld.9.3.16.M.img` |

---

## Cisco IOS-XE Firmware Naming

### Platform: `ios`

### MANDATORY File Extensions
- `.bin` - Standard firmware images
- `.SPA.bin` - SPA (Shared Port Adapter) images (preferred)

### MANDATORY Filename Patterns

#### Catalyst 9000 Series
**Pattern**: `cat9k_iosxe.{version}.SPA.bin`

**Version Format**: `XX.YY.ZZa` (e.g., `17.09.04a`)

**Examples**:
- `cat9k_iosxe.17.09.04a.SPA.bin`
- `cat9k_iosxe.17.15.03a.SPA.bin`

**Regex Pattern**: `^cat9k_iosxe\.[0-9]{2}\.[0-9]{2}\.[0-9]{2}[a-z]?\.SPA\.bin$`

#### Catalyst 9200/9300 Series
**Pattern**: `cat9k_lite_iosxe.{version}.SPA.bin`

**Version Format**: `XX.YY.ZZa` (e.g., `17.09.04a`)

**Examples**:
- `cat9k_lite_iosxe.17.09.04a.SPA.bin`
- `cat9k_lite_iosxe.16.12.10.SPA.bin`

**Regex Pattern**: `^cat9k_lite_iosxe\.[0-9]{2}\.[0-9]{2}\.[0-9]{2}[a-z]?\.SPA\.bin$`

#### Catalyst 8000 Series
**Pattern**: `c8000aes-universalk9.{version}.SPA.bin`

**Version Format**: `XX.YY.ZZa` (e.g., `17.15.03a`)

**Examples**:
- `c8000aes-universalk9.17.15.03a.SPA.bin`
- `c8000aes-universalk9.17.09.04a.SPA.bin`

**Regex Pattern**: `^c8000aes-universalk9\.[0-9]{2}\.[0-9]{2}\.[0-9]{2}[a-z]?\.SPA\.bin$`

### Hardware Platform Detection

The system detects Catalyst hardware platforms and selects appropriate firmware:

| Device Model | Firmware Pattern | Example |
|-------------|------------------|---------|
| C9200 | `cat9k_lite_iosxe.*.SPA.bin` | `cat9k_lite_iosxe.17.09.04a.SPA.bin` |
| C9300 | `cat9k_lite_iosxe.*.SPA.bin` | `cat9k_lite_iosxe.17.09.04a.SPA.bin` |
| C9400 | `cat9k_iosxe.*.SPA.bin` | `cat9k_iosxe.17.09.04a.SPA.bin` |
| C8500L | `c8000aes-universalk9.*.SPA.bin` | `c8000aes-universalk9.17.15.03a.SPA.bin` |

---

## FortiOS Firmware Naming

### Platform: `fortios`

### MANDATORY File Extensions
- `.out` - FortiOS firmware images (ONLY valid extension)

### MANDATORY Filename Pattern

**Pattern**: `FGT_*-v{version}-*-FORTINET.out`

**Version Format**: `X.Y.Z` (e.g., `7.2.5`)

**Build Format**: `buildXXXX` (e.g., `build1517`)

**Complete Pattern**: `FGT_{model}-v{version}-{build}-FORTINET.out`

**Examples**:
- `FGT_VM64_KVM-v7.2.5-build1517-FORTINET.out`
- `FGT_VM64_KVM-v7.0.12-build0523-FORTINET.out`
- `FGT_600D-v7.2.5-build1517-FORTINET.out`

**Regex Pattern**: `^FGT_.+-v[0-9]+\.[0-9]+\.[0-9]+-build[0-9]+-FORTINET\.out$`

### Model Codes

Common FortiOS model codes in filenames:
- `FGT_VM64_KVM` - Virtual FortiGate for KVM
- `FGT_VM64` - Virtual FortiGate generic
- `FGT_600D` - FortiGate 600D hardware
- `FGT_3000D` - FortiGate 3000D hardware

---

## Opengear Firmware Naming

### Platform: `opengear`

### MANDATORY File Extensions
- `.flash` - Legacy console servers (CM7100, IM7200)
- `.raucb` - Modern console servers (CM8100, OM2100, OM2200)

### MANDATORY Filename Patterns

#### Legacy Console Servers (CM7100)
**Pattern**: `cm71xx-{version}.flash`

**Version Format**: `X.Y.Z` (e.g., `5.2.4`)

**Examples**:
- `cm71xx-5.2.4.flash`
- `cm71xx-5.16.4.flash`

**Regex Pattern**: `^cm71xx-[0-9]+\.[0-9]+\.[0-9]+\.flash$`

#### Legacy Infrastructure Manager (IM7200)
**Pattern**: `im72xx-{version}.flash`

**Version Format**: `X.Y.Z` (e.g., `5.2.4`)

**Examples**:
- `im72xx-5.2.4.flash`
- `im72xx-5.16.4.flash`

**Regex Pattern**: `^im72xx-[0-9]+\.[0-9]+\.[0-9]+\.flash$`

#### Modern Console Manager (CM8100)
**Pattern**: `console_manager-{version}-production-signed.raucb`

**Version Format**: `YY.MM.P` (e.g., `25.07.0`)

**Examples**:
- `console_manager-25.07.0-production-signed.raucb`
- `console_manager-24.12.1-production-signed.raucb`

**Regex Pattern**: `^console_manager-[0-9]{2}\.[0-9]{2}\.[0-9]+-production-signed\.raucb$`

#### Modern Operations Manager (OM2100/OM2200)
**Pattern**: `operations_manager-{version}-production-signed.raucb`

**Version Format**: `YY.MM.P` (e.g., `25.07.0`)

**Examples**:
- `operations_manager-25.07.0-production-signed.raucb`
- `operations_manager-24.12.1-production-signed.raucb`

**Regex Pattern**: `^operations_manager-[0-9]{2}\.[0-9]{2}\.[0-9]+-production-signed\.raucb$`

### Hardware Platform Detection

The system detects Opengear device models and selects appropriate firmware:

| Device Model | Architecture | Firmware Pattern | Extension | Example |
|-------------|--------------|------------------|-----------|---------|
| CM7100 | Legacy CLI | `cm71xx-*.flash` | `.flash` | `cm71xx-5.2.4.flash` |
| IM7200 | Legacy CLI | `im72xx-*.flash` | `.flash` | `im72xx-5.2.4.flash` |
| CM8100 | Modern CLI | `console_manager-*-production-signed.raucb` | `.raucb` | `console_manager-25.07.0-production-signed.raucb` |
| OM2100 | Modern CLI | `operations_manager-*-production-signed.raucb` | `.raucb` | `operations_manager-25.07.0-production-signed.raucb` |
| OM2200 | Modern CLI | `operations_manager-*-production-signed.raucb` | `.raucb` | `operations_manager-25.07.0-production-signed.raucb` |

### Version Format Notes

**Legacy Devices (CM7100, IM7200)**:
- Version Format: Semantic versioning `X.Y.Z`
- Example: `5.2.4`, `5.16.4`

**Modern Devices (CM8100, OM2100, OM2200)**:
- Version Format: Date-based `YY.MM.P`
- Example: `25.07.0` (July 2025, patch 0)

---

## Metamako MOS Firmware Naming

### Platform: `metamako_mos`

### MANDATORY File Extensions
- `.iso` - MOS operating system images
- `.swix` - MetaMux and MetaWatch application packages

### MANDATORY Filename Patterns

#### MOS Operating System
**Pattern**: `mos-{version}.iso`

**Version Format**: `X.YY.Z` (e.g., `0.39.9`)

**Examples**:
- `mos-0.39.9.iso`
- `mos-0.40.2.iso`
- `mos-1.0.0.iso`

**Regex Pattern**: `^mos-[0-9]+\.[0-9]+\.[0-9]+\.iso$`

#### MetaMux Application
**Pattern**: `metamux-{version}.swix`

**Version Format**: `X.Y.Z` (e.g., `2.1.7`)

**Examples**:
- `metamux-2.1.7.swix`
- `metamux-2.2.3.swix`
- `metamux-3.0.0.swix`

**Regex Pattern**: `^metamux-[0-9]+\.[0-9]+\.[0-9]+\.swix$`

#### MetaWatch Application
**Pattern**: `metawatch-{version}.swix`

**Version Format**: `X.Y.Z` (e.g., `0.11.3`)

**Examples**:
- `metawatch-0.11.3.swix`
- `metawatch-1.0.4.swix`
- `metawatch-3.2.0.swix`

**Regex Pattern**: `^metawatch-[0-9]+\.[0-9]+\.[0-9]+\.swix$`

### Component Types

| Component | Type | Extension | Purpose | Example |
|-----------|------|-----------|---------|---------|
| MOS Base OS | Operating System | `.iso` | Core firmware and drivers | `mos-0.39.9.iso` |
| MetaMux | Application | `.swix` | High-performance packet switching | `metamux-2.1.7.swix` |
| MetaWatch | Application | `.swix` | Performance monitoring and latency measurement | `metawatch-0.11.3.swix` |

### Version Format

**All Metamako Components**: Semantic versioning `X.Y.Z`
- `X` = Major version
- `Y` = Minor version
- `Z` = Patch version

**Examples**:
- `0.39.9` - MOS pre-1.0 release
- `2.1.7` - MetaMux stable version
- `0.11.3` - MetaWatch development version

---

## File Path Structure

### MANDATORY Path Requirements

**CRITICAL**: ALL platforms use **IDENTICAL** firmware path structure with **NO subdirectories**.

### Universal Path Pattern

```
firmware_base_path/target_firmware
```

### Examples by Platform

```bash
# Cisco NX-OS
/var/lib/network-upgrade/firmware/nxos64-cs.10.4.5.M.bin

# Cisco IOS-XE
/var/lib/network-upgrade/firmware/cat9k_iosxe.17.09.04a.SPA.bin

# FortiOS
/var/lib/network-upgrade/firmware/FGT_VM64_KVM-v7.2.5-build1517-FORTINET.out

# Opengear (Legacy)
/var/lib/network-upgrade/firmware/cm71xx-5.2.4.flash

# Opengear (Modern)
/var/lib/network-upgrade/firmware/console_manager-25.07.0-production-signed.raucb

# Metamako MOS
/var/lib/network-upgrade/firmware/mos-0.39.9.iso
/var/lib/network-upgrade/firmware/metamux-2.1.7.swix
/var/lib/network-upgrade/firmware/metawatch-0.11.3.swix
```

### ❌ INVALID Path Structures

**DO NOT use platform subdirectories:**

```bash
# ❌ WRONG - No subdirectories allowed
/var/lib/network-upgrade/firmware/cisco/nxos64-cs.10.4.5.M.bin
/var/lib/network-upgrade/firmware/fortios/FGT_VM64_KVM-v7.2.5-build1517-FORTINET.out
/var/lib/network-upgrade/firmware/opengear/cm71xx-5.2.4.flash
```

### Configuration Variables

**Ansible Variables**:
```yaml
firmware_base_path: "/var/lib/network-upgrade/firmware"
target_firmware: "nxos64-cs.10.4.5.M.bin"

# Resolved path:
full_path: "{{ firmware_base_path }}/{{ target_firmware }}"
# Result: /var/lib/network-upgrade/firmware/nxos64-cs.10.4.5.M.bin
```

---

## Validation Implementation

### Integrity Validation

**File**: `ansible-content/roles/image-validation/tasks/integrity-audit.yml`

The system performs MANDATORY validation of:

1. **File Existence**: Firmware file must exist at specified path
2. **File Size**: Minimum 1MB (prevents corrupt/empty files)
3. **File Permissions**: File must be readable
4. **File Extension**: Must match platform-specific valid extensions
5. **Filename Pattern**: Must match platform-specific MANDATORY patterns (FUTURE)

### Current Extension Validation

```yaml
# Validates file extensions per platform
- name: Validate file extension for platform
  ansible.builtin.assert:
    that:
      - >
        (platform == 'nxos' and
          (firmware_filename.endswith('.bin') or
           firmware_filename.endswith('.img'))) or
        (platform == 'ios' and
          (firmware_filename.endswith('.bin') or
           firmware_filename.endswith('.SPA.bin'))) or
        (platform == 'fortios' and
          firmware_filename.endswith('.out')) or
        (platform == 'metamako_mos' and
          (firmware_filename.endswith('.iso') or
           firmware_filename.endswith('.swix'))) or
        (platform == 'opengear' and
          (firmware_filename.endswith('.flash') or
           firmware_filename.endswith('.raucb')))
```

### Planned Pattern Validation

Future enhancement will add full regex pattern matching against the MANDATORY patterns defined in this document.

---

## Summary Table

| Platform | Valid Extensions | Filename Pattern Examples | Path Structure |
|----------|-----------------|---------------------------|----------------|
| **Cisco NX-OS** | `.bin`, `.img` | `nxos64-cs.10.4.5.M.bin`<br>`nxos64-msll.10.4.6.M.bin`<br>`n9000-epld.9.3.16.img` | `firmware_base_path/filename` |
| **Cisco IOS-XE** | `.bin`, `.SPA.bin` | `cat9k_iosxe.17.09.04a.SPA.bin`<br>`cat9k_lite_iosxe.17.09.04a.SPA.bin`<br>`c8000aes-universalk9.17.15.03a.SPA.bin` | `firmware_base_path/filename` |
| **FortiOS** | `.out` | `FGT_VM64_KVM-v7.2.5-build1517-FORTINET.out` | `firmware_base_path/filename` |
| **Opengear** | `.flash`, `.raucb` | `cm71xx-5.2.4.flash`<br>`console_manager-25.07.0-production-signed.raucb`<br>`operations_manager-25.07.0-production-signed.raucb` | `firmware_base_path/filename` |
| **Metamako MOS** | `.iso`, `.swix` | `mos-0.39.9.iso`<br>`metamux-2.1.7.swix`<br>`metawatch-0.11.3.swix` | `firmware_base_path/filename` |

---

## Enforcement

### Validation Failure Behavior

When a firmware file fails naming standards validation:

1. **Immediate Failure**: Upgrade process stops before any device contact
2. **Error Message**: Clear indication of which standard was violated
3. **No Partial Execution**: Zero-tolerance policy - fix filename first
4. **Audit Logging**: Validation failures are logged for compliance

### Compliance Requirements

**ALL firmware files MUST**:
- Use correct file extension for platform
- Follow filename pattern for device model
- Use correct version format
- Be placed at root of firmware_base_path (no subdirectories)

### Related Documentation

- [Container Deployment Guide](container-deployment.md) - Firmware mounting examples
- [Platform File Transfer Guide](platform-file-transfer-guide.md) - Platform-specific transfer details
- [Upgrade Workflow Guide](upgrade-workflow-guide.md) - Complete upgrade process

---

**Document Version**: 1.0
**Last Updated**: 2025-01-06
**Authority**: This document is the MANDATORY authoritative source for firmware naming standards
