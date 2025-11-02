# Documentation Index

Complete documentation for the Network Device Upgrade Management System - automated firmware upgrades across 1000+ heterogeneous network devices.

## 📚 Documentation Structure

### [User Guides](user-guides/) - Getting Started & Day-to-Day Operations

Essential documentation for operators and administrators:

- **[Container Deployment Guide](user-guides/container-deployment.md)** - Docker/Podman deployment
- **[Upgrade Workflow Guide](user-guides/upgrade-workflow-guide.md)** - How to perform upgrades
- **[Ansible Module Usage Guide](user-guides/ansible-module-usage-guide.md)** - Ansible module reference
- **[Comprehensive Project Guide](../CLAUDE.md)** - Complete system documentation including installation, parameters, and troubleshooting

### [Platform Guides](platform-guides/) - Platform-Specific Documentation

Platform-specific implementation details and standards:

- **[Firmware Naming Standards](platform-guides/firmware-naming-standards.md)** - Firmware file naming conventions
- **[Firmware Operations](platform-guides/firmware-operations.md)** - Firmware management procedures
- **[Platform File Transfer Guide](platform-guides/platform-file-transfer-guide.md)** - Secure file transfer methods
- **[Platform Implementation Status](platform-guides/platform-implementation-status.md)** - Feature support matrix

**Supported Platforms**: Cisco NX-OS, Cisco IOS-XE, FortiOS, Opengear, Metamako MOS

### [Deployment](deployment/) - System Deployment & Integration

Deployment, monitoring, and optimization guides:

- **[Grafana Integration Guide](deployment/grafana-integration.md)** - Dashboard deployment and configuration
- **[Storage Cleanup Guide](deployment/storage-cleanup-guide.md)** - Storage management procedures
- **[Container Build Optimization](deployment/container-build-optimization.md)** - Container optimization strategies

### [Testing](testing/) - Testing & Quality Assurance

Testing framework and quality assurance documentation:

- **[Testing Framework Guide](testing/testing-framework-guide.md)** - Comprehensive test suite documentation
- **[Molecule Testing Guide](testing/molecule-testing-guide.md)** - Container-based testing
- **[Pre-Commit Setup](testing/pre-commit-setup.md)** - Git hooks and validation

### [Architecture](architecture/) - System Design & Requirements

System architecture, design decisions, and requirements:

- **[Main Upgrade Workflow Architecture](architecture/main-upgrade-workflow.md)** - 7-step upgrade workflow with automatic dependency resolution
- **[GitHub Actions Workflow Architecture](architecture/workflow-architecture.md)** - CI/CD pipeline design
- **[Project Requirements](architecture/project-requirements.md)** - System requirements and specifications
- **[Technical Debt](architecture/technical-debt.md)** - Known limitations and future improvements

### [Internal](internal/) - Developer Documentation

Internal implementation notes and developer resources:

- **[SSH Key Privilege Drop Solution](internal/ssh-key-privilege-drop-solution.md)** - Container security implementation
- **[Deployment Guide](internal/deployment-guide.md)** - Deployment directory structure reference
- **[AI Code Reviews](internal/ai-code-reviews/)** - Automated code analysis reports

### [Archived](archived/) - Historical Documentation

Archived analysis reports and one-time assessments:

- Code analysis reports
- Workflow optimization studies
- Platform-specific analysis (NX-OS facts, connectivity validation)
- Historical testing summaries

### [GitHub Templates](github-templates/) - Repository Templates

GitHub issue and PR templates:

- Pull Request Template
- Bug Report Template
- Feature Request Template

## 🚀 Quick Start

New to the system? Start here:

1. **[Installation Guide](user-guides/installation-guide.md)** - Set up the system
2. **[Container Deployment](user-guides/container-deployment.md)** - Deploy with Docker/Podman
3. **[Upgrade Workflow Guide](user-guides/upgrade-workflow-guide.md)** - Run your first upgrade
4. **[Inventory Parameters](user-guides/inventory-parameters.md)** - Configure your environment

## 🔧 Common Tasks

### Running an Upgrade
See [Upgrade Workflow Guide](user-guides/upgrade-workflow-guide.md)

### Troubleshooting Issues
See [Troubleshooting Guide](user-guides/troubleshooting.md)

### Platform-Specific Configuration
See [Platform Guides](platform-guides/)

### Setting Up Monitoring
See [Grafana Integration Guide](deployment/grafana-integration.md)

## 📋 System Overview

### Key Features
- **Multi-Platform Support**: 5 major network device platforms
- **Scale**: Designed for 1000+ devices
- **Automation**: Ansible-based with AWX integration
- **Monitoring**: Real-time Grafana dashboards with InfluxDB
- **Container Support**: Docker and Podman deployment
- **Phase-Separated Upgrades**: Safe, controlled firmware upgrades
- **Security**: SHA512 verification, signature validation, SSH key authentication

### Architecture
- **Ansible**: Core automation engine
- **AWX**: Web UI and job orchestration
- **NetBox**: Device inventory and IPAM
- **Grafana**: Visualization and dashboards
- **InfluxDB v2**: Time-series metrics
- **Redis**: Job queuing and caching

### Supported Platforms
1. **Cisco NX-OS** - Data center switches (ISSU, EPLD support)
2. **Cisco IOS-XE** - Catalyst switches (install mode, bundle mode)
3. **FortiOS** - FortiGate firewalls (multi-step upgrades, HA support)
4. **Opengear** - Console servers (legacy CLI + modern API)
5. **Metamako MOS** - Low-latency network devices

## 📖 Additional Resources

### External Documentation
- [Ansible Documentation](https://docs.ansible.com/)
- [AWX Documentation](https://ansible.readthedocs.io/projects/awx/en/latest/)
- [NetBox Documentation](https://docs.netbox.dev/)
- [Grafana Documentation](https://grafana.com/docs/)

### Repository
- [GitHub Repository](https://github.com/garryshtern/network-device-upgrade-system)
- [Container Registry](https://github.com/garryshtern/network-device-upgrade-system/pkgs/container/network-device-upgrade-system)

## 🤝 Contributing

Please see:
- [Pull Request Template](github-templates/PULL_REQUEST_TEMPLATE.md)
- [Bug Report Template](github-templates/bug_report.md)
- [Feature Request Template](github-templates/feature_request.md)

## 📝 Documentation Standards

- All user-facing documentation in `user-guides/`
- Platform-specific details in `platform-guides/`
- Internal implementation notes in `internal/`
- One-time analysis reports in `archived/`
- Keep documentation updated with code changes
- Use clear, concise language
- Include examples where appropriate

---

**Last Updated**: October 2025  
**System Version**: 4.0.0  
**Documentation Version**: 2.0.0
