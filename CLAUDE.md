# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a native service-based network device upgrade management system for 1000+ heterogeneous network devices. The system automates firmware upgrades across multiple vendor platforms using pure Ansible configuration with AWX and NetBox running as native systemd services.

## Project Structure

- **`ansible-content/`**: Primary focus - Pure Ansible playbooks, roles, and templates
  - `playbooks/`: Core workflow orchestration including main-upgrade-workflow.yml
  - `roles/`: Vendor-specific upgrade logic (cisco-nxos-upgrade, cisco-iosxe-upgrade, etc.)
  - `collections/requirements.yml`: Ansible collection dependencies
- **`awx-config/`**: AWX Configuration (YAML only) - job templates, workflows, inventories
- **`install/`**: Native service installation scripts and configurations
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

This is a native service-based, configuration-only system with the following architecture:
- **AWX**: Open source automation platform running as systemd services with web UI for job orchestration
- **NetBox**: Device inventory and IPAM management running as systemd services
- **Telegraf**: Metrics collection service for existing InfluxDB v2
- **Redis**: Native service for job queuing and caching
- **Single Server Deployment**: All services running as systemd user services on single Linux server

### Upgrade Workflow Architecture

The system implements a **phase-separated upgrade approach** for safe firmware upgrades.

**For detailed workflow information, see**: `docs/UPGRADE_WORKFLOW_GUIDE.md`

### Supported Platforms

5 major network device platforms supported with comprehensive validation.

**For platform-specific details, see**:
- `docs/PLATFORM_IMPLEMENTATION_GUIDE.md` - Detailed platform features and implementation
- `README.md` - Platform overview and current status

### Key Implementation Details

- **Master Workflow**: `ansible-content/playbooks/main-upgrade-workflow.yml`
- **Vendor Roles**: Platform-specific roles in `ansible-content/roles/`
- **Validation Framework**: Comprehensive network state validation
- **Security**: SHA512 hash verification, signature validation, encrypted secrets
- **Metrics Integration**: Real-time progress tracking via InfluxDB

## Current Implementation Status

**Status**: Production ready for all platforms - See `IMPLEMENTATION_STATUS.md` for detailed status.

### Recent Development Completion

**Critical validation requirements have been fulfilled**:
- ✅ IOS-XE validation suite completed (IPSec, BFD, optics)
- ✅ NX-OS enhanced validation implemented (IGMP, enhanced BFD)
- ✅ All platforms production ready

### Development Priorities - COMPLETED
All critical validation requirements have been successfully implemented.

**For current status details, see**:
- `IMPLEMENTATION_STATUS.md` - Comprehensive platform status and completion analysis
- `README.md` - Project overview and current feature status