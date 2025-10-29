# Container Deployment Guide

This guide provides instructions for deploying the Network Device Upgrade System container with Docker or Podman.

## Quick Start

### Docker
```bash
# Pull the latest image
docker pull ghcr.io/garryshtern/network-device-upgrade-system:latest

# Display help
docker run --rm ghcr.io/garryshtern/network-device-upgrade-system:latest help

# Test syntax
docker run --rm ghcr.io/garryshtern/network-device-upgrade-system:latest syntax-check
```

### Podman (Recommended for RHEL8/9)
```bash
# Pull the latest image
podman pull ghcr.io/garryshtern/network-device-upgrade-system:latest

# Display help
podman run --rm ghcr.io/garryshtern/network-device-upgrade-system:latest help
```

## Environment Variables Reference

### Required Variables
- `MAX_CONCURRENT` - **REQUIRED**: Number of devices to upgrade in parallel (e.g., 5)
  - Must be provided as `-e MAX_CONCURRENT=5`
  - The 'serial' keyword is processed before group_vars are loaded
- `TARGET_HOSTS` - Hosts to target (requires INVENTORY_FILE)
- `TARGET_FIRMWARE` - Firmware version/filename to install
- `INVENTORY_FILE` - Path to inventory file (required when using TARGET_HOSTS)

### Upgrade Configuration
- `UPGRADE_PHASE` - Phase: full, loading, installation, validation, rollback
- `MAINTENANCE_WINDOW` - Set to 'true' for installation phase (default: false)

### SSH Key Authentication (Preferred)
- `CISCO_NXOS_SSH_KEY` - SSH private key path for Cisco NX-OS
- `CISCO_IOSXE_SSH_KEY` - SSH private key path for Cisco IOS-XE
- `OPENGEAR_SSH_KEY` - SSH private key path for Opengear
- `METAMAKO_SSH_KEY` - SSH private key path for Metamako

### API Token Authentication
- `FORTIOS_API_TOKEN` - API token for FortiOS devices
- `OPENGEAR_API_TOKEN` - API token for Opengear REST API

### Password Authentication (Fallback)
- `CISCO_NXOS_PASSWORD` - Password for Cisco NX-OS
- `CISCO_IOSXE_PASSWORD` - Password for Cisco IOS-XE
- `FORTIOS_PASSWORD` - Password for FortiOS
- `OPENGEAR_PASSWORD` - Password for Opengear
- `METAMAKO_PASSWORD` - Password for Metamako

### Username Configuration
- `CISCO_NXOS_USERNAME` - Username for Cisco NX-OS
- `CISCO_IOSXE_USERNAME` - Username for Cisco IOS-XE
- `FORTIOS_USERNAME` - Username for FortiOS
- `OPENGEAR_USERNAME` - Username for Opengear
- `METAMAKO_USERNAME` - Username for Metamako

### Debug Configuration
- `SHOW_DEBUG` - Enable verbose debug output (true/false, default: false)
  - Only set when explicitly 'true' - passes through to Ansible with | bool filter

### Workflow Step Control
- `ANSIBLE_TAGS` - Run individual workflow steps with automatic dependency resolution
  - Single step: `step1`, `step5`, `step6`, `step8`, etc.
  - Multiple steps: `step1,step5` (comma-separated)
  - Supported tags: `step1-step8`, `connectivity`, `version_check`, `space_check`, `image_upload`, `config_backup`, `pre_validation`, `install`, `reboot`, `post_validation`, `emergency_rollback`
  - New dependency model: Each step depends directly on step1 only; main workflow orchestrates full dependencies via tags
  - Example: Running `step6` ensures main workflow executes steps 1-6 in order
  - Leave unset to run full workflow

### Platform-Specific Upgrade Features
- `TARGET_EPLD_FIRMWARE` - EPLD firmware filename (Cisco NX-OS only)
  - If provided, **automatically enables EPLD upgrade** (unless `ENABLE_EPLD_UPGRADE=false`)
  - Example: `n9000-epld.10.1.2.img`
- `ENABLE_EPLD_UPGRADE` - Enable/disable EPLD firmware upgrades (Cisco NX-OS only, default: auto)
  - Set to `true` to explicitly enable EPLD upgrade
  - Set to `false` to **disable EPLD upgrade** (overrides `TARGET_EPLD_FIRMWARE`)
  - Leave unset to auto-enable if `TARGET_EPLD_FIRMWARE` is provided (recommended)
- `INSTALL_COMBINED_MODE` - Install firmware + EPLD in single operation for faster upgrade (Cisco NX-OS only, default: false)
  - Only effective when EPLD upgrade is enabled
  - If false, uses sequential mode (firmware first, then EPLD after reboot)
  - Only set when explicitly 'true'
- `ALLOW_DISRUPTIVE_EPLD` - Allow disruptive EPLD upgrades without dual supervisors (Cisco NX-OS only, default: false)
  - Only effective when EPLD upgrade is enabled
  - Only set when explicitly 'true'
- `MULTI_STEP_UPGRADE_REQUIRED` - Enable multi-step upgrade mode (FortiOS only, default: false)
  - Required for major version jumps (e.g., 6.x to 7.x)
  - Only set when explicitly 'true'
  - Use with `UPGRADE_PATH` to specify intermediate versions

### Firmware Image Management
- `FIRMWARE_BASE_PATH` - Base directory for firmware images (default: /var/lib/network-upgrade/firmware)
- `BACKUP_BASE_PATH` - Base directory for configuration backups (default: /var/lib/network-upgrade/backups)

## Usage Examples

### Basic Dry Run
```bash
docker run --rm \
  -v ./inventory:/opt/inventory:ro \
  -v ./firmware:/var/lib/network-upgrade/firmware:ro \
  -e INVENTORY_FILE=/opt/inventory/hosts.yml \
  -e MAX_CONCURRENT=5 \
  -e TARGET_HOSTS=cisco-switches \
  -e TARGET_FIRMWARE=nxos64-cs.10.4.5.M.bin \
  -e CISCO_NXOS_SSH_KEY=/keys/cisco-key \
  ghcr.io/garryshtern/network-device-upgrade-system:latest dry-run
```

### Production Upgrade with Maintenance Window
```bash
docker run --rm \
  -v /opt/inventory:/opt/inventory:ro \
  -v /opt/firmware:/var/lib/network-upgrade/firmware:ro \
  -v /opt/backups:/var/lib/network-upgrade/backups \
  -v /opt/secrets/ssh-keys:/keys:ro \
  -e INVENTORY_FILE=/opt/inventory/production.yml \
  -e MAX_CONCURRENT=5 \
  -e TARGET_HOSTS=datacenter-switches \
  -e TARGET_FIRMWARE=nxos64-cs.10.4.5.M.bin \
  -e MAINTENANCE_WINDOW=true \
  -e CISCO_NXOS_SSH_KEY=/keys/cisco-nxos-key \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

### FortiOS Multi-Step Upgrade
```bash
docker run --rm \
  -v /opt/inventory:/opt/inventory:ro \
  -v /opt/firmware:/var/lib/network-upgrade/firmware:ro \
  -e INVENTORY_FILE=/opt/inventory/hosts.yml \
  -e MAX_CONCURRENT=5 \
  -e TARGET_HOSTS=fortinet-firewalls \
  -e TARGET_FIRMWARE=7.2.5 \
  -e MULTI_STEP_UPGRADE_REQUIRED=true \
  -e UPGRADE_PATH="6.4.8,7.0.12,7.2.5" \
  -e MAINTENANCE_WINDOW=true \
  -e FORTIOS_API_TOKEN="$(cat ~/.secrets/fortios-token)" \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

### Cisco NX-OS with EPLD Upgrade (Auto-Enabled)
```bash
docker run --rm \
  -v /opt/inventory:/opt/inventory:ro \
  -v /opt/firmware:/var/lib/network-upgrade/firmware:ro \
  -v /opt/secrets/ssh-keys:/keys:ro \
  -e INVENTORY_FILE=/opt/inventory/hosts.yml \
  -e MAX_CONCURRENT=5 \
  -e TARGET_HOSTS=nexus-switches \
  -e TARGET_FIRMWARE=nxos64-cs.10.4.5.M.bin \
  -e TARGET_EPLD_FIRMWARE=n9000-epld.10.1.2.img \
  -e MAINTENANCE_WINDOW=true \
  -e CISCO_NXOS_SSH_KEY=/keys/cisco-nxos-key \
  -e ALLOW_DISRUPTIVE_EPLD=true \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```
**Note:** EPLD upgrade is automatically enabled because `TARGET_EPLD_FIRMWARE` is provided. No need to set `ENABLE_EPLD_UPGRADE=true`.

### Podman with SELinux (RHEL8/9)
```bash
podman run --rm \
  -v /opt/inventory:/opt/inventory:ro,Z \
  -v /opt/firmware:/var/lib/network-upgrade/firmware:ro,Z \
  -v /opt/secrets/ssh-keys:/keys:ro,Z \
  -e INVENTORY_FILE=/opt/inventory/hosts.yml \
  -e MAX_CONCURRENT=5 \
  -e TARGET_HOSTS=cisco-switches \
  -e TARGET_FIRMWARE=nxos64-cs.10.4.5.M.bin \
  -e CISCO_NXOS_SSH_KEY=/keys/cisco-key \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

## Running Individual Workflow Steps

The container supports running individual workflow steps using the `ANSIBLE_TAGS` environment variable, providing the same flexibility as bare-metal deployments with automatic dependency resolution.

### Workflow Steps Overview

The upgrade workflow is divided into 7 distinct steps:

1. **STEP 1: Connectivity & Version Check** - Verify device access and current firmware version
2. **STEP 2: Disk Space Check & Hash Verification** - Ensure sufficient storage and validate firmware integrity
3. **STEP 3: Firmware Image Upload** - Transfer firmware to devices (skipped if already present)
4. **STEP 4: Configuration Backup** - Backup running configuration before changes
5. **STEP 5: Pre-Upgrade Network Validation** - Baseline network state (BGP, OSPF, interfaces, routing)
6. **STEP 6: Firmware Installation & Reboot** - Install firmware and reboot devices (requires `MAINTENANCE_WINDOW=true`)
7. **STEP 7: Post-Upgrade Network Validation** - Compare post-upgrade state against baseline

### Automatic Dependency Resolution

When you run a specific step, all prerequisite steps execute automatically:

- Running `step6` automatically executes `step1`, `step2`, `step3`, `step4`, and `step5` first
- Running `step5` automatically executes `step1`, `step2`, `step3`, and `step4` first
- Running `step1` executes only connectivity and version checks
- Running `step7` executes standalone (requires `step5` baseline from previous run)

### Docker Examples

#### Step 1: Connectivity Check Only
```bash
# Verify device connectivity and firmware version
docker run --rm \
  -v ./inventory:/opt/inventory:ro \
  -v ./keys:/keys:ro \
  -e INVENTORY_FILE=/opt/inventory/hosts.yml \
  -e ANSIBLE_TAGS=step1 \
  -e TARGET_HOSTS=cisco-switch-01 \
  -e MAX_CONCURRENT=5 \
  -e CISCO_NXOS_SSH_KEY=/keys/cisco-key \
  ghcr.io/garryshtern/network-device-upgrade-system:latest dry-run
```

#### Step 2: Disk Space and Hash Verification
```bash
# Check storage capacity and verify firmware hash (auto-runs step1)
docker run --rm \
  -v ./inventory:/opt/inventory:ro \
  -v ./firmware:/var/lib/network-upgrade/firmware:ro \
  -v ./keys:/keys:ro \
  -e INVENTORY_FILE=/opt/inventory/hosts.yml \
  -e ANSIBLE_TAGS=step2 \
  -e TARGET_FIRMWARE=nxos.10.2.3.bin \
  -e TARGET_HOSTS=cisco-switch-01 \
  -e MAX_CONCURRENT=5 \
  -e CISCO_NXOS_SSH_KEY=/keys/cisco-key \
  ghcr.io/garryshtern/network-device-upgrade-system:latest dry-run
```

#### Step 4: Configuration Backup Only
```bash
# Backup device configurations (auto-runs steps 1-3)
docker run --rm \
  -v ./inventory:/opt/inventory:ro \
  -v ./firmware:/var/lib/network-upgrade/firmware:ro \
  -v ./backups:/var/lib/network-upgrade/backups \
  -v ./keys:/keys:ro \
  -e INVENTORY_FILE=/opt/inventory/hosts.yml \
  -e ANSIBLE_TAGS=step4 \
  -e TARGET_FIRMWARE=nxos.10.2.3.bin \
  -e TARGET_HOSTS=cisco-switch-01 \
  -e MAX_CONCURRENT=5 \
  -e CISCO_NXOS_SSH_KEY=/keys/cisco-key \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

#### Step 5: Pre-Upgrade Validation
```bash
# Run pre-upgrade validation and establish baseline (auto-runs steps 1-4)
docker run --rm \
  -v ./inventory:/opt/inventory:ro \
  -v ./firmware:/var/lib/network-upgrade/firmware:ro \
  -v ./keys:/keys:ro \
  -e INVENTORY_FILE=/opt/inventory/hosts.yml \
  -e ANSIBLE_TAGS=step5 \
  -e TARGET_FIRMWARE=nxos.10.2.3.bin \
  -e TARGET_HOSTS=cisco-switch-01 \
  -e MAX_CONCURRENT=5 \
  -e CISCO_NXOS_SSH_KEY=/keys/cisco-key \
  ghcr.io/garryshtern/network-device-upgrade-system:latest dry-run
```

#### Step 6: Firmware Installation
```bash
# Install firmware and reboot (auto-runs steps 1-5, requires maintenance window)
docker run --rm \
  -v ./inventory:/opt/inventory:ro \
  -v ./firmware:/var/lib/network-upgrade/firmware:ro \
  -v ./backups:/var/lib/network-upgrade/backups \
  -v ./keys:/keys:ro \
  -e INVENTORY_FILE=/opt/inventory/hosts.yml \
  -e ANSIBLE_TAGS=step6 \
  -e TARGET_FIRMWARE=nxos.10.2.3.bin \
  -e TARGET_HOSTS=cisco-switch-01 \
  -e MAX_CONCURRENT=5 \
  -e MAINTENANCE_WINDOW=true \
  -e CISCO_NXOS_SSH_KEY=/keys/cisco-key \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

#### Step 7: Post-Upgrade Validation
```bash
# Validate network state after upgrade (standalone, requires step5 baseline)
docker run --rm \
  -v ./inventory:/opt/inventory:ro \
  -v ./keys:/keys:ro \
  -e INVENTORY_FILE=/opt/inventory/hosts.yml \
  -e ANSIBLE_TAGS=step7 \
  -e TARGET_HOSTS=cisco-switch-01 \
  -e MAX_CONCURRENT=5 \
  -e CISCO_NXOS_SSH_KEY=/keys/cisco-key \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

### Podman Examples (RHEL8/9)

#### Step 5: Pre-Upgrade Validation with SELinux
```bash
podman run --rm \
  -v /opt/inventory:/opt/inventory:ro,Z \
  -v /opt/firmware:/var/lib/network-upgrade/firmware:ro,Z \
  -v /opt/secrets/ssh-keys:/keys:ro,Z \
  -e INVENTORY_FILE=/opt/inventory/hosts.yml \
  -e ANSIBLE_TAGS=step5 \
  -e TARGET_FIRMWARE=nxos64-cs.10.4.5.M.bin \
  -e TARGET_HOSTS=datacenter-switches \
  -e MAX_CONCURRENT=5 \
  -e CISCO_NXOS_SSH_KEY=/keys/cisco-nxos-key \
  ghcr.io/garryshtern/network-device-upgrade-system:latest dry-run
```

#### Step 6: Production Firmware Installation with SELinux
```bash
podman run --rm \
  -v /opt/inventory:/opt/inventory:ro,Z \
  -v /opt/firmware:/var/lib/network-upgrade/firmware:ro,Z \
  -v /opt/backups:/var/lib/network-upgrade/backups:Z \
  -v /opt/secrets/ssh-keys:/keys:ro,Z \
  -e INVENTORY_FILE=/opt/inventory/production.yml \
  -e ANSIBLE_TAGS=step6 \
  -e TARGET_FIRMWARE=nxos64-cs.10.4.5.M.bin \
  -e TARGET_HOSTS=datacenter-switches \
  -e MAX_CONCURRENT=5 \
  -e MAINTENANCE_WINDOW=true \
  -e CISCO_NXOS_SSH_KEY=/keys/cisco-nxos-key \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

### Advanced Tag Usage

#### Multiple Steps
```bash
# Run only steps 1 and 5 (skips upload and backup)
docker run --rm \
  -e ANSIBLE_TAGS=step1,step5 \
  -e TARGET_HOSTS=cisco-switch-01 \
  -e MAX_CONCURRENT=5 \
  ghcr.io/garryshtern/network-device-upgrade-system:latest dry-run
```

#### Granular Tags
```bash
# Run only connectivity check (part of step1)
docker run --rm \
  -e ANSIBLE_TAGS=connectivity \
  -e TARGET_HOSTS=cisco-switch-01 \
  -e MAX_CONCURRENT=5 \
  ghcr.io/garryshtern/network-device-upgrade-system:latest dry-run

# Run only pre-upgrade validation (part of step5)
docker run --rm \
  -e ANSIBLE_TAGS=pre_validation \
  -e TARGET_HOSTS=cisco-switch-01 \
  -e MAX_CONCURRENT=5 \
  ghcr.io/garryshtern/network-device-upgrade-system:latest dry-run
```

### Common Use Cases

#### Testing Connectivity Before Maintenance Window
```bash
# Quick connectivity check during planning phase
docker run --rm \
  -v ./inventory:/opt/inventory:ro \
  -e ANSIBLE_TAGS=step1 \
  -e TARGET_HOSTS=all-switches \
  -e MAX_CONCURRENT=10 \
  ghcr.io/garryshtern/network-device-upgrade-system:latest dry-run
```

#### Pre-Staging Firmware
```bash
# Upload firmware outside maintenance window (steps 1-3)
docker run --rm \
  -v ./inventory:/opt/inventory:ro \
  -v ./firmware:/var/lib/network-upgrade/firmware:ro \
  -e ANSIBLE_TAGS=step3 \
  -e TARGET_FIRMWARE=nxos.10.2.3.bin \
  -e TARGET_HOSTS=datacenter-switches \
  -e MAX_CONCURRENT=5 \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

#### Emergency Configuration Backup
```bash
# Backup configurations before emergency maintenance
docker run --rm \
  -v ./inventory:/opt/inventory:ro \
  -v ./backups:/var/lib/network-upgrade/backups \
  -e ANSIBLE_TAGS=config_backup \
  -e TARGET_HOSTS=critical-devices \
  -e MAX_CONCURRENT=10 \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

#### Validation Only
```bash
# Run pre and post validation without upgrade
docker run --rm \
  -v ./inventory:/opt/inventory:ro \
  -e ANSIBLE_TAGS=step5,step7 \
  -e TARGET_HOSTS=cisco-switch-01 \
  -e MAX_CONCURRENT=5 \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

### Workflow Step Dependencies

Understanding the dependency chain:

```
step1 (connectivity, version_check)
  |
  v
step2 (space_check, hash verification)
  |
  v
step3 (image_upload)
  |
  v
step4 (config_backup)
  |
  v
step5 (pre_validation)
  |
  v
step6 (install, reboot)
  |
  v
step7 (post_validation) - standalone, requires step5 baseline
```

### Important Notes

- **Step 7 Requirements**: Post-upgrade validation (`step7`) requires a baseline from `step5` to compare against. Run `step5` before the upgrade, then `step7` after.
- **Maintenance Window**: Steps 1-5 can run without `MAINTENANCE_WINDOW=true`. Step 6 (installation) requires it.
- **Firmware Upload**: Step 3 automatically skips if firmware already exists on device (idempotent).
- **Dependency Resolution**: You cannot skip prerequisite steps. Running `step6` always executes `step1-step5` first.
- **Tag Flexibility**: Use step-based tags (`step1-step7`) for workflow control or granular tags (`connectivity`, `pre_validation`) for specific tasks.

## Container Commands

- `help` - Display help information
- `syntax-check` - Validate playbook syntax (default)
- `dry-run` - Execute in check mode (no changes)
- `run` - Execute actual upgrade (requires MAINTENANCE_WINDOW=true)
- `shell` - Interactive shell access
- `test` - Run test suite

## Important Notes

### Inventory Requirements
When using `TARGET_HOSTS`, you MUST mount a proper Ansible inventory file. The inventory provides:
- IP addresses and connection details
- Authentication credentials
- Platform types (cisco_nxos, cisco_iosxe, etc.)
- Host and group variables

### Volume Mounts
- Firmware images: Mount to `/var/lib/network-upgrade/firmware`
- Inventory: Mount to `/opt/inventory`
- SSH keys: Mount to `/keys` (read-only recommended)
- Backups: Mount to `/var/lib/network-upgrade/backups`

### SELinux Compatibility (Podman on RHEL/CentOS)
Add `,Z` to volume mounts for SELinux relabeling:
```bash
-v /path/to/data:/container/path:ro,Z
```

### Security Best Practices
1. Use SSH keys instead of passwords
2. Mount secrets as read-only (`:ro`)
3. Use API tokens for FortiOS and modern Opengear devices
4. Store credentials in external secret management (Vault, Kubernetes Secrets)
5. Never commit credentials to version control

## Platform-Specific Notes

### Cisco NX-OS
- Supports ISSU (In-Service Software Upgrade)
- EPLD upgrades available (may be disruptive)
- Uses `.bin` firmware files

### Cisco IOS-XE
- Supports install mode and bundle mode
- Uses `.bin` firmware files

### FortiOS
- Supports multi-step upgrades for major version jumps
- API token authentication preferred
- Uses `.out` firmware files

### Opengear
- Legacy models (CM7100, OM7200): Use `.flash` files, CLI-based
- Modern models (CM8100, OM2100/OM2200): Use `.raucb` files, API-based
- API token authentication available for modern models

### Metamako MOS
- Complete system upgrades (OS + applications)
- Uses `.iso` firmware files
- Supports application package installation (MetaWatch, MetaMux)

## Troubleshooting

### Common Issues

**"max_concurrent is REQUIRED" error**
- Solution: Add `-e MAX_CONCURRENT=5` to your docker run command
- This is mandatory for dry-run and run modes

**"Inventory not found" error**
- Verify inventory file is mounted correctly
- Check INVENTORY_FILE path matches the mount point
- Ensure inventory file exists and is readable

**Authentication failures**
- Verify SSH keys have correct permissions (600)
- Check that keys are mounted to the correct paths
- Ensure usernames match the device configuration
- For API tokens, verify they're not expired

**SELinux denials (RHEL/CentOS)**
- Add `,Z` to volume mounts for automatic relabeling
- Or use `sudo chcon -Rt svirt_sandbox_file_t /path/to/data`

For more detailed documentation, see:
- [Installation Guide](installation-guide.md)
- [Upgrade Workflow Guide](upgrade-workflow-guide.md)
- [Inventory Parameters](inventory-parameters.md)
