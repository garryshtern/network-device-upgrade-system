# Documentation Index

Complete documentation for the Network Device Upgrade Management System - automated firmware upgrades across 1000+ heterogeneous network devices.

## 📚 Documentation Structure

### [User Guides](user-guides/) - Getting Started & Day-to-Day Operations

Essential documentation for operators and administrators:

- **[Upgrade Workflow Guide](user-guides/upgrade-workflow-guide.md)** - How to perform upgrades
- **[Container Deployment Guide](user-guides/container-deployment.md)** - Docker/Podman deployment
- **[Complete Project Guide](../CLAUDE.md)** - Installation, configuration, parameters, and troubleshooting

### [Platform Guides](platform-guides/) - Platform-Specific Documentation

Platform-specific implementation details and feature support:

- **[Platform Implementation Status](platform-guides/platform-implementation-status.md)** - Feature support matrix for all platforms

**Supported Platforms**: Cisco NX-OS, Cisco IOS-XE, FortiOS, Opengear, Metamako MOS

### [Deployment](deployment/) - System Deployment & Integration

Deployment, monitoring, and optimization guides:

- **[Grafana Integration Guide](deployment/grafana-integration.md)** - Dashboard deployment and configuration
- **[Storage Cleanup Guide](deployment/storage-cleanup-guide.md)** - Storage management procedures
- **[Container Build Optimization](deployment/container-build-optimization.md)** - Container optimization strategies

### [Testing](testing/) - Testing & Quality Assurance

Testing framework and quality assurance documentation:

- **[Pre-Commit Setup](testing/pre-commit-setup.md)** - Git hooks and validation procedures

### [Architecture](architecture/) - System Design & CI/CD

System architecture and CI/CD pipeline design:

- **[GitHub Actions Workflow Architecture](architecture/workflow-architecture.md)** - CI/CD pipeline design and optimization

### [Internal](internal/) - Developer Documentation

Internal implementation notes and developer resources:

- **[Deployment Guide](internal/deployment-guide.md)** - Deployment directory structure reference
- **[Network Validation Data Types](internal/network-validation-data-types.md)** - Comprehensive validation data types and normalization rules
- **[Baseline Comparison Examples](internal/baseline-comparison-examples.md)** - Example output from baseline comparison for all data types

### [GitHub Templates](github-templates/) - Repository Templates

GitHub issue and PR templates:

- Pull Request Template
- Bug Report Template
- Feature Request Template

## 🚀 Quick Start

New to the system? Start here:

1. **[CLAUDE.md](../CLAUDE.md)** - Installation, setup, and configuration
2. **[Container Deployment](user-guides/container-deployment.md)** - Deploy with Docker/Podman
3. **[Upgrade Workflow Guide](user-guides/upgrade-workflow-guide.md)** - Run your first upgrade

## 🔧 Common Tasks

### Running an Upgrade
See [Upgrade Workflow Guide](user-guides/upgrade-workflow-guide.md)

### Troubleshooting Issues
See [CLAUDE.md](../CLAUDE.md) - Troubleshooting section

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

## 📝 Documentation Standards

- All user-facing documentation in `user-guides/`
- Platform-specific details in `platform-guides/`
- Internal implementation notes in `internal/`
- One-time analysis reports in `archived/`
- Keep documentation updated with code changes
- Use clear, concise language
- Include examples where appropriate

---

**Last Updated**: November 2, 2025
**System Version**: 4.0.0
**Documentation Version**: 3.0.0
