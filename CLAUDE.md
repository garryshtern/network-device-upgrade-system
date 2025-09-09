# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Project Overview

Network device upgrade management system for 1000+ heterogeneous network devices. Automates firmware upgrades across multiple vendor platforms using Ansible with AWX and NetBox as native systemd services.

## Project Structure

- **`ansible-content/`**: Core Ansible playbooks, roles, and templates
  - `playbooks/`: Workflow orchestration including main-upgrade-workflow.yml
  - `roles/`: Vendor-specific upgrade logic (cisco-nxos-upgrade, cisco-iosxe-upgrade, etc.)
  - `collections/requirements.yml`: Ansible collection dependencies
- **`awx-config/`**: AWX Configuration (YAML) - job templates, workflows, inventories
- **`install/`**: Native service installation scripts and configurations
- **`integration/`**: External system integration (NetBox, Grafana, InfluxDB)
- **`tests/`**: Testing framework with comprehensive test runner
- **`docs/`**: Documentation and vendor-specific guides

## Development Commands

**Requires Ansible 11.9.0 with ansible-core 2.19.1 and Python 3.13**.

### Setup & Testing

```bash
# Install latest Ansible version
pip install ansible==11.9.0

# Install Ansible collections
ansible-galaxy collection install -r ansible-content/collections/requirements.yml --force

# Run comprehensive test suite
./tests/run-all-tests.sh

# Test playbook syntax
ansible-playbook --syntax-check ansible-content/playbooks/main-upgrade-workflow.yml

# Run playbooks in check mode
ansible-playbook --check ansible-content/playbooks/health-check.yml

# Lint Ansible content
ansible-lint ansible-content/playbooks/
yamllint ansible-content/
```

### Troubleshooting

**Common Issue: `ModuleNotFoundError: No module named 'ansible.module_utils.six.moves'`**

This issue is resolved in modern Ansible versions. Update to latest:

```bash
pip uninstall ansible ansible-core ansible-base -y
pip install ansible==11.9.0

# Install specific collection versions
ansible-galaxy collection install cisco.nxos:11.0.0 cisco.ios:9.0.0 fortinet.fortios:2.3.0 \
  ansible.netcommon:8.1.0 community.network:5.0.0 community.general:8.0.0 --force --ignore-certs
```

## Testing Framework

Comprehensive testing for Mac/Linux development without physical devices:

- Mock inventory testing with simulated devices
- Variable validation and template rendering
- Workflow logic and error handling validation
- Integration testing with complete workflows
- YAML/JSON validation and performance testing
- Container-based molecule testing
- CI/CD integration

**Main test runner:** `./tests/run-all-tests.sh`

## Code Standards

- **Ansible Best Practices**: Follow official guidelines
- **Idempotency**: All tasks must be idempotent and support check mode
- **YAML Standards**: Consistent formatting and structure
- **Testing**: Comprehensive unit and integration tests
- **Security**: All sensitive data encrypted with Ansible Vault

## Architecture

Native service-based system:
- **AWX**: Automation platform with web UI for job orchestration
- **NetBox**: Device inventory and IPAM management
- **Telegraf**: Metrics collection for InfluxDB v2
- **Redis**: Job queuing and caching
- **Single Server**: All services as systemd user services

**Master Workflow**: `ansible-content/playbooks/main-upgrade-workflow.yml`

**Supported Platforms**: 5 major network device platforms with comprehensive validation

**Key Features**:
- Phase-separated upgrade approach for safe firmware upgrades
- SHA512 hash verification and signature validation
- Real-time progress tracking via InfluxDB
- Comprehensive network state validation