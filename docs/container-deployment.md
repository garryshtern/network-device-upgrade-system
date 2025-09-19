# Container Deployment Guide

This guide provides comprehensive instructions for deploying the Network Device Upgrade System container with full authentication support including SSH keys and API tokens.

## Quick Start

```bash
# Docker
docker pull ghcr.io/garryshtern/network-device-upgrade-system:latest
docker run --rm ghcr.io/garryshtern/network-device-upgrade-system:latest help

# Podman (RHEL8/9 compatible)
podman pull ghcr.io/garryshtern/network-device-upgrade-system:latest
podman run --rm ghcr.io/garryshtern/network-device-upgrade-system:latest help
```

## Environment Variables Reference

The container supports extensive configuration through environment variables:

### Core Ansible Configuration
- `ANSIBLE_PLAYBOOK` - Playbook to execute (default: main-upgrade-workflow.yml)
- `ANSIBLE_INVENTORY` - Inventory file (default: hosts.yml)
- `ANSIBLE_CONFIG` - Path to ansible.cfg file
- `ANSIBLE_VAULT_PASSWORD_FILE` - Path to vault password file

### Upgrade Configuration
- `TARGET_HOSTS` - Hosts to target (default: all)
- `TARGET_FIRMWARE` - Firmware version to install
- `UPGRADE_PHASE` - Phase: full, loading, installation, validation, rollback
- `MAINTENANCE_WINDOW` - Set to 'true' for installation phase

### SSH Key Authentication (Preferred Method)
- `VAULT_CISCO_NXOS_SSH_KEY` - SSH private key path for Cisco NX-OS devices
- `VAULT_CISCO_IOSXE_SSH_KEY` - SSH private key path for Cisco IOS-XE devices
- `VAULT_OPENGEAR_SSH_KEY` - SSH private key path for Opengear devices
- `VAULT_METAMAKO_SSH_KEY` - SSH private key path for Metamako devices

### API Token Authentication (API-based platforms)
- `VAULT_FORTIOS_API_TOKEN` - API token for FortiOS devices
- `VAULT_OPENGEAR_API_TOKEN` - API token for Opengear REST API

### Password Authentication (Fallback)
- `VAULT_CISCO_NXOS_PASSWORD` - Password for Cisco NX-OS devices
- `VAULT_CISCO_IOSXE_PASSWORD` - Password for Cisco IOS-XE devices
- `VAULT_FORTIOS_PASSWORD` - Password for FortiOS devices
- `VAULT_OPENGEAR_PASSWORD` - Password for Opengear devices
- `VAULT_METAMAKO_PASSWORD` - Password for Metamako devices

### Username Configuration
- `VAULT_CISCO_NXOS_USERNAME` - Username for Cisco NX-OS devices
- `VAULT_CISCO_IOSXE_USERNAME` - Username for Cisco IOS-XE devices
- `VAULT_FORTIOS_USERNAME` - Username for FortiOS devices
- `VAULT_OPENGEAR_USERNAME` - Username for Opengear devices
- `VAULT_METAMAKO_USERNAME` - Username for Metamako devices

### Additional Configuration
- `VAULT_IMAGE_SERVER_USERNAME` - Username for firmware image server
- `VAULT_IMAGE_SERVER_PASSWORD` - Password for firmware image server
- `VAULT_SNMP_COMMUNITY` - SNMP community string for monitoring

## Authentication Configuration

The container supports multiple authentication methods:

### Authentication Priority Order
1. **SSH Keys** (Preferred for SSH-based platforms)
2. **API Tokens** (Preferred for API-based platforms)
3. **Username/Password** (Fallback when keys/tokens unavailable)

## Secure SSH Key Mount Options

### Method 1: File Mounts (Recommended)

```bash
# Docker - Mount SSH keys securely
docker run --rm \
  -v ~/.ssh/id_rsa_cisco:/keys/cisco-key:ro \
  -v ~/.ssh/id_rsa_opengear:/keys/opengear-key:ro \
  -v ~/.ssh/id_rsa_metamako:/keys/metamako-key:ro \
  -e VAULT_CISCO_NXOS_SSH_KEY=/keys/cisco-key \
  -e VAULT_OPENGEAR_SSH_KEY=/keys/opengear-key \
  -e VAULT_METAMAKO_SSH_KEY=/keys/metamako-key \
  ghcr.io/garryshtern/network-device-upgrade-system:latest syntax-check

# Podman - Mount SSH keys with SELinux context
podman run --rm \
  -v ~/.ssh/id_rsa_cisco:/keys/cisco-key:ro,Z \
  -v ~/.ssh/id_rsa_opengear:/keys/opengear-key:ro,Z \
  -e VAULT_CISCO_NXOS_SSH_KEY=/keys/cisco-key \
  -e VAULT_OPENGEAR_SSH_KEY=/keys/opengear-key \
  ghcr.io/garryshtern/network-device-upgrade-system:latest syntax-check
```

### Method 2: External Secrets (Production Recommended)

```bash
# Using external secret management (Kubernetes, Docker Secrets)
docker run --rm \
  --mount type=bind,source=/run/secrets/cisco-ssh-key,target=/keys/cisco-key,readonly \
  --mount type=bind,source=/run/secrets/opengear-ssh-key,target=/keys/opengear-key,readonly \
  -e VAULT_CISCO_NXOS_SSH_KEY=/keys/cisco-key \
  -e VAULT_OPENGEAR_SSH_KEY=/keys/opengear-key \
  ghcr.io/garryshtern/network-device-upgrade-system:latest dry-run
```

## Secure API Token Configuration

### Method 1: Environment Variables (Development)

```bash
# Read tokens from files (secure)
docker run --rm \
  -e VAULT_FORTIOS_API_TOKEN="$(cat ~/.secrets/fortios-token)" \
  -e VAULT_OPENGEAR_API_TOKEN="$(cat ~/.secrets/opengear-token)" \
  ghcr.io/garryshtern/network-device-upgrade-system:latest syntax-check
```

### Method 2: External Secrets (Production Recommended)

```bash
# Using Docker secrets or external secret management
docker run --rm \
  --mount type=bind,source=/run/secrets/fortios-api-token,target=/tmp/fortios-token,readonly \
  --mount type=bind,source=/run/secrets/opengear-api-token,target=/tmp/opengear-token,readonly \
  -e VAULT_FORTIOS_API_TOKEN="$(cat /tmp/fortios-token)" \
  -e VAULT_OPENGEAR_API_TOKEN="$(cat /tmp/opengear-token)" \
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
  -e VAULT_CISCO_NXOS_SSH_KEY=/keys/cisco-nxos-key \
  -e VAULT_CISCO_IOSXE_SSH_KEY=/keys/cisco-iosxe-key \
  -e VAULT_FORTIOS_API_TOKEN="$(cat /opt/secrets/fortios-api-token)" \
  -e VAULT_OPENGEAR_SSH_KEY=/keys/opengear-key \
  -e VAULT_OPENGEAR_API_TOKEN="$(cat /opt/secrets/opengear-api-token)" \
  -e VAULT_METAMAKO_SSH_KEY=/keys/metamako-key \
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

# Interactive debugging
docker run --rm -it network-upgrade-system shell

# Run test suite
docker run --rm network-upgrade-system test
```

For detailed platform-specific requirements, see [Platform File Transfer Guide](platform-file-transfer-guide.md).
