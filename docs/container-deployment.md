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

## Authentication Configuration

The container supports multiple authentication methods:

### Authentication Priority Order
1. **SSH Keys** (Preferred for SSH-based platforms)
2. **API Tokens** (Preferred for API-based platforms)  
3. **Username/Password** (Fallback when keys/tokens unavailable)

## SSH Key Mount Options

```bash
# Docker - Mount SSH keys
docker run --rm \
  -v ~/.ssh/id_rsa_cisco:/keys/cisco-key:ro \
  -v ~/.ssh/id_rsa_opengear:/keys/opengear-key:ro \
  -e VAULT_CISCO_NXOS_SSH_KEY=/keys/cisco-key \
  -e VAULT_OPENGEAR_SSH_KEY=/keys/opengear-key \
  ghcr.io/garryshtern/network-device-upgrade-system:latest syntax-check
```

## API Token Configuration

```bash
# Docker - API tokens
docker run --rm \
  -e VAULT_FORTIOS_API_TOKEN="your-fortios-api-token-here" \
  -e VAULT_OPENGEAR_API_TOKEN="your-opengear-api-token-here" \
  ghcr.io/garryshtern/network-device-upgrade-system:latest syntax-check
```

## Security Best Practices

- **Key Permissions**: chmod 600 for SSH keys
- **Read-Only Mounts**: Always use :ro for key mounts
- **Token Rotation**: Regularly rotate API tokens
- **Separate Keys**: Use different keys per platform

For detailed platform-specific requirements, see [Platform File Transfer Guide](PLATFORM_FILE_TRANSFER_GUIDE.md).
