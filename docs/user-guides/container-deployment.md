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

### Platform-Specific Upgrade Features
- `ENABLE_EPLD_UPGRADE` - Enable EPLD firmware upgrades (Cisco NX-OS only, default: false)
  - Only set when explicitly 'true'
- `ALLOW_DISRUPTIVE_EPLD` - Allow disruptive EPLD upgrades (Cisco NX-OS only, default: false)
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

### Cisco NX-OS with EPLD Upgrade
```bash
docker run --rm \
  -v /opt/inventory:/opt/inventory:ro \
  -v /opt/firmware:/var/lib/network-upgrade/firmware:ro \
  -v /opt/secrets/ssh-keys:/keys:ro \
  -e INVENTORY_FILE=/opt/inventory/hosts.yml \
  -e MAX_CONCURRENT=5 \
  -e TARGET_HOSTS=nexus-switches \
  -e TARGET_FIRMWARE=nxos64-cs.10.4.5.M.bin \
  -e MAINTENANCE_WINDOW=true \
  -e CISCO_NXOS_SSH_KEY=/keys/cisco-nxos-key \
  -e ENABLE_EPLD_UPGRADE=true \
  -e ALLOW_DISRUPTIVE_EPLD=true \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

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
