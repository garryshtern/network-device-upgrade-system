# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an AWX-based network device upgrade management system for 1000+ heterogeneous network devices. The system automates firmware upgrades across multiple vendor platforms using pure Ansible configuration with no custom development required.

## Project Structure

- **`ansible-content/`**: Primary focus - Pure Ansible playbooks, roles, and templates
  - `playbooks/`: Core workflow orchestration including main-upgrade-workflow.yml
  - `roles/`: Vendor-specific upgrade logic (cisco-nxos-upgrade, cisco-iosxe-upgrade, etc.)
  - `collections/requirements.yml`: Ansible collection dependencies
- **`awx-config/`**: AWX Configuration (YAML only) - job templates, workflows, inventories
- **`install/`**: Container-based installation scripts and configurations
- **`integration/`**: External system integration (NetBox, Grafana, InfluxDB)
- **`tests/`**: Testing framework with comprehensive test runner
- **`docs/`**: Documentation and vendor-specific guides

## Development Commands

This project uses Ansible for automation. Key commands:

```bash
# Install Ansible collections
ansible-galaxy install -r ansible-content/collections/requirements.yml --force

# Run comprehensive test suite
./tests/run-all-tests.sh

# Test playbook syntax
ansible-playbook --syntax-check ansible-content/playbooks/main-upgrade-workflow.yml

# Run playbooks in check mode
ansible-playbook --check ansible-content/playbooks/health-check.yml

# Lint Ansible content (if available)
ansible-lint ansible-content/playbooks/
yamllint ansible-content/
```

## Testing

The project includes a comprehensive test framework:
- **`./tests/run-all-tests.sh`**: Main test runner that executes all test suites
- **Syntax validation**: Automated syntax checking for all playbooks and roles
- **Integration tests**: End-to-end workflow validation
- **Vendor-specific tests**: Platform-specific test cases

## Code Standards and Contribution Guidelines

Follow these Ansible and DevOps standards:

- **Ansible Best Practices**: Follow official Ansible development guidelines
- **Idempotency**: All tasks must be idempotent and support check mode
- **YAML Standards**: Consistent YAML formatting and structure
- **Documentation**: Comprehensive inline documentation for all playbooks and roles
- **Testing**: Unit tests for custom modules and comprehensive integration tests
- **Version Control**: Git-based version control with meaningful commit messages
- **Security**: All sensitive data encrypted with Ansible Vault

## Claude Code Custom Commands

Two custom commands are configured:

1. **`/code-commit`**: Performs careful code review and commit with push
2. **`/code-review`**: Comprehensive code review with standards checking

## Architecture Notes

This is a container-based, configuration-only system with the following architecture:
- **AWX**: Open source automation platform with web UI for job orchestration
- **NetBox**: Device inventory and IPAM management (pre-existing deployment)
- **Telegraf**: Metrics collection for existing InfluxDB v2
- **Redis**: Job queuing and caching
- **Single Server Deployment**: All services containerized on single Linux server

### Upgrade Workflow Architecture

The system implements a **phase-separated upgrade approach**:

1. **Phase 1: Image Loading** (Business hours safe)
   - Device health check and baseline capture
   - Storage cleanup and preparation  
   - Firmware image transfer and staging
   - Cryptographic hash verification

2. **Phase 2: Image Installation** (Maintenance window)
   - Final pre-installation validation
   - Firmware activation and installation
   - Device reboot and recovery monitoring
   - Comprehensive post-upgrade validation

3. **Phase 3: Validation and Rollback**
   - Network state comparison (pre/post)
   - Protocol convergence validation
   - Automatic rollback on failure
   - Metrics export to InfluxDB

### Supported Platforms with Specific Features

- **Cisco NX-OS**: ISSU support, EPLD upgrades, boot variable management
- **Cisco IOS-XE**: Install mode vs bundle mode handling, boot system configuration  
- **Metamako MOS**: Ultra-low latency procedures, custom CLI handling, latency validation
- **Opengear**: Web interface automation, serial port management, power coordination
- **FortiOS**: HA cluster coordination, license validation, VPN handling

### Key Implementation Details

- **Master Workflow**: `ansible-content/playbooks/main-upgrade-workflow.yml` orchestrates all phases
- **Vendor Roles**: Each platform has dedicated roles in `ansible-content/roles/`
- **Validation Framework**: Comprehensive network state validation with pre/post comparison
- **Security**: SHA512 hash verification, signature validation, encrypted secrets
- **Error Handling**: Automatic rollback triggers, manual intervention procedures
- **Metrics Integration**: Real-time progress tracking via InfluxDB line protocol

## Implementation Status & Known Gaps

**Overall Completion**: 85% - Production ready for most platforms

### Platform Readiness Status
- ✅ **Cisco NX-OS**: 95% complete (production ready)
- ⚠️ **Cisco IOS-XE**: 70% complete (missing IPSec, BFD, optics validation)
- ✅ **FortiOS**: 90% complete (production ready)
- ✅ **Metamako MOS**: 85% complete (production ready)  
- ✅ **Opengear**: 80% complete (production ready)

### Critical Gaps for IOS-XE Platform
The IOS-XE implementation is missing required validation components per PROJECT_REQUIREMENTS.md:

**Missing Validation Tasks** (High Priority):
- `ansible-content/roles/cisco-iosxe-upgrade/tasks/ipsec-validation.yml` - IPSec tunnel validation
- `ansible-content/roles/cisco-iosxe-upgrade/tasks/bfd-validation.yml` - BFD session validation  
- `ansible-content/roles/cisco-iosxe-upgrade/tasks/optics-validation.yml` - Interface optics validation

These must be implemented and integrated into the main validation workflow before IOS-XE production deployment.

### Development Priorities
1. **High**: Complete IOS-XE validation suite
2. **Medium**: Add IGMP validation for NX-OS
3. **Medium**: Enhance BFD validation across all platforms
4. **Low**: Complete documentation and vendor guides

See `IMPLEMENTATION_STATUS.md` for detailed compliance analysis.