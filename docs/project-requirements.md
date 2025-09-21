# Network Device Upgrade System - Complete Build Requirements

## Overview

Complete requirements specification for building the Network Device Upgrade Management System from scratch. This system automates firmware upgrades across 1000+ heterogeneous network devices using Ansible with AWX orchestration and comprehensive validation.

## Quick Start Requirements Summary

### Minimum Build Requirements
- **OS**: RHEL/CentOS 8+, Ubuntu 20.04+, Rocky/Alma Linux 8+
- **CPU**: 4 cores minimum (8+ recommended for production)
- **RAM**: 8GB minimum (16GB+ recommended for production)
- **Storage**: 100GB minimum (500GB+ recommended for firmware storage)
- **Python**: 3.13+ with pip
- **Ansible**: 11.9.0+ (ansible-core 2.19.1+) - Latest stable
- **Container Runtime**: Docker 20.10+ OR Podman 3.0+ (RHEL8/9 compatible)
- **Git**: 2.30+ for repository management

### Core System Dependencies
- **Ansible**: 11.9.0+ (includes ansible-core 2.19.1+)
- **Python**: 3.13+ with pip package manager
- **Operating Systems**:
  - **Production**: RHEL 8+, CentOS 8+, Rocky Linux 8+, AlmaLinux 8+
  - **Ubuntu**: 20.04 LTS or higher (22.04+ recommended)
  - **Development**: macOS 12+ (for development and testing)

### Supported Network Platforms
- **Cisco NX-OS**: Version 9.2+ (SSH + NXAPI) - ISSU support
- **Cisco IOS-XE**: Version 16.12+ (SSH) - Install Mode support
- **FortiOS**: Version 6.4+ (HTTPS API) - HA coordination
- **Opengear**: Console servers with firmware 5.14+ (SSH + REST API) - Legacy/Modern detection
- **Metamako MOS**: Version 0.39+ (SSH) - Ultra-low latency switches

## Build From Scratch Instructions

### Step 1: System Preparation

```bash
# Update system packages
sudo dnf update -y        # RHEL/CentOS/Rocky/Alma
sudo apt update && sudo apt upgrade -y  # Ubuntu

# Install base development tools
sudo dnf groupinstall "Development Tools" -y  # RHEL-based
sudo apt install build-essential git curl -y  # Ubuntu

# Install Python 3.13+ and pip
sudo dnf install python3 python3-pip -y  # RHEL-based
sudo apt install python3 python3-pip -y  # Ubuntu
```

### Step 2: Install Ansible and Collections

```bash
# Install latest Ansible (includes ansible-core 2.19.1+)
pip3 install --user 'ansible>=11.9.0'

# Verify installation
ansible --version
# Expected output: ansible [core 2.19.1+]

# Clone the repository
git clone https://github.com/company/network-device-upgrade-system.git
cd network-device-upgrade-system

# Install required Ansible collections (exact versions for production)
ansible-galaxy collection install -r ansible-content/collections/requirements.yml --force
```

### Step 3: Required Ansible Collections (Production Versions)

The system requires these exact collection versions for production use:

```yaml
# From ansible-content/collections/requirements.yml
collections:
  - cisco.nxos:11.0.0        # Cisco NX-OS automation
  - cisco.ios:11.0.0         # Cisco IOS-XE automation
  - fortinet.fortios:2.4.0   # FortiOS automation
  - ansible.netcommon:8.1.0  # Network common utilities
  - community.general:11.3.0 # General utility modules
  - ansible.posix:1.5.0      # POSIX system modules
  - community.crypto:2.15.0  # Cryptographic operations
  - ansible.utils:6.0.0      # Ansible utility modules
  - netbox.netbox:3.18.0     # NetBox integration
```

### Step 4: Container Runtime Installation (Choose One)

**Option A: Docker Installation**
```bash
# Docker (Ubuntu/Debian)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Docker (RHEL/CentOS)
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install docker-ce docker-ce-cli containerd.io -y
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
```

**Option B: Podman Installation (Recommended for RHEL)**
```bash
# Podman (RHEL/CentOS/Rocky/Alma)
sudo dnf install podman -y

# Podman (Ubuntu)
sudo apt install podman -y

# Enable rootless containers
sudo systemctl enable --now podman.socket
loginctl enable-linger $USER
```

### Step 5: Testing and Validation

```bash
# Install testing dependencies (optional but recommended)
pip3 install --user molecule 'molecule-plugins[docker]' pytest-testinfra yamllint ansible-lint

# Test installation
ansible-playbook --syntax-check ansible-content/playbooks/main-upgrade-workflow.yml

# Run mock device tests (no physical devices required)
ansible-playbook -i tests/mock-inventories/all-platforms.yml --check \
  ansible-content/playbooks/main-upgrade-workflow.yml

# Run comprehensive test suite
./tests/run-all-tests.sh
```

### Step 6: Container Deployment (Production Ready)

```bash
# Pull production container (multi-architecture: amd64/arm64)
docker pull ghcr.io/garryshtern/network-device-upgrade-system:latest
# OR
podman pull ghcr.io/garryshtern/network-device-upgrade-system:latest

# Verify container functionality
docker run --rm ghcr.io/garryshtern/network-device-upgrade-system:latest help
# OR
podman run --rm ghcr.io/garryshtern/network-device-upgrade-system:latest help
```

## Production Deployment Requirements

### Full System Deployment Options

**Option 1: Native systemd Services (Recommended)**
- Complete installation via `./install/setup-system.sh`
- AWX, NetBox, Redis, Nginx as systemd user services
- Single server deployment optimized for 1000+ devices
- See: [Installation Guide](installation-guide.md)

**Option 2: Container-based Deployment**
- AWX and NetBox in containers with Podman/Docker
- External monitoring integration (InfluxDB v2, Grafana)
- Multi-node support for high availability
- See: [Container Deployment Guide](container-deployment.md)

### Infrastructure Components

#### Core Services Required
- **AWX**: Job orchestration and web interface
- **NetBox**: Device inventory and IPAM (pre-existing or new)
- **Redis**: Job queuing and caching
- **Nginx**: Web proxy and SSL termination
- **Telegraf**: Metrics collection agent

#### Optional Integration Services
- **InfluxDB v2**: Time-series metrics storage
- **Grafana**: Dashboard visualization and alerting
- **PostgreSQL**: Database for AWX/NetBox (if not using SQLite)

### Network Infrastructure Requirements

#### Firewall Rules
```bash
# Required ports for system operation
22/tcp   # SSH to network devices
443/tcp  # HTTPS web interface
8043/tcp # AWX web interface
8000/tcp # NetBox web interface (if separate)
```

#### Network Connectivity
- **Management Network**: Dedicated VLAN for device management
- **Internet Access**: For package downloads and container pulls
- **DNS Resolution**: Forward and reverse DNS for all devices
- **NTP Synchronization**: Accurate time synchronization

## Authentication Requirements

### SSH Key Authentication (Preferred)
- **Key Format**: OpenSSH RSA, ECDSA, or Ed25519
- **Key Permissions**: 600 (read-write for owner only)
- **Key Storage**: Secure key management system or encrypted storage
- **Separate Keys**: Different keys per platform/environment for security isolation

### API Token Authentication
- **FortiOS**: API tokens with appropriate permissions for firmware management
- **Opengear**: REST API tokens for firmware upload and management
- **Token Rotation**: Regular rotation schedule (recommended monthly)
- **Minimal Permissions**: Tokens with only required permissions

### Password Authentication (Fallback)
- **Encryption**: All passwords must be encrypted using Ansible Vault
- **Complexity**: Follow organizational password policy
- **Rotation**: Regular password rotation schedule

## Network Requirements

### Connectivity
- **Management Network**: Dedicated management network for device access
- **Bandwidth**: Minimum 100 Mbps for firmware transfer
- **Protocols**: HTTPS, SSH, SCP, SFTP support
- **Firewall**: Appropriate firewall rules for management protocols

### Security
- **Network Segmentation**: Isolated management network
- **VPN Access**: Secure VPN access for remote operations
- **Monitoring**: Network traffic monitoring and logging
- **Access Control**: Role-based access control (RBAC)

## Hardware and Storage Requirements

### Production Server Specifications
- **CPU**: 4 cores minimum (8+ cores for 1000+ devices)
- **Memory**: 8GB RAM minimum (16GB+ for production workloads)
- **Storage**: 100GB minimum (500GB+ recommended)
  - SSD preferred for database and application storage
  - Additional storage for firmware repository
- **Network**: Gigabit Ethernet minimum, dual NICs recommended

### Firmware Repository Management
- **Storage Location**: `/opt/network-upgrade/firmware/` (configurable)
- **Directory Structure**: Organized by vendor (cisco/, fortinet/, opengear/, metamako/)
- **Security**: SHA512 hash verification for all firmware images
- **Access Control**: Restricted file permissions (644 for images, 755 for directories)
- **Backup Strategy**: Regular backup of firmware repository

### Container System Requirements
- **Container Runtime**: Docker 20.10+ or Podman 3.0+ (4.0+ recommended)
- **Architecture Support**: amd64/arm64 multi-architecture images
- **Security**: Rootless container execution (UID 1000)
- **SELinux**: Compatible with SELinux enforcing mode (RHEL/CentOS)
- **Registry Access**: GitHub Container Registry (ghcr.io) connectivity

## Common Installation Issues and Solutions

### Ansible Compatibility Issues
**Problem**: `ModuleNotFoundError: No module named 'ansible.module_utils.six.moves'`
**Solution**: Update to latest Ansible version
```bash
pip uninstall ansible ansible-core ansible-base -y
pip install 'ansible>=11.9.0'
ansible-galaxy collection install -r ansible-content/collections/requirements.yml --force
```

**Problem**: SSL certificate errors during collection installation
**Solution**: Use --ignore-certs flag
```bash
ansible-galaxy collection install -r ansible-content/collections/requirements.yml --ignore-certs --force
```

### Container Runtime Issues
**Problem**: Permission denied accessing Docker socket
**Solution**: Add user to docker group
```bash
sudo usermod -aG docker $USER
# Log out and log back in
```

**Problem**: Podman rootless containers not persisting after reboot
**Solution**: Enable lingering for user
```bash
loginctl enable-linger $USER
```

### Network Connectivity Issues
**Problem**: Cannot reach network devices from Ansible control node
**Solution**: Verify routing and firewall rules
```bash
# Test connectivity
ping <device-ip>
ssh <username>@<device-ip>
# Check firewall rules
sudo firewall-cmd --list-all  # RHEL/CentOS
sudo ufw status              # Ubuntu
```

## Development Requirements

### Development Environment
- **IDE**: VS Code with Ansible extension recommended
- **Git**: Version 2.30+
- **Testing**: Local Docker/Podman for container testing
- **Linting**: yamllint, ansible-lint, shellcheck

### Testing Framework
- **Mock Devices**: Container-based mock device simulation
- **Unit Tests**: Ansible task and variable validation
- **Integration Tests**: End-to-end workflow testing
- **Performance Tests**: Load testing with 100+ devices

## Security Requirements

### Data Protection
- **Encryption**: All sensitive data encrypted at rest and in transit
- **Key Management**: Secure key management system
- **Audit Logging**: Comprehensive audit trail for all operations
- **Backup**: Encrypted backups of configurations and keys

### Access Control
- **RBAC**: Role-based access control implementation
- **MFA**: Multi-factor authentication for administrative access
- **Session Management**: Secure session management and timeout
- **Privilege Escalation**: Controlled privilege escalation mechanisms

### Compliance
- **Standards**: Compliance with organizational security standards
- **Vulnerability Management**: Regular security scans and updates
- **Incident Response**: Security incident response procedures
- **Documentation**: Security documentation and procedures

## Performance Requirements

### Scalability
- **Device Capacity**: Support for 1000+ devices
- **Concurrent Operations**: 50+ concurrent device upgrades
- **Batch Processing**: Efficient batch processing capabilities
- **Resource Management**: Optimal resource utilization

### Reliability
- **Uptime**: 99.9% system availability
- **Error Handling**: Graceful error handling and recovery
- **Rollback**: Automatic rollback on upgrade failures
- **Monitoring**: Real-time monitoring and alerting

## Operational Requirements

### Monitoring
- **Metrics**: Real-time upgrade progress metrics
- **Alerting**: Proactive alerting for failures
- **Dashboards**: Grafana dashboards for visualization
- **Logging**: Centralized logging system

### Backup and Recovery
- **Configuration Backup**: Automated device configuration backup
- **Firmware Rollback**: Automated firmware rollback capabilities
- **System Backup**: Regular system backup procedures
- **Disaster Recovery**: Disaster recovery procedures and testing

### Maintenance
- **Update Schedule**: Regular system update schedule
- **Maintenance Windows**: Planned maintenance windows
- **Change Management**: Change management procedures
- **Documentation**: Up-to-date operational documentation

## Integration Requirements

### External Systems
- **NetBox**: Device inventory and IPAM integration
- **InfluxDB**: Time-series database for metrics
- **Grafana**: Visualization and dashboard platform
- **LDAP/AD**: Authentication system integration

### API Integration
- **REST APIs**: RESTful API integration capabilities
- **Webhooks**: Webhook support for event notifications
- **SNMP**: SNMP monitoring integration
- **Syslog**: Syslog integration for device logs

## Compliance Requirements

### Documentation
- **Architecture**: System architecture documentation
- **Procedures**: Standard operating procedures
- **Training**: User training materials
- **Change Log**: Change management documentation

### Validation
- **Testing**: Comprehensive testing procedures
- **Verification**: Upgrade verification procedures
- **Certification**: Platform certification requirements
- **Reporting**: Compliance reporting capabilities

## Support Requirements

### Technical Support
- **Documentation**: Comprehensive technical documentation
- **Troubleshooting**: Troubleshooting guides and procedures
- **Knowledge Base**: Searchable knowledge base
- **Community**: Community support resources

### Training
- **User Training**: End-user training programs
- **Administrator Training**: System administrator training
- **Best Practices**: Best practices documentation
- **Certification**: Optional certification programs

## Complete System Validation Checklist

Use this checklist to verify your build from scratch installation:

### Base System Validation
- [ ] Operating system meets minimum requirements (RHEL 8+, Ubuntu 20.04+)
- [ ] Python 3.13+ installed and accessible
- [ ] Ansible 11.9.0+ installed with ansible-core 2.19.1+
- [ ] Git 2.30+ installed for repository management
- [ ] Container runtime (Docker/Podman) installed and functional

### Repository and Collections
- [ ] Repository cloned successfully from GitHub
- [ ] All Ansible collections installed from requirements.yml
- [ ] Syntax validation passes: `ansible-playbook --syntax-check ansible-content/playbooks/main-upgrade-workflow.yml`
- [ ] Collection versions match production requirements

### Testing Framework Validation
- [ ] Mock inventory tests pass: `ansible-playbook -i tests/mock-inventories/all-platforms.yml --check ansible-content/playbooks/main-upgrade-workflow.yml`
- [ ] Comprehensive test suite passes: `./tests/run-all-tests.sh`
- [ ] Container deployment functional: `docker run --rm ghcr.io/garryshtern/network-device-upgrade-system:latest help`

### Network and Security
- [ ] Network connectivity to target device management networks
- [ ] SSH access to network devices configured
- [ ] Firewall rules configured for required ports
- [ ] SSL certificates configured for web interfaces

### Production Readiness
- [ ] AWX or native service deployment completed
- [ ] NetBox integration configured
- [ ] Monitoring integration (Telegraf/InfluxDB) operational
- [ ] Backup and recovery procedures documented
- [ ] Security hardening applied per requirements

### Documentation and Training
- [ ] All installation documentation reviewed
- [ ] Platform-specific guides available for target devices
- [ ] Operational procedures documented
- [ ] Team training completed

### Final Validation
- [ ] System health check passes
- [ ] Test upgrade performed on non-production devices
- [ ] Rollback procedures tested and validated
- [ ] Production cutover plan approved

## Quick Reference - Essential Commands

```bash
# Verify installation
ansible --version
ansible-galaxy collection list

# Test playbook syntax
ansible-playbook --syntax-check ansible-content/playbooks/main-upgrade-workflow.yml

# Run mock device tests (no hardware required)
ansible-playbook -i tests/mock-inventories/all-platforms.yml --check \
  ansible-content/playbooks/main-upgrade-workflow.yml

# Run full test suite
./tests/run-all-tests.sh

# Container deployment test
docker run --rm ghcr.io/garryshtern/network-device-upgrade-system:latest help

# System deployment (production)
./install/setup-system.sh
```

## Support and Next Steps

After completing the build from scratch:

1. **Review Documentation**: [Installation Guide](installation-guide.md) for detailed deployment
2. **Understand Workflows**: [Upgrade Workflow Guide](upgrade-workflow-guide.md) for operations
3. **Platform Specifics**: [Platform Implementation Status](platform-implementation-status.md) for vendor details
4. **Testing Framework**: [Testing Framework Guide](testing-framework-guide.md) for comprehensive testing
5. **Container Options**: [Container Deployment Guide](container-deployment.md) for container deployment

This requirements document provides everything needed to build the Network Device Upgrade Management System from scratch on any supported platform.