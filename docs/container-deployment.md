# Container Deployment Guide

Network Device Upgrade System - Container Deployment

## Overview

The Network Device Upgrade System is available as a production-ready container image optimized for enterprise environments, including RHEL8/9 with rootless Podman support.

## Container Features

- ✅ **Minimal Size**: Alpine-based image (~200MB)
- ✅ **Security**: Non-root execution (UID/GID 1000)
- ✅ **Compatibility**: RHEL8/9, Docker, Podman 4.9.4+, Kubernetes
- ✅ **Multi-Architecture**: AMD64 and ARM64 support
- ✅ **Latest Stack**: Ansible 12.0.0, Python 3.13.7
- ✅ **Pre-installed Collections**: All required Ansible collections included

## Quick Start

### Docker

```bash
# Pull the latest image
docker pull ghcr.io/garryshtern/network-device-upgrade-system:latest

# Run syntax check (default)
docker run --rm ghcr.io/garryshtern/network-device-upgrade-system:latest

# Get help and usage information
docker run --rm ghcr.io/garryshtern/network-device-upgrade-system:latest help

# Interactive shell for exploration
docker run --rm -it ghcr.io/garryshtern/network-device-upgrade-system:latest shell
```

### Podman (RHEL8/9)

```bash
# Pull with podman (rootless)
podman pull ghcr.io/garryshtern/network-device-upgrade-system:latest

# Run syntax check
podman run --rm ghcr.io/garryshtern/network-device-upgrade-system:latest

# Run with custom inventory
podman run --rm -v ./inventory:/opt/inventory:Z \
  -e ANSIBLE_INVENTORY=/opt/inventory/hosts.yml \
  ghcr.io/garryshtern/network-device-upgrade-system:latest dry-run
```

## Available Commands

The container supports several execution modes via the entrypoint script:

| Command | Description | Example |
|---------|-------------|---------|
| `syntax-check` | Validate playbook syntax (default) | `docker run --rm image:tag syntax-check` |
| `dry-run` | Execute in check mode (no changes) | `docker run --rm image:tag dry-run` |
| `run` | Execute playbook (make changes) | `docker run --rm image:tag run` |
| `test` | Run comprehensive test suite | `docker run --rm image:tag test` |
| `shell` | Interactive bash shell | `docker run --rm -it image:tag shell` |
| `help` | Show usage information | `docker run --rm image:tag help` |

## Environment Variables

Configure the container behavior using environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `ANSIBLE_PLAYBOOK` | Playbook to execute | `ansible-content/playbooks/main-upgrade-workflow.yml` |
| `ANSIBLE_INVENTORY` | Inventory file path | `ansible-content/inventory/hosts.yml` |
| `TARGET_HOSTS` | Hosts to target | `all` |
| `TARGET_FIRMWARE` | Firmware version to install | (required for upgrades) |
| `UPGRADE_PHASE` | Phase: full, loading, installation, validation, rollback | `full` |
| `MAINTENANCE_WINDOW` | Set to 'true' for installation phase | `false` |
| `ANSIBLE_VAULT_PASSWORD_FILE` | Path to vault password file | (optional) |

## Production Examples

### 1. Firmware Loading Phase (Business Hours Safe)

```bash
docker run --rm \
  -e TARGET_FIRMWARE="9.3.12" \
  -e TARGET_HOSTS="cisco-datacenter-switches" \
  -e UPGRADE_PHASE="loading" \
  -e MAINTENANCE_WINDOW="false" \
  -v ./production-inventory:/opt/inventory:ro \
  -v ./ansible-vault-key:/opt/vault-key:ro \
  -e ANSIBLE_INVENTORY="/opt/inventory/production.yml" \
  -e ANSIBLE_VAULT_PASSWORD_FILE="/opt/vault-key" \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

### 2. Installation Phase (Maintenance Window)

```bash
docker run --rm \
  -e TARGET_FIRMWARE="9.3.12" \
  -e TARGET_HOSTS="cisco-datacenter-switches" \
  -e UPGRADE_PHASE="installation" \
  -e MAINTENANCE_WINDOW="true" \
  -v ./production-inventory:/opt/inventory:ro \
  -v ./ansible-vault-key:/opt/vault-key:ro \
  -e ANSIBLE_INVENTORY="/opt/inventory/production.yml" \
  -e ANSIBLE_VAULT_PASSWORD_FILE="/opt/vault-key" \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

### 3. Health Check Playbook

```bash
docker run --rm \
  -e ANSIBLE_PLAYBOOK="ansible-content/playbooks/health-check.yml" \
  -v ./production-inventory:/opt/inventory:ro \
  -e ANSIBLE_INVENTORY="/opt/inventory/production.yml" \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

### 4. Dry Run with Custom Playbook

```bash
docker run --rm \
  -e ANSIBLE_PLAYBOOK="ansible-content/playbooks/config-backup.yml" \
  -e TARGET_HOSTS="critical-switches" \
  -v ./production-inventory:/opt/inventory:ro \
  -e ANSIBLE_INVENTORY="/opt/inventory/production.yml" \
  ghcr.io/garryshtern/network-device-upgrade-system:latest dry-run
```

### 5. Device Inventory and Firmware Management

```bash
# Create device inventory file
cat > device-inventory.yml << 'EOF'
all:
  children:
    cisco_nxos:
      hosts:
        nx-core-01:
          ansible_host: 10.1.1.10
          ansible_network_os: nxos
          platform_type: cisco_nxos
          firmware_version: "9.3.10"
          target_version: "10.1.2"
          device_model: "N9K-C93180YC-EX"
          issu_capable: true
        nx-core-02:
          ansible_host: 10.1.1.11
          ansible_network_os: nxos
          platform_type: cisco_nxos
          firmware_version: "9.3.10"
          target_version: "10.1.2"
          device_model: "N9K-C93180YC-EX"
          issu_capable: true
      vars:
        ansible_user: admin
        ansible_password: "{{ vault_cisco_password }}"

    cisco_iosxe:
      hosts:
        cat9k-01:
          ansible_host: 10.1.2.10
          ansible_network_os: ios
          platform_type: cisco_iosxe
          firmware_version: "17.09.04a"
          target_version: "17.12.01"
          device_model: "C9300-48P"
          install_mode_capable: true
      vars:
        ansible_user: admin
        ansible_password: "{{ vault_cisco_password }}"
EOF

# Run upgrade with device inventory and firmware images
docker run --rm \
  -v ./device-inventory.yml:/opt/inventory/devices.yml:ro \
  -v ./firmware-images:/opt/firmware:ro \
  -v ./vault-password:/opt/vault-key:ro \
  -e ANSIBLE_INVENTORY="/opt/inventory/devices.yml" \
  -e ANSIBLE_VAULT_PASSWORD_FILE="/opt/vault-key" \
  -e TARGET_FIRMWARE="10.1.2" \
  -e TARGET_HOSTS="cisco_nxos" \
  -e UPGRADE_PHASE="loading" \
  -e firmware_base_path="/opt/firmware" \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

## RHEL8/9 with Podman

### Rootless Podman Setup

```bash
# Enable user namespaces (if not already enabled)
echo 'user.max_user_namespaces=28633' | sudo tee -a /etc/sysctl.d/userns.conf
sudo sysctl -p /etc/sysctl.d/userns.conf

# Configure subuid and subgid for your user (if not already configured)
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $(whoami)

# Pull and run with podman (multi-architecture manifest support)
podman pull ghcr.io/garryshtern/network-device-upgrade-system:latest
podman run --rm ghcr.io/garryshtern/network-device-upgrade-system:latest

# Verify multi-architecture manifest
podman manifest inspect ghcr.io/garryshtern/network-device-upgrade-system:latest

# Example with device inventory and firmware images
podman run --rm \
  -v ./device-inventory.yml:/opt/inventory/devices.yml:Z \
  -v ./firmware-images:/opt/firmware:Z \
  -v ./vault-password:/opt/vault-key:Z \
  -e ANSIBLE_INVENTORY="/opt/inventory/devices.yml" \
  -e ANSIBLE_VAULT_PASSWORD_FILE="/opt/vault-key" \
  -e TARGET_FIRMWARE="10.1.2" \
  -e TARGET_HOSTS="cisco_nxos" \
  -e UPGRADE_PHASE="loading" \
  -e firmware_base_path="/opt/firmware" \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

### SELinux Considerations

When mounting volumes with SELinux enabled, use the `:Z` flag for private mounts or `:z` for shared mounts:

```bash
# Private mount (recommended for sensitive files)
podman run --rm -v ./inventory:/opt/inventory:Z \
  ghcr.io/garryshtern/network-device-upgrade-system:latest

# Shared mount (for read-only shared data)
podman run --rm -v ./shared-configs:/opt/configs:z \
  ghcr.io/garryshtern/network-device-upgrade-system:latest
```

## Kubernetes Deployment

### Job Example

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: network-upgrade-loading-phase
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: network-upgrade
        image: ghcr.io/garryshtern/network-device-upgrade-system:latest
        args: ["run"]
        env:
        - name: TARGET_FIRMWARE
          value: "9.3.12"
        - name: TARGET_HOSTS
          value: "cisco-datacenter-switches"
        - name: UPGRADE_PHASE
          value: "loading"
        - name: MAINTENANCE_WINDOW
          value: "false"
        - name: ANSIBLE_INVENTORY
          value: "/opt/inventory/production.yml"
        - name: ANSIBLE_VAULT_PASSWORD_FILE
          value: "/opt/vault/password"
        volumeMounts:
        - name: inventory
          mountPath: /opt/inventory
          readOnly: true
        - name: vault-password
          mountPath: /opt/vault
          readOnly: true
        securityContext:
          runAsNonRoot: true
          runAsUser: 1000
          runAsGroup: 1000
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
      volumes:
      - name: inventory
        configMap:
          name: ansible-inventory
      - name: vault-password
        secret:
          name: ansible-vault-password
```

### CronJob for Scheduled Operations

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: network-health-check
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: health-check
            image: ghcr.io/garryshtern/network-device-upgrade-system:latest
            args: ["run"]
            env:
            - name: ANSIBLE_PLAYBOOK
              value: "ansible-content/playbooks/health-check.yml"
            - name: ANSIBLE_INVENTORY
              value: "/opt/inventory/production.yml"
            volumeMounts:
            - name: inventory
              mountPath: /opt/inventory
              readOnly: true
          volumes:
          - name: inventory
            configMap:
              name: ansible-inventory
```

## Security Best Practices

### 1. Non-Root Execution
The container runs as user `ansible` (UID 1000) and never requires root privileges.

### 2. Vault Password Management
```bash
# Create secure vault password file
echo "your-vault-password" | sudo tee /opt/vault-password
sudo chmod 600 /opt/vault-password
sudo chown 1000:1000 /opt/vault-password

# Use with container
docker run --rm \
  -v /opt/vault-password:/opt/vault-password:ro \
  -e ANSIBLE_VAULT_PASSWORD_FILE="/opt/vault-password" \
  ghcr.io/garryshtern/network-device-upgrade-system:latest
```

### 3. Read-Only Mounts
Mount configuration files as read-only when possible:

```bash
docker run --rm \
  -v ./inventory:/opt/inventory:ro \
  -v ./group_vars:/opt/group_vars:ro \
  ghcr.io/garryshtern/network-device-upgrade-system:latest
```

### 4. Network Isolation
Run in isolated networks for production environments:

```bash
# Create isolated network
docker network create --driver bridge network-automation

# Run container in isolated network
docker run --rm --network network-automation \
  ghcr.io/garryshtern/network-device-upgrade-system:latest
```

## Troubleshooting

### Common Issues

1. **Permission Denied on RHEL/CentOS**
   ```bash
   # Ensure SELinux labels are correct
   ls -lZ /path/to/mounted/files
   # Use :Z flag for private mounts
   podman run --rm -v ./files:/opt/files:Z image:tag
   ```

2. **Container Won't Start**
   ```bash
   # Check container logs
   docker logs container-id
   # Run with shell to debug
   docker run --rm -it --entrypoint /bin/bash image:tag
   ```

3. **Ansible Collections Not Found**
   ```bash
   # Verify collections in container
   docker run --rm image:tag shell
   # Inside container:
   ansible-galaxy collection list
   ```

### Debug Mode

Enable verbose Ansible output:
```bash
docker run --rm \
  -e ANSIBLE_VERBOSITY=3 \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

## Container Registry

### Available Tags

- `latest` - Latest stable release
- `main` - Latest development build
- `v1.x.x` - Specific version tags
- `main-abc1234` - Branch and commit SHA

### Multi-Architecture Support

The container images are built for multiple architectures:
- `linux/amd64` - Intel/AMD 64-bit
- `linux/arm64` - ARM 64-bit (Apple M1/M2, AWS Graviton)

Pull the appropriate architecture automatically:
```bash
docker pull ghcr.io/garryshtern/network-device-upgrade-system:latest
```

## Monitoring and Logging

### Health Checks

The container includes built-in health checks:
```bash
# Check container health
docker inspect --format='{{.State.Health.Status}}' container-id

# View health check logs
docker inspect --format='{{range .State.Health.Log}}{{.Output}}{{end}}' container-id
```

### Log Collection

Collect logs for monitoring:
```bash
# Run with log driver
docker run --rm \
  --log-driver json-file \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run

# Export logs
docker logs container-id > upgrade-logs.txt
```

## Performance Considerations

### Resource Limits

Set appropriate resource limits:
```bash
docker run --rm \
  --memory=1g \
  --cpus=2 \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

### Caching

Use volume caching for better performance with repeated runs:
```bash
docker run --rm \
  -v ansible-cache:/home/ansible/.ansible \
  ghcr.io/garryshtern/network-device-upgrade-system:latest
```

## Support

For container-related issues:
- Check the [troubleshooting section](#troubleshooting) above
- Review container logs: `docker logs <container-id>`
- Test with interactive shell: `docker run -it image:tag shell`
- Report issues at: https://github.com/garryshtern/network-device-upgrade-system/issues

For general usage and Ansible questions, refer to the main documentation.