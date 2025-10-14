# Container Deployment Guide

This guide provides comprehensive instructions for deploying the Network Device Upgrade System container with full authentication support including SSH keys and API tokens.

## Container Runtime Installation

### Docker Installation

#### Ubuntu/Debian
```bash
# Update package index
sudo apt-get update

# Install Docker
sudo apt-get install -y docker.io

# Start and enable Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Add user to docker group (requires logout/login to take effect)
sudo usermod -aG docker $USER

# Verify installation
docker --version
```

#### CentOS/RHEL 7
```bash
# Install Docker CE
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce docker-ce-cli containerd.io

# Start and enable Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Add user to docker group
sudo usermod -aG docker $USER

# Verify installation
docker --version
```

### Podman Installation (Recommended for RHEL8/9)

#### RHEL 8/9 and CentOS Stream
```bash
# Install Podman
sudo dnf install -y podman

# Verify installation
podman --version

# Configure rootless containers (optional but recommended)
echo 'export XDG_RUNTIME_DIR="$HOME/.cache/podman"' >> ~/.bashrc
source ~/.bashrc
```

#### Ubuntu 20.04+
```bash
# Add Podman repository
. /etc/os-release
echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libpod:/stable/xUbuntu_${VERSION_ID}/ /" | sudo tee /etc/apt/sources.list.d/devel:kubic:libpod:stable.list
curl -L "https://download.opensuse.org/repositories/devel:/kubic:/libpod:/stable/xUbuntu_${VERSION_ID}/Release.key" | sudo apt-key add -

# Install Podman
sudo apt-get update
sudo apt-get install -y podman

# Verify installation
podman --version
```

#### Fedora
```bash
# Install Podman (usually pre-installed)
sudo dnf install -y podman

# Verify installation
podman --version
```

## Quick Start

### Docker
```bash
# Pull the latest image
docker pull ghcr.io/garryshtern/network-device-upgrade-system:latest

# Display help and available commands
docker run --rm ghcr.io/garryshtern/network-device-upgrade-system:latest help

# Test basic functionality
docker run --rm ghcr.io/garryshtern/network-device-upgrade-system:latest syntax-check
```

### Podman (Rootless)
```bash
# Pull the latest image
podman pull ghcr.io/garryshtern/network-device-upgrade-system:latest

# Display help and available commands
podman run --rm ghcr.io/garryshtern/network-device-upgrade-system:latest help

# Test basic functionality
podman run --rm ghcr.io/garryshtern/network-device-upgrade-system:latest syntax-check
```

## Environment Variables Reference

The container supports extensive configuration through environment variables:

### Core Ansible Configuration
- `ANSIBLE_PLAYBOOK` - Playbook to execute (default: main-upgrade-workflow.yml)
- `ANSIBLE_INVENTORY` - Inventory file (default: hosts.yml) - **MANDATORY when using TARGET_HOSTS**
- `ANSIBLE_CONFIG` - Path to ansible.cfg file
- `ANSIBLE_VAULT_PASSWORD_FILE` - Path to vault password file

### Upgrade Configuration
- `TARGET_HOSTS` - Hosts to target (default: all) - **Requires ANSIBLE_INVENTORY to be mounted**
- `TARGET_FIRMWARE` - Firmware version to install
- `UPGRADE_PHASE` - Phase: full, loading, installation, validation, rollback
- `MAINTENANCE_WINDOW` - Set to 'true' for installation phase

### SSH Key Authentication (Preferred Method)
- `CISCO_NXOS_SSH_KEY` - SSH private key path for Cisco NX-OS devices
- `CISCO_IOSXE_SSH_KEY` - SSH private key path for Cisco IOS-XE devices
- `OPENGEAR_SSH_KEY` - SSH private key path for Opengear devices
- `METAMAKO_SSH_KEY` - SSH private key path for Metamako devices

### API Token Authentication (API-based platforms)
- `FORTIOS_API_TOKEN` - API token for FortiOS devices
- `OPENGEAR_API_TOKEN` - API token for Opengear REST API

### Password Authentication (Fallback)
- `CISCO_NXOS_PASSWORD` - Password for Cisco NX-OS devices
- `CISCO_IOSXE_PASSWORD` - Password for Cisco IOS-XE devices
- `FORTIOS_PASSWORD` - Password for FortiOS devices
- `OPENGEAR_PASSWORD` - Password for Opengear devices
- `METAMAKO_PASSWORD` - Password for Metamako devices

### Username Configuration
- `CISCO_NXOS_USERNAME` - Username for Cisco NX-OS devices
- `CISCO_IOSXE_USERNAME` - Username for Cisco IOS-XE devices
- `FORTIOS_USERNAME` - Username for FortiOS devices
- `OPENGEAR_USERNAME` - Username for Opengear devices
- `METAMAKO_USERNAME` - Username for Metamako devices

### Additional Configuration
- `IMAGE_SERVER_USERNAME` - Username for firmware image server
- `IMAGE_SERVER_PASSWORD` - Password for firmware image server
- `SNMP_COMMUNITY` - SNMP community string for monitoring

### Debug Configuration
- `SHOW_DEBUG` - Enable verbose debug output (true/false, default: false)
  - Provides comprehensive device facts dumps and detailed execution information
  - Enables all debug tasks in network validation roles
  - Example: `-e SHOW_DEBUG=true`

### Firmware Image Management
- `FIRMWARE_BASE_PATH` - Base directory for firmware images in container (default: /var/lib/network-upgrade/firmware)
- `TARGET_FIRMWARE` - Target firmware version/filename to install
- `BACKUP_BASE_PATH` - Base directory for configuration backups (default: /var/lib/network-upgrade/backups)

## Inventory Configuration

**CRITICAL**: When using `TARGET_HOSTS`, the container **REQUIRES** a properly mounted Ansible inventory file. Ansible must resolve the specified hostnames from the inventory.

### Why Inventory is Required with TARGET_HOSTS

When you specify `TARGET_HOSTS=cisco-switch-01` (or any specific hostname), Ansible needs to:
1. Resolve the hostname to an IP address/connection details
2. Find authentication credentials (username, keys, passwords)
3. Determine platform type (cisco_nxos, cisco_iosxe, etc.)
4. Apply host-specific variables and group memberships

All this information comes from the inventory file and its associated group_vars.

### Correct Inventory Mounting

```bash
# ✅ CORRECT: Mount inventory directory and specify full path
docker run --rm \
  -v /path/to/your/inventory:/opt/inventory:ro \
  -e ANSIBLE_INVENTORY=/opt/inventory/hosts.yml \
  -e TARGET_HOSTS=cisco-switch-01 \
  ghcr.io/garryshtern/network-device-upgrade-system:latest syntax-check

# ✅ CORRECT: Mount single inventory file directly
docker run --rm \
  -v /path/to/hosts.yml:/opt/inventory/hosts.yml:ro \
  -e ANSIBLE_INVENTORY=/opt/inventory/hosts.yml \
  -e TARGET_HOSTS=cisco-switch-01 \
  ghcr.io/garryshtern/network-device-upgrade-system:latest syntax-check
```

### Common Inventory Mounting Mistakes

```bash
# ❌ WRONG: Mounting to container root - Ansible won't find files
docker run --rm \
  -v /path/to/inventory:/inventory:ro \
  -e ANSIBLE_INVENTORY=/inventory/hosts.yml \
  -e TARGET_HOSTS=cisco-switch-01 \
  ghcr.io/garryshtern/network-device-upgrade-system:latest syntax-check

# ❌ WRONG: Using default path without mounting
docker run --rm \
  -e ANSIBLE_INVENTORY=hosts.yml \
  -e TARGET_HOSTS=cisco-switch-01 \
  ghcr.io/garryshtern/network-device-upgrade-system:latest syntax-check

# ❌ CRITICAL ERROR: Using TARGET_HOSTS without mounting inventory
docker run --rm \
  -e TARGET_HOSTS=cisco-switch-01 \
  ghcr.io/garryshtern/network-device-upgrade-system:latest syntax-check
# This will FAIL because Ansible cannot resolve 'cisco-switch-01'
```

### SELinux Compatibility (RHEL/CentOS)

```bash
# For systems with SELinux enabled (RHEL8/9)
podman run --rm \
  -v /path/to/inventory:/opt/inventory:ro,Z \
  -e ANSIBLE_INVENTORY=/opt/inventory/hosts.yml \
  -e TARGET_HOSTS=cisco-switch-01 \
  ghcr.io/garryshtern/network-device-upgrade-system:latest syntax-check
```

## Authentication Configuration

The container supports multiple authentication methods:

### Authentication Priority Order
1. **SSH Keys** (Preferred for SSH-based platforms)
2. **API Tokens** (Preferred for API-based platforms)
3. **Username/Password** (Fallback when keys/tokens unavailable)

## Secure SSH Key Mount Options

**The container automatically handles SSH key permissions!** The entrypoint script copies mounted SSH keys to the ansible user's home directory with correct permissions.

### SSH Key Mounting (Simple and Secure)

```bash
# ✅ SIMPLE: Just mount your SSH keys - container handles permissions automatically
docker run --rm \
  -v ~/.ssh/id_rsa_cisco:/keys/cisco-key:ro \
  -v ~/.ssh/id_rsa_opengear:/keys/opengear-key:ro \
  -v ~/.ssh/id_rsa_metamako:/keys/metamako-key:ro \
  -v /path/to/your/inventory:/opt/inventory:ro \
  -e ANSIBLE_INVENTORY=/opt/inventory/hosts.yml \
  -e CISCO_NXOS_SSH_KEY=/keys/cisco-key \
  -e OPENGEAR_SSH_KEY=/keys/opengear-key \
  -e METAMAKO_SSH_KEY=/keys/metamako-key \
  -e TARGET_HOSTS=cisco-switch-01 \
  ghcr.io/garryshtern/network-device-upgrade-system:latest syntax-check

# ✅ PODMAN: Same approach with SELinux context for RHEL8/9
podman run --rm \
  -v ~/.ssh/id_rsa_cisco:/keys/cisco-key:ro,Z \
  -v ~/.ssh/id_rsa_opengear:/keys/opengear-key:ro,Z \
  -v /path/to/your/inventory:/opt/inventory:ro,Z \
  -e ANSIBLE_INVENTORY=/opt/inventory/hosts.yml \
  -e CISCO_NXOS_SSH_KEY=/keys/cisco-key \
  -e OPENGEAR_SSH_KEY=/keys/opengear-key \
  -e TARGET_HOSTS=opengear-console-01 \
  ghcr.io/garryshtern/network-device-upgrade-system:latest syntax-check
```

### Directory Mount (Alternative)

```bash
# Mount entire SSH directory - container will find and copy the keys
docker run --rm \
  -v ~/.ssh:/keys:ro \
  -v /path/to/your/inventory:/opt/inventory:ro \
  -e ANSIBLE_INVENTORY=/opt/inventory/hosts.yml \
  -e CISCO_NXOS_SSH_KEY=/keys/id_rsa_cisco \
  -e CISCO_IOSXE_SSH_KEY=/keys/id_rsa_iosxe \
  -e OPENGEAR_SSH_KEY=/keys/id_rsa_opengear \
  -e TARGET_HOSTS=cisco-switch-01,router-01,console-01 \
  ghcr.io/garryshtern/network-device-upgrade-system:latest syntax-check
```

### How It Works

The container entrypoint automatically:
1. Detects mounted SSH keys specified via environment variables
2. Copies them to `/home/ansible/.ssh/` with correct ownership (ansible user)
3. Sets proper file permissions (600) for security
4. Updates Ansible variables to use the copied keys

**No manual permission changes needed!**

### Method 3: External Secrets (Production Recommended)

```bash
# Using external secret management (Kubernetes, Docker Secrets)
docker run --rm \
  --mount type=bind,source=/run/secrets/cisco-ssh-key,target=/keys/cisco-key,readonly \
  --mount type=bind,source=/run/secrets/opengear-ssh-key,target=/keys/opengear-key,readonly \
  --mount type=bind,source=/opt/inventory,target=/opt/inventory,readonly \
  -e ANSIBLE_INVENTORY=/opt/inventory/hosts.yml \
  -e CISCO_NXOS_SSH_KEY=/keys/cisco-key \
  -e OPENGEAR_SSH_KEY=/keys/opengear-key \
  -e TARGET_HOSTS=production-devices \
  ghcr.io/garryshtern/network-device-upgrade-system:latest dry-run
```

## Secure API Token Configuration

### Method 1: Environment Variables (Development)

```bash
# Read tokens from files (secure)
docker run --rm \
  -v /path/to/your/inventory:/opt/inventory:ro \
  -e ANSIBLE_INVENTORY=/opt/inventory/hosts.yml \
  -e FORTIOS_API_TOKEN="$(cat ~/.secrets/fortios-token)" \
  -e OPENGEAR_API_TOKEN="$(cat ~/.secrets/opengear-token)" \
  -e TARGET_HOSTS=fortinet-firewall-01,opengear-console-01 \
  ghcr.io/garryshtern/network-device-upgrade-system:latest syntax-check
```

### Method 2: External Secrets (Production Recommended)

```bash
# Using Docker secrets or external secret management
docker run --rm \
  --mount type=bind,source=/run/secrets/fortios-api-token,target=/tmp/fortios-token,readonly \
  --mount type=bind,source=/run/secrets/opengear-api-token,target=/tmp/opengear-token,readonly \
  --mount type=bind,source=/opt/inventory,target=/opt/inventory,readonly \
  -e ANSIBLE_INVENTORY=/opt/inventory/hosts.yml \
  -e FORTIOS_API_TOKEN="$(cat /tmp/fortios-token)" \
  -e OPENGEAR_API_TOKEN="$(cat /tmp/opengear-token)" \
  -e TARGET_HOSTS=fortinet-firewalls,opengear-consoles \
  ghcr.io/garryshtern/network-device-upgrade-system:latest dry-run
```

## Complete Production Example

```bash
# Complete production deployment with all authentication methods
docker run --rm \
  --name network-upgrade \
  --mount type=bind,source=/opt/secrets/ssh-keys,target=/keys,readonly \
  --mount type=bind,source=/opt/inventory,target=/opt/inventory,readonly \
  --mount type=bind,source=/opt/firmware,target=/opt/firmware,readonly \
  -e ANSIBLE_INVENTORY=/opt/inventory/production.yml \
  -e TARGET_HOSTS=cisco-datacenter-switches \
  -e TARGET_FIRMWARE=9.3.12 \
  -e UPGRADE_PHASE=loading \
  -e MAINTENANCE_WINDOW=false \
  -e CISCO_NXOS_SSH_KEY=/keys/cisco-nxos-key \
  -e CISCO_IOSXE_SSH_KEY=/keys/cisco-iosxe-key \
  -e FORTIOS_API_TOKEN="$(cat /opt/secrets/fortios-api-token)" \
  -e OPENGEAR_SSH_KEY=/keys/opengear-key \
  -e OPENGEAR_API_TOKEN="$(cat /opt/secrets/opengear-api-token)" \
  -e METAMAKO_SSH_KEY=/keys/metamako-key \
  ghcr.io/garryshtern/network-device-upgrade-system:latest dry-run
```

## Security Best Practices

### SSH Key Security
- **Key Permissions**: `chmod 600` for SSH private keys
- **Read-Only Mounts**: Always use `:ro` for key mounts
- **Separate Keys**: Use different keys per platform/environment
- **Key Rotation**: Regularly rotate SSH keys
- **No Key Logging**: Never log or print SSH key contents

### API Token Security
- **Token Rotation**: Regularly rotate API tokens
- **Minimal Permissions**: Use tokens with minimal required permissions
- **Secure Storage**: Store tokens in external secret management systems
- **No Token Logging**: Never log or print API token values
- **Environment Isolation**: Use different tokens per environment

### Container Security
- **Non-Root Execution**: Container runs as UID 1000 (ansible user)
- **Rootless Podman**: Compatible with rootless podman on RHEL8/9
- **SELinux Context**: Use `:Z` flag with podman for proper SELinux labeling
- **Resource Limits**: Set appropriate CPU/memory limits
- **Network Isolation**: Use appropriate network policies

### Data Protection
- **Encrypted Storage**: Store sensitive data in encrypted volumes
- **Audit Logging**: Enable container and host audit logging
- **Backup Security**: Secure backup of SSH keys and tokens
- **Access Control**: Implement proper RBAC for container access

## Container Commands Reference

### Available Commands
- `syntax-check` - Run Ansible syntax validation (default)
- `dry-run` - Execute playbook in check mode (no changes)
- `run` - Execute playbook (make actual changes)
- `test` - Run comprehensive test suite
- `shell` - Start interactive bash shell
- `help` - Show help message with all environment variables

### Usage Examples

```bash
# Check syntax
docker run --rm network-upgrade-system syntax-check

# Dry run with custom inventory
docker run --rm \
  -v ./inventory:/opt/inventory:ro \
  -e ANSIBLE_INVENTORY=/opt/inventory/staging.yml \
  network-upgrade-system dry-run

# Enable debug output with verbose display
docker run --rm \
  -v ./inventory:/opt/inventory:ro \
  -e ANSIBLE_INVENTORY=/opt/inventory/hosts.yml \
  -e SHOW_DEBUG=true \
  -e TARGET_HOSTS=cisco-switch-01 \
  network-upgrade-system dry-run

# Interactive debugging
docker run --rm -it network-upgrade-system shell

# Run test suite
docker run --rm network-upgrade-system test
```

## FortiOS Multi-Step Upgrades

FortiOS devices require sequential upgrades for major version jumps (e.g., 6.4.x → 7.2.x). The container automatically handles multi-step upgrades when properly configured.

### Multi-Step Upgrade Configuration

```bash
# Multi-step upgrade environment variables
MULTI_STEP_UPGRADE_REQUIRED=true    # Enable multi-step upgrade mode
UPGRADE_PATH="6.4.8,7.0.12,7.2.5"  # Comma-separated upgrade path
TARGET_FIRMWARE=7.2.5               # Final target version
```

### Multi-Step Upgrade Examples

#### Standalone FortiGate Upgrade

```bash
# Example: Upgrade from FortiOS 6.4.8 to 7.2.5 (via 7.0.12)
docker run --rm \
  -e TARGET_FIRMWARE=7.2.5 \
  -e MULTI_STEP_UPGRADE_REQUIRED=true \
  -e UPGRADE_PATH="6.4.8,7.0.12,7.2.5" \
  -e FORTIOS_API_TOKEN="$(cat ~/.secrets/fortios-token)" \
  -e TARGET_HOSTS=fortinet-firewall-01 \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

#### HA Cluster Multi-Step Upgrade

```bash
# HA cluster upgrade with maintenance window
docker run --rm \
  -e TARGET_FIRMWARE=7.2.5 \
  -e MULTI_STEP_UPGRADE_REQUIRED=true \
  -e UPGRADE_PATH="6.4.8,7.0.12,7.2.5" \
  -e FORTIOS_API_TOKEN="$(cat ~/.secrets/fortios-token)" \
  -e TARGET_HOSTS=fortinet-ha-cluster \
  -e MAINTENANCE_WINDOW=true \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

#### Production Multi-Step Upgrade

```bash
# Complete production multi-step upgrade
docker run --rm \
  --name fortios-upgrade \
  --mount type=bind,source=/opt/secrets,target=/secrets,readonly \
  --mount type=bind,source=/opt/inventory,target=/opt/inventory,readonly \
  -e ANSIBLE_INVENTORY=/opt/inventory/production.yml \
  -e TARGET_HOSTS=fortinet-datacenter-firewalls \
  -e TARGET_FIRMWARE=7.2.5 \
  -e MULTI_STEP_UPGRADE_REQUIRED=true \
  -e UPGRADE_PATH="6.4.8,7.0.12,7.2.5" \
  -e MAINTENANCE_WINDOW=true \
  -e FORTIOS_API_TOKEN="$(cat /secrets/fortios-api-token)" \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

### Multi-Step Upgrade Process

The multi-step upgrade process automatically:

1. **Version Detection**: Determines current FortiOS version
2. **Path Validation**: Validates the provided upgrade path
3. **HA Coordination**: Coordinates upgrades in HA environments
4. **Sequential Execution**: Executes each upgrade step in sequence
5. **Verification**: Verifies each step before proceeding
6. **Final Validation**: Confirms final target version

### Common Multi-Step Paths

| Current Version | Target Version | Recommended Path |
|----------------|----------------|------------------|
| 6.4.x | 7.0.x | `6.4.x,7.0.x` |
| 6.4.x | 7.2.x | `6.4.x,7.0.12,7.2.x` |
| 6.4.x | 7.4.x | `6.4.x,7.0.12,7.2.8,7.4.x` |
| 7.0.x | 7.4.x | `7.0.x,7.2.8,7.4.x` |

### Important Notes

- **License Validation**: Valid FortiCare license required
- **Backup Required**: Configuration backup created before upgrade
- **Downtime Planning**: Plan for extended downtime with multi-step upgrades
- **HA Coordination**: HA clusters require special handling
- **Firmware Availability**: Ensure all intermediate firmware versions are available

## Firmware Image Management

The container requires proper firmware image organization and mounting to perform upgrades. This section explains how to structure and provide firmware images to the container.

### Firmware Directory Structure

The container expects firmware images to be organized by platform in the following structure:

```
/var/lib/network-upgrade/firmware/
├── cisco.nxos/          # Cisco NX-OS firmware images
│   ├── nxos64-cs.10.4.5.M.bin
│   ├── nxos64-msll.10.4.6.M.bin
│   └── ...
├── cisco.ios/           # Cisco IOS-XE firmware images
│   ├── cat9k_lite_iosxe.16.12.10.SPA.bin
│   ├── cat9k_iosxe.17.09.04a.SPA.bin
│   └── ...
├── fortios/             # FortiOS firmware images
│   ├── FGT_VM64_KVM-v7.0.12-build0523-FORTINET.out
│   ├── FGT_VM64_KVM-v7.2.5-build1517-FORTINET.out
│   └── ...
├── opengear/            # Opengear firmware images
│   ├── cm71xx-5.2.4.flash         # Legacy Console Manager (CM7100)
│   ├── console_manager-25.07.0-production-signed.raucb  # Modern Console Manager (CM8100)
│   ├── operations_manager-25.07.0-production-signed.raucb # Operations Manager (OM2100/OM2200)
│   ├── im72xx-5.2.4.flash         # Legacy Infrastructure Manager (IM7200)
│   └── ...
└── metamako/            # Metamako MOS firmware images
    ├── mos-0.39.9.iso                  # Base MOS firmware
    ├── metawatch-3.2.0-1967.x86_64.rpm # MetaWatch application
    ├── metamux-2.2.3-1849.x86_64.rpm   # MetaMux application
    └── ...
```

### Volume Mounting for Firmware Images

#### Method 1: Single Firmware Directory Mount

```bash
# Mount your firmware directory to the container
docker run --rm \
  -v /opt/firmware:/var/lib/network-upgrade/firmware:ro \
  -v /opt/inventory:/opt/inventory:ro \
  -e ANSIBLE_INVENTORY=/opt/inventory/hosts.yml \
  -e TARGET_FIRMWARE=nxos64-cs.10.4.5.M.bin \
  -e TARGET_HOSTS=cisco-switches \
  -e CISCO_NXOS_SSH_KEY=/keys/cisco-key \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

#### Method 2: Platform-Specific Mounts

```bash
# Mount platform-specific directories
docker run --rm \
  -v /opt/firmware/cisco:/var/lib/network-upgrade/firmware/cisco.nxos:ro \
  -v /opt/firmware/fortinet:/var/lib/network-upgrade/firmware/fortios:ro \
  -v /opt/firmware/opengear:/var/lib/network-upgrade/firmware/opengear:ro \
  -v /opt/inventory:/opt/inventory:ro \
  -e ANSIBLE_INVENTORY=/opt/inventory/hosts.yml \
  -e TARGET_FIRMWARE=nxos64-cs.10.4.5.M.bin \
  -e TARGET_HOSTS=cisco-datacenter-switches \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

#### Method 3: Production Setup with Multiple Volumes

```bash
# Production deployment with organized structure
docker run --rm \
  --name network-upgrade \
  -v /opt/network-upgrade/firmware:/var/lib/network-upgrade/firmware:ro \
  -v /opt/network-upgrade/backups:/var/lib/network-upgrade/backups \
  -v /opt/network-upgrade/logs:/var/log/network-upgrade \
  -v /opt/secrets/ssh-keys:/keys:ro \
  -e ANSIBLE_INVENTORY=/opt/inventory/production.yml \
  -e TARGET_FIRMWARE=nxos64-cs.10.4.5.M.bin \
  -e TARGET_HOSTS=datacenter-switches \
  -e CISCO_NXOS_SSH_KEY=/keys/cisco-nxos-key \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

### Platform-Specific Firmware Examples

#### Cisco NX-OS
```bash
# Docker - NX-OS upgrade example
docker run --rm \
  -v /opt/firmware:/var/lib/network-upgrade/firmware:ro \
  -v ~/.ssh/cisco_nxos_key:/keys/cisco-key:ro \
  -v /opt/inventory:/opt/inventory:ro \
  -e ANSIBLE_INVENTORY=/opt/inventory/hosts.yml \
  -e TARGET_FIRMWARE=nxos64-cs.10.4.5.M.bin \
  -e TARGET_HOSTS=nexus-switches \
  -e CISCO_NXOS_SSH_KEY=/keys/cisco-key \
  -e CISCO_NXOS_USERNAME=admin \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run

# Podman - NX-OS upgrade example (RHEL8/9 compatible)
podman run --rm \
  -v /opt/firmware:/var/lib/network-upgrade/firmware:ro,Z \
  -v ~/.ssh/cisco_nxos_key:/keys/cisco-key:ro,Z \
  -v /opt/inventory:/opt/inventory:ro,Z \
  -e ANSIBLE_INVENTORY=/opt/inventory/hosts.yml \
  -e TARGET_FIRMWARE=nxos64-cs.10.4.5.M.bin \
  -e TARGET_HOSTS=nexus-switches \
  -e CISCO_NXOS_SSH_KEY=/keys/cisco-key \
  -e CISCO_NXOS_USERNAME=admin \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

#### Cisco IOS-XE
```bash
# Docker - IOS-XE upgrade example
docker run --rm \
  -v /opt/firmware:/var/lib/network-upgrade/firmware:ro \
  -v ~/.ssh/cisco_iosxe_key:/keys/cisco-key:ro \
  -v /opt/inventory:/opt/inventory:ro \
  -e ANSIBLE_INVENTORY=/opt/inventory/hosts.yml \
  -e TARGET_FIRMWARE=cat9k_iosxe.17.09.04a.SPA.bin \
  -e TARGET_HOSTS=catalyst-switches \
  -e CISCO_IOSXE_SSH_KEY=/keys/cisco-key \
  -e CISCO_IOSXE_USERNAME=admin \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run

# Podman - IOS-XE upgrade example (RHEL8/9 compatible)
podman run --rm \
  -v /opt/firmware:/var/lib/network-upgrade/firmware:ro,Z \
  -v ~/.ssh/cisco_iosxe_key:/keys/cisco-key:ro,Z \
  -v /opt/inventory:/opt/inventory:ro,Z \
  -e ANSIBLE_INVENTORY=/opt/inventory/hosts.yml \
  -e TARGET_FIRMWARE=cat9k_iosxe.17.09.04a.SPA.bin \
  -e TARGET_HOSTS=catalyst-switches \
  -e CISCO_IOSXE_SSH_KEY=/keys/cisco-key \
  -e CISCO_IOSXE_USERNAME=admin \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

#### FortiOS
```bash
# FortiOS upgrade example
docker run --rm \
  -v /opt/firmware:/var/lib/network-upgrade/firmware:ro \
  -v /opt/inventory:/opt/inventory:ro \
  -e ANSIBLE_INVENTORY=/opt/inventory/hosts.yml \
  -e TARGET_FIRMWARE=FGT_VM64_KVM-v7.2.5-build1517-FORTINET.out \
  -e TARGET_HOSTS=fortinet-firewalls \
  -e FORTIOS_API_TOKEN="$(cat ~/.secrets/fortios-token)" \
  -e FORTIOS_USERNAME=admin \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

#### Opengear Console Servers

Opengear supports two different device models with different firmware formats and upgrade methods:

**Legacy Models (CM7100, IM7200) - Uses .flash files**
```bash
# Docker - Opengear legacy models upgrade example (CM7100, IM7200 with netflash)
docker run --rm \
  -v /opt/firmware:/var/lib/network-upgrade/firmware:ro \
  -v ~/.ssh/opengear_key:/keys/opengear-key:ro \
  -v /opt/inventory:/opt/inventory:ro \
  -e ANSIBLE_INVENTORY=/opt/inventory/hosts.yml \
  -e TARGET_FIRMWARE=cm71xx-5.2.4.flash \
  -e TARGET_HOSTS=console-servers-legacy \
  -e OPENGEAR_SSH_KEY=/keys/opengear-key \
  -e OPENGEAR_USERNAME=root \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run

# Podman - Opengear legacy models upgrade example (RHEL8/9 compatible)
podman run --rm \
  -v /opt/firmware:/var/lib/network-upgrade/firmware:ro,Z \
  -v ~/.ssh/opengear_key:/keys/opengear-key:ro,Z \
  -v /opt/inventory:/opt/inventory:ro,Z \
  -e ANSIBLE_INVENTORY=/opt/inventory/hosts.yml \
  -e TARGET_FIRMWARE=cm71xx-5.2.4.flash \
  -e TARGET_HOSTS=console-servers-legacy \
  -e OPENGEAR_SSH_KEY=/keys/opengear-key \
  -e OPENGEAR_USERNAME=root \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

**Modern Models (CM8100, OM2100/OM2200) - Uses .raucb files**
```bash
# Docker - Opengear modern models upgrade example (CM8100, OM2100/OM2200 with puginstall)
docker run --rm \
  -v /opt/firmware:/var/lib/network-upgrade/firmware:ro \
  -v ~/.ssh/opengear_key:/keys/opengear-key:ro \
  -v /opt/inventory:/opt/inventory:ro \
  -e ANSIBLE_INVENTORY=/opt/inventory/hosts.yml \
  -e TARGET_FIRMWARE=console_manager-25.07.0-production-signed.raucb \
  -e TARGET_HOSTS=console-servers-modern \
  -e OPENGEAR_SSH_KEY=/keys/opengear-key \
  -e OPENGEAR_USERNAME=root \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run

# Podman - Opengear modern models upgrade example (RHEL8/9 compatible)
podman run --rm \
  -v /opt/firmware:/var/lib/network-upgrade/firmware:ro,Z \
  -v ~/.ssh/opengear_key:/keys/opengear-key:ro,Z \
  -v /opt/inventory:/opt/inventory:ro,Z \
  -e ANSIBLE_INVENTORY=/opt/inventory/hosts.yml \
  -e TARGET_FIRMWARE=console_manager-25.07.0-production-signed.raucb \
  -e TARGET_HOSTS=console-servers-modern \
  -e OPENGEAR_SSH_KEY=/keys/opengear-key \
  -e OPENGEAR_USERNAME=root \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

#### Metamako MOS (Complete System Upgrade)

Metamako MOS upgrades are **complete system upgrades** that include both the base MOS firmware/OS and all applications (MetaWatch, MetaMux) as an integrated process.

```bash
# Docker - Metamako MOS complete system upgrade (includes MOS firmware + MetaWatch + MetaMux applications)
docker run --rm \
  -v /opt/firmware:/var/lib/network-upgrade/firmware:ro \
  -v ~/.ssh/metamako_key:/keys/metamako-key:ro \
  -v /opt/inventory:/opt/inventory:ro \
  -e ANSIBLE_INVENTORY=/opt/inventory/hosts.yml \
  -e TARGET_FIRMWARE=mos-0.39.9.iso \
  -e TARGET_HOSTS=metamako-devices \
  -e METAMAKO_SSH_KEY=/keys/metamako-key \
  -e METAMAKO_USERNAME=admin \
  -e ENABLE_APPLICATION_INSTALLATION=true \
  -e METAWATCH_PACKAGE=metawatch-3.2.0-1967.x86_64.rpm \
  -e METAMUX_PACKAGE=metamux-2.2.3-1849.x86_64.rpm \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run

# Podman - Metamako MOS complete system upgrade (RHEL8/9 compatible)
podman run --rm \
  -v /opt/firmware:/var/lib/network-upgrade/firmware:ro,Z \
  -v ~/.ssh/metamako_key:/keys/metamako-key:ro,Z \
  -v /opt/inventory:/opt/inventory:ro,Z \
  -e ANSIBLE_INVENTORY=/opt/inventory/hosts.yml \
  -e TARGET_FIRMWARE=mos-0.39.9.iso \
  -e TARGET_HOSTS=metamako-devices \
  -e METAMAKO_SSH_KEY=/keys/metamako-key \
  -e METAMAKO_USERNAME=admin \
  -e ENABLE_APPLICATION_INSTALLATION=true \
  -e METAWATCH_PACKAGE=metawatch-3.2.0-1967.x86_64.rpm \
  -e METAMUX_PACKAGE=metamux-2.2.3-1849.x86_64.rpm \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

**MOS Upgrade Process Includes**:
1. **Base MOS Firmware**: Core operating system and drivers (ISO format: `mos-0.39.9.iso`)
2. **MetaWatch Application**: Performance monitoring and latency measurement (RPM: `metawatch-3.2.0-1967.x86_64.rpm`)
3. **MetaMux Application**: High-performance packet switching and routing (RPM: `metamux-2.2.3-1849.x86_64.rpm`)
4. **System Integration**: All components are installed and configured together
5. **Latency Validation**: Ultra-low latency performance verification post-upgrade

**File Formats**:
- **MOS Base OS**: ISO image format for bare-metal installation (`.iso`)
- **Applications**: SWIX packages (`.swix`) for MetaWatch and MetaMux applications
- **Installation Method**: ISO boot/mount + SWIX package installation

**Important**: Metamako MOS upgrades are **always complete system upgrades** - you cannot upgrade MOS firmware without also updating the applications, as they are tightly integrated for ultra-low latency performance requirements.

**MANDATORY Filename Patterns**:
- MOS OS: `mos-{version}.iso` (e.g., `mos-0.39.9.iso`)
- MetaMux: `metamux-{version}.swix` (e.g., `metamux-2.1.7.swix`)
- MetaWatch: `metawatch-{version}.swix` (e.g., `metawatch-0.11.3.swix`)

See [Firmware Naming Standards](firmware-naming-standards.md) for complete requirements.

### Firmware Filename Resolution

The system resolves firmware file paths using different mechanisms depending on the platform:

#### Direct Resolution (Cisco Platforms)
For **Cisco NX-OS** and **Cisco IOS-XE**, the filename is constructed as:
```
Full Path = firmware_base_path + "/" + target_firmware
```

Example:
- `FIRMWARE_BASE_PATH=/var/lib/network-upgrade/firmware`
- `TARGET_FIRMWARE=nxos64-cs.10.4.5.M.bin`
- **Resolved Path**: `/var/lib/network-upgrade/firmware/nxos64-cs.10.4.5.M.bin`

#### Platform-Specific Subdirectories
For **FortiOS**, **Opengear**, and **Metamako**, the system uses platform-specific subdirectories:

| Platform | Firmware Path Resolution | Example |
|----------|-------------------------|---------|
| Cisco NX-OS | `firmware_base_path/target_firmware` | `/var/lib/network-upgrade/firmware/nxos64-cs.10.4.5.M.bin` |
| Cisco IOS-XE | `firmware_base_path/target_firmware` | `/var/lib/network-upgrade/firmware/cat9k_iosxe.17.09.04a.SPA.bin` |
| FortiOS | `firmware_base_path/fortios/target_firmware` | `/var/lib/network-upgrade/firmware/fortios/FGT_VM64_KVM-v7.2.5-build1517-FORTINET.out` |
| Opengear | `firmware_base_path/opengear/target_firmware` | `/var/lib/network-upgrade/firmware/opengear/cm71xx-5.2.4.flash` |
| Metamako MOS | `firmware_base_path/metamako/target_firmware` | `/var/lib/network-upgrade/firmware/metamako/mos-0.39.9.iso` |

### Platform-Specific Firmware Selection

The system automatically detects device models and selects the appropriate firmware file based on hardware platform. You can also specify firmware per device model using the `platform_firmware` parameter.

#### Automatic Detection (Recommended)
```bash
# System automatically detects device model and selects correct firmware
docker run --rm \
  -v /opt/firmware:/var/lib/network-upgrade/firmware:ro \
  -v /opt/inventory:/opt/inventory:ro \
  -e ANSIBLE_INVENTORY=/opt/inventory/hosts.yml \
  -e TARGET_FIRMWARE=9.3.12 \
  -e TARGET_HOSTS=cisco-switches \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

#### Platform-Specific Override
```bash
# Specify different firmware per platform/model
docker run --rm \
  -v /opt/firmware:/var/lib/network-upgrade/firmware:ro \
  -v /opt/inventory:/opt/inventory:ro \
  -e ANSIBLE_INVENTORY=/opt/inventory/hosts.yml \
  -e TARGET_HOSTS=mixed-cisco-devices \
  -e PLATFORM_FIRMWARE='{
    "cisco_nxos": {
      "N9K-C93180": "nxos64-cs.10.4.5.M.bin",
      "N3K-C3548": "nxos64-msll.10.4.6.M.bin",
      "N7K-C7004": "n7000-s2-dk9.9.3.12.bin",
      "default": "nxos64-cs.10.4.5.M.bin"
    },
    "cisco_iosxe": {
      "C9300": "cat9k_lite_iosxe.17.09.04a.SPA.bin",
      "C9400": "cat9k_iosxe.17.09.04a.SPA.bin",
      "C8500L": "c8000aes-universalk9.17.15.03a.SPA.bin",
      "default": "cat9k_iosxe.17.09.04a.SPA.bin"
    },
    "opengear": {
      "CM7100": "cm71xx-5.2.4.flash",
      "CM8100": "console_manager-25.07.0-production-signed.raucb"
    }
  }' \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

### Firmware Naming Conventions

> **⚠️ MANDATORY NAMING STANDARDS**: All firmware filenames MUST conform to the strict patterns defined in [Firmware Naming Standards](firmware-naming-standards.md). The system performs validation and will **REJECT** non-conformant files.

| Platform | Firmware Naming Pattern | Example |
|----------|------------------------|---------|
| **Cisco NX-OS** | **Platform-Specific Patterns** | |
| Nexus 9000 Series | `nxos64-cs.{version}.bin` | `nxos64-cs.10.1.1.bin` or `nxos64-cs.10.4.5.M.bin` |
| Nexus 92384/93180 | `nxos64-cs.{version}.bin` | `nxos64-cs.9.3.10.bin` or `nxos64-cs.10.4.5.M.bin` |
| Nexus 7000 Series | `n7000-s2-dk9.{version}.bin` | `n7000-s2-dk9.9.3.12.bin` |
| Nexus 5000 Series | `n5000-uk9.{version}.bin` | `n5000-uk9.9.3.12.bin` |
| Nexus 3548 | `nxos64-msll.{version}.bin` | `nxos64-msll.10.4.6.M.bin` (version: `10.4.6.M`) |
| Nexus 3000 Other | `n3000-uk9.{version}.bin` | `n3000-uk9.9.3.12.bin` |
| **NX-OS EPLD** | `n9000-epld.{version}.img` | `n9000-epld.10.1.2.img` or `n9000-epld.9.3.16.M.img` |
| **Cisco IOS-XE** | **Platform-Specific Patterns** | |
| Catalyst 9000 Series | `cat9k_iosxe.{version}.SPA.bin` | `cat9k_iosxe.17.09.04a.SPA.bin` |
| Catalyst 9200/9300 | `cat9k_lite_iosxe.{version}.SPA.bin` | `cat9k_lite_iosxe.17.09.04a.SPA.bin` |
| Catalyst 3850/3650 | `cat3k_caa-universalk9.{version}.SPA.bin` | `cat3k_caa-universalk9.17.09.04a.SPA.bin` |
| ISR 4000 Series | `isr4300-universalk9_ias.{version}.SPA.bin` | `isr4300-universalk9_ias.17.09.04a.SPA.bin` |
| ASR 1000 Series | `asr1000rp3-adventerprisek9.{version}.SPA.bin` | `asr1000rp3-adventerprisek9.17.09.04a.SPA.bin` |
| Catalyst 8000 Series | `c8000aes-universalk9.{version}.SPA.bin` | `c8000aes-universalk9.17.15.03a.SPA.bin` |
| **FortiOS** | `FGT_*-v{version}-*-FORTINET.out` | `FGT_VM64_KVM-v7.2.5-build1517-FORTINET.out` |
| **Opengear** | **Model-Specific Patterns** | |
| CM7100 (Legacy) | `cm71xx-{version}.flash` | `cm71xx-5.2.4.flash` |
| IM7200 (Legacy) | `im72xx-{version}.flash` | `im72xx-5.2.4.flash` |
| CM8100 (Modern) | `console_manager-{version}-production-signed.raucb` | `console_manager-25.07.0-production-signed.raucb` |
| OM2100/OM2200 (Modern) | `operations_manager-{version}-production-signed.raucb` | `operations_manager-25.07.0-production-signed.raucb` |
| **Metamako MOS** | `mos-{version}.iso` | `mos-0.39.9.iso` |
| **MetaWatch App** | `metawatch-{version}.swix` | `metawatch-0.11.3.swix` |
| **MetaMux App** | `metamux-{version}.swix` | `metamux-2.1.7.swix` |

**For complete naming standards, patterns, and validation rules, see [Firmware Naming Standards](firmware-naming-standards.md).**

### EPLD Upgrade Examples (Cisco NX-OS)

EPLD (Embedded Programmable Logic Device) upgrades require special handling and can be disruptive. The system automatically detects EPLD requirements and uses the correct firmware filename pattern:

#### EPLD Upgrade with Automatic Detection
```bash
# Nexus 9000 EPLD upgrade with automatic filename detection
docker run --rm \
  -v /opt/firmware:/var/lib/network-upgrade/firmware:ro \
  -v ~/.ssh/cisco_nxos_key:/keys/cisco-key:ro \
  -v /opt/inventory:/opt/inventory:ro \
  -e ANSIBLE_INVENTORY=/opt/inventory/hosts.yml \
  -e TARGET_FIRMWARE=10.4.5.M \
  -e TARGET_EPLD_IMAGE=n9000-epld.9.3.16.img \
  -e TARGET_HOSTS=nexus-9000-switches \
  -e CISCO_NXOS_SSH_KEY=/keys/cisco-key \
  -e ENABLE_EPLD_UPGRADE=true \
  -e ALLOW_DISRUPTIVE_EPLD=true \
  -e MAINTENANCE_WINDOW=true \
  -e EPLD_UPGRADE_TIMEOUT=7200 \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

#### EPLD-Only Upgrade
```bash
# EPLD-only upgrade (no firmware upgrade)
docker run --rm \
  -v /opt/firmware:/var/lib/network-upgrade/firmware:ro \
  -v ~/.ssh/cisco_nxos_key:/keys/cisco-key:ro \
  -v /opt/inventory:/opt/inventory:ro \
  -e ANSIBLE_INVENTORY=/opt/inventory/hosts.yml \
  -e TARGET_EPLD_IMAGE=n9000-epld.9.3.16.img \
  -e TARGET_HOSTS=nexus-switches \
  -e CISCO_NXOS_SSH_KEY=/keys/cisco-key \
  -e ENABLE_EPLD_UPGRADE=true \
  -e ALLOW_DISRUPTIVE_EPLD=false \
  -e UPGRADE_PHASE=epld \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

**EPLD Upgrade Notes:**
- EPLD files use `.img` extension (e.g., `n9000-epld.9.3.16.M.img`)
- EPLD versions follow SAME format as NX-OS (include `.M` suffix)
- System automatically detects correct EPLD filename based on device platform
- EPLD upgrades can be disruptive and may require maintenance windows
- Use `ALLOW_DISRUPTIVE_EPLD=true` only during maintenance windows

EPLD (Embedded Programmable Logic Device) upgrades require special handling and can be disruptive:

#### Standard EPLD Upgrade
```bash
# EPLD upgrade with non-disruptive mode
docker run --rm \
  -v /opt/firmware:/var/lib/network-upgrade/firmware:ro \
  -v ~/.ssh/cisco_nxos_key:/keys/cisco-key:ro \
  -v /opt/inventory:/opt/inventory:ro \
  -e ANSIBLE_INVENTORY=/opt/inventory/hosts.yml \
  -e TARGET_FIRMWARE=nxos64-cs.10.4.5.M.bin \
  -e TARGET_HOSTS=nexus-switches \
  -e CISCO_NXOS_SSH_KEY=/keys/cisco-key \
  -e ENABLE_EPLD_UPGRADE=true \
  -e ALLOW_DISRUPTIVE_EPLD=false \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

#### Disruptive EPLD Upgrade (Maintenance Window Required)
```bash
# EPLD upgrade with disruptive mode (requires maintenance window)
docker run --rm \
  -v /opt/firmware:/var/lib/network-upgrade/firmware:ro \
  -v ~/.ssh/cisco_nxos_key:/keys/cisco-key:ro \
  -v /opt/inventory:/opt/inventory:ro \
  -e ANSIBLE_INVENTORY=/opt/inventory/hosts.yml \
  -e TARGET_FIRMWARE=nxos.10.1.2.bin \
  -e TARGET_HOSTS=nexus-core-switches \
  -e CISCO_NXOS_SSH_KEY=/keys/cisco-key \
  -e ENABLE_EPLD_UPGRADE=true \
  -e ALLOW_DISRUPTIVE_EPLD=true \
  -e MAINTENANCE_WINDOW=true \
  -e EPLD_UPGRADE_TIMEOUT=7200 \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

## Complete Examples

This section provides comprehensive, production-ready examples for all supported platforms. Replace `docker` with `podman` for Red Hat/enterprise environments.

### Cisco NX-OS Complete Example

```bash
# Complete Cisco NX-OS upgrade with EPLD support
docker run --rm \
  --name cisco-nxos-upgrade \
  --mount type=bind,source=/opt/firmware,target=/var/lib/network-upgrade/firmware,readonly \
  --mount type=bind,source=/opt/backups,target=/var/lib/network-upgrade/backups \
  --mount type=bind,source=/opt/secrets/ssh-keys,target=/keys,readonly \
  --mount type=bind,source=/opt/inventory,target=/opt/inventory,readonly \
  -e ANSIBLE_INVENTORY=/opt/inventory/production.yml \
  -e TARGET_HOSTS=datacenter-nexus-switches \
  -e TARGET_FIRMWARE=nxos64-cs.10.4.5.M.bin \
  -e UPGRADE_PHASE=full \
  -e CISCO_NXOS_SSH_KEY=/keys/cisco-nxos-key \
  -e CISCO_NXOS_USERNAME=admin \
  -e ENABLE_EPLD_UPGRADE=true \
  -e ALLOW_DISRUPTIVE_EPLD=false \
  -e MAINTENANCE_WINDOW=false \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

### FortiOS Multi-Step Upgrade Example

```bash
# FortiOS multi-step upgrade from 6.4.x to 7.2.5
docker run --rm \
  --name fortios-multi-step-upgrade \
  --mount type=bind,source=/opt/firmware,target=/var/lib/network-upgrade/firmware,readonly \
  --mount type=bind,source=/opt/secrets,target=/secrets,readonly \
  --mount type=bind,source=/opt/inventory,target=/opt/inventory,readonly \
  -e ANSIBLE_INVENTORY=/opt/inventory/production.yml \
  -e TARGET_HOSTS=fortinet-datacenter-firewalls \
  -e TARGET_FIRMWARE=7.2.5 \
  -e MULTI_STEP_UPGRADE_REQUIRED=true \
  -e UPGRADE_PATH="6.4.8,7.0.12,7.2.5" \
  -e MAINTENANCE_WINDOW=true \
  -e FORTIOS_API_TOKEN="$(cat /secrets/fortios-api-token)" \
  -e FORTIOS_USERNAME=admin \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

### Opengear Legacy Models Example

```bash
# Opengear legacy models (CM7100, OM7200) with .flash files
docker run --rm \
  --name opengear-legacy-upgrade \
  --mount type=bind,source=/opt/firmware,target=/var/lib/network-upgrade/firmware,readonly \
  --mount type=bind,source=/opt/secrets/ssh-keys,target=/keys,readonly \
  -e TARGET_FIRMWARE=cm71xx-5.2.4.flash \
  -e TARGET_HOSTS=console-servers-legacy \
  -e OPENGEAR_SSH_KEY=/keys/opengear-key \
  -e OPENGEAR_USERNAME=root \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

### Opengear Modern Models Example

```bash
# Opengear modern models (CM8100, OM2200) with .raucb files
docker run --rm \
  --name opengear-modern-upgrade \
  --mount type=bind,source=/opt/firmware,target=/var/lib/network-upgrade/firmware,readonly \
  --mount type=bind,source=/opt/secrets,target=/secrets,readonly \
  -e TARGET_FIRMWARE=console_manager-25.07.0-production-signed.raucb \
  -e TARGET_HOSTS=console-servers-modern \
  -e OPENGEAR_API_TOKEN="$(cat /secrets/opengear-api-token)" \
  -e OPENGEAR_USERNAME=root \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

### Metamako MOS Complete System Upgrade

```bash
# Metamako MOS complete system upgrade (firmware + applications)
docker run --rm \
  --name metamako-system-upgrade \
  --mount type=bind,source=/opt/firmware,target=/var/lib/network-upgrade/firmware,readonly \
  --mount type=bind,source=/opt/secrets/ssh-keys,target=/keys,readonly \
  -e TARGET_FIRMWARE=mos-0.39.9.iso \
  -e TARGET_HOSTS=metamako-switch-fabric \
  -e METAMAKO_SSH_KEY=/keys/metamako-key \
  -e METAMAKO_USERNAME=admin \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

### Platform-Specific Firmware Example

```bash
# Multi-platform upgrade with device-specific firmware
docker run --rm \
  --name platform-specific-upgrade \
  --mount type=bind,source=/opt/firmware,target=/var/lib/network-upgrade/firmware,readonly \
  --mount type=bind,source=/opt/secrets/ssh-keys,target=/keys,readonly \
  --mount type=bind,source=/opt/inventory,target=/opt/inventory,readonly \
  -e ANSIBLE_INVENTORY=/opt/inventory/production.yml \
  -e TARGET_HOSTS=mixed-platform-devices \
  -e PLATFORM_FIRMWARE='{
    "cisco_nxos": {
      "N9K-C92384": "nxos64-cs.10.4.5.M.bin",
      "N9K-C93180": "nxos64-cs.10.4.5.M.bin",
      "N3K-C3548": "nxos64-msll.10.4.6.M.bin",
      "N7K-C7004": "n7000-s2-dk9.9.3.12.bin",
      "default": "nxos64-cs.10.4.5.M.bin"
    },
    "cisco_iosxe": {
      "C9200": "cat9k_lite_iosxe.17.09.04a.SPA.bin",
      "C9300": "cat9k_lite_iosxe.17.09.04a.SPA.bin",
      "C9400": "cat9k_iosxe.17.09.04a.SPA.bin",
      "C8500L": "c8000aes-universalk9.17.15.03a.SPA.bin",
      "ISR4321": "isr4300-universalk9_ias.17.09.04a.SPA.bin",
      "default": "cat9k_iosxe.17.09.04a.SPA.bin"
    },
    "opengear": {
      "CM7100": "cm71xx-5.2.4.flash",
      "CM8100": "console_manager-25.07.0-production-signed.raucb",
      "OM2200": "operations_manager-25.07.0-production-signed.raucb"
    }
  }' \
  -e CISCO_NXOS_SSH_KEY=/keys/cisco-nxos-key \
  -e CISCO_IOSXE_SSH_KEY=/keys/cisco-iosxe-key \
  -e OPENGEAR_SSH_KEY=/keys/opengear-key \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

### Multi-Platform Production Example

```bash
# Complete multi-platform production deployment
docker run --rm \
  --name network-upgrade-production \
  --mount type=bind,source=/opt/network-upgrade/firmware,target=/var/lib/network-upgrade/firmware,readonly \
  --mount type=bind,source=/opt/network-upgrade/backups,target=/var/lib/network-upgrade/backups \
  --mount type=bind,source=/opt/network-upgrade/logs,target=/var/log/network-upgrade \
  --mount type=bind,source=/opt/secrets/ssh-keys,target=/keys,readonly \
  --mount type=bind,source=/opt/secrets,target=/secrets,readonly \
  --mount type=bind,source=/opt/inventory,target=/opt/inventory,readonly \
  -e ANSIBLE_INVENTORY=/opt/inventory/production.yml \
  -e TARGET_HOSTS=all-network-devices \
  -e TARGET_FIRMWARE=auto-detect \
  -e UPGRADE_PHASE=loading \
  -e MAINTENANCE_WINDOW=false \
  -e CISCO_NXOS_SSH_KEY=/keys/cisco-nxos-key \
  -e CISCO_IOSXE_SSH_KEY=/keys/cisco-iosxe-key \
  -e FORTIOS_API_TOKEN="$(cat /secrets/fortios-api-token)" \
  -e OPENGEAR_SSH_KEY=/keys/opengear-key \
  -e OPENGEAR_API_TOKEN="$(cat /secrets/opengear-api-token)" \
  -e METAMAKO_SSH_KEY=/keys/metamako-key \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

### Podman Examples (Enterprise/RHEL)

For enterprise environments using Podman, replace `docker` with `podman` and add `:Z` flags for SELinux:

```bash
# Podman with SELinux context
podman run --rm \
  --name cisco-upgrade-rootless \
  -v /opt/firmware:/var/lib/network-upgrade/firmware:ro,Z \
  -v /opt/secrets/ssh-keys:/keys:ro,Z \
  -v /opt/inventory:/opt/inventory:ro,Z \
  -e ANSIBLE_INVENTORY=/opt/inventory/hosts.yml \
  -e TARGET_FIRMWARE=nxos64-cs.10.4.5.M.bin \
  -e TARGET_HOSTS=cisco-switches \
  -e CISCO_NXOS_SSH_KEY=/keys/cisco-key \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

### Important Notes

- **Read-Only Mounts**: Always use `:ro` flag for firmware directories to prevent accidental modification
- **File Permissions**: Ensure firmware files are readable by UID 1000 (container user)
- **Storage Space**: Plan for adequate storage - firmware images can be 500MB-2GB each
- **Backup Storage**: Mount a writable volume for configuration backups
- **Log Storage**: Mount a volume for persistent upgrade logs
- **SELinux**: Use `:Z` flag with Podman for proper SELinux labeling

For detailed platform-specific requirements, see [Platform File Transfer Guide](platform-file-transfer-guide.md).
