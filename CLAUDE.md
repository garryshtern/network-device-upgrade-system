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

**Requires latest versions: Ansible 12.0.0 with ansible-core 2.19.2 and Python 3.13.7**.

### Setup & Testing

```bash
# Install latest Ansible version (includes ansible-core 2.19.2)
pip install --upgrade ansible

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
# Clean install latest versions
pip uninstall ansible ansible-core ansible-base -y
pip install --upgrade ansible

# Install latest collection versions (as of September 11, 2025)
ansible-galaxy collection install \
  cisco.nxos:11.0.0 \
  cisco.ios:11.0.0 \
  fortinet.fortios:2.4.0 \
  ansible.netcommon:8.1.0 \
  community.general:11.3.0 \
  ansible.utils:6.0.0 \
  --force --upgrade --ignore-certs
```

## Container Deployment

🐳 **Production-ready container available:**

```bash
# Docker
docker pull ghcr.io/garryshtern/network-device-upgrade-system:latest
docker run --rm ghcr.io/garryshtern/network-device-upgrade-system:latest help

# Podman (RHEL8/9 compatible)
podman pull ghcr.io/garryshtern/network-device-upgrade-system:latest
podman run --rm ghcr.io/garryshtern/network-device-upgrade-system:latest
```

**Container Features:**
- Alpine-based (minimal ~200MB)
- Non-root execution (UID 1000)
- RHEL8/9 podman compatible
- Multi-architecture (amd64/arm64)
- Pre-installed Ansible 12.0.0 & Python 3.13.7

See [Container Deployment Guide](docs/container-deployment.md) for detailed usage.

## Testing Framework

Comprehensive testing for Mac/Linux development without physical devices:

- Mock inventory testing with simulated devices
- Variable validation and template rendering
- Workflow logic and error handling validation
- Integration testing with complete workflows
- YAML/JSON validation and performance testing
- Shell script and Python script testing
- Linting and formatting checks
- Container-based molecule testing
- CI/CD integration

**Main test runner:** `./tests/run-all-tests.sh`

## Code Standards

- **Code Quality**: MUST generate code without any syntactical and logical errors
- **Ansible Best Practices**: Follow official guidelines
- **Idempotency**: All tasks must be idempotent and support check mode
- **YAML Standards**: Consistent formatting and structure
- **Testing**: Comprehensive unit and integration tests
- **Security**: All sensitive data encrypted with Ansible Vault
- **Version Control**: Git with meaningful commit messages
- **YAML/JSON Validation**: Use yamllint and jsonlint
- **Linting**: Use ansible-lint for playbooks and roles
- **Line Length**: Max 80 characters per line
- **Error Handling**: Graceful error handling, no masking of errors

### **Documentation Standards (MANDATORY)**

- **Documentation Location**: ALL documentation MUST be under `docs/` directory
- **No Scattered Documentation**: Documentation files MUST NOT exist outside `docs/`
- **Change Verification Process**:
  1. **Before implementing changes**: Verify current behavior against existing documentation
  2. **During implementation**: Ensure changes align with documented standards
  3. **After implementation**: Update documentation to reflect new information/updates
- **Documentation Currency**: All documentation MUST be kept current with code changes
- **Broken Links**: All internal documentation links MUST be verified and functional
- **Documentation Review**: All changes MUST include documentation impact assessment
- **Single Source of Truth**: Each concept/process MUST be documented in exactly one location
- **Cross-References**: Use links to avoid documentation duplication

## Architecture

Native service-based system:
- **AWX**: Automation platform with web UI for job orchestration
- **NetBox**: Device inventory and IPAM management
- **Telegraf**: Metrics collection for InfluxDB v2
- **Redis**: Job queuing and caching
- **Single Server**: All services as systemd user services
- **Ansible**: Core automation engine
- **InfluxDB v2**: Time-series database for real-time tracking
- **Grafana**: Visualization and dashboards

**Master Workflow**: `ansible-content/playbooks/main-upgrade-workflow.yml`

**Supported Platforms**: 5 major network device platforms with comprehensive validation

**Key Features**:
- Phase-separated upgrade approach for safe firmware upgrades
- SHA512 hash verification and signature validation
- Real-time progress tracking via InfluxDB
- Comprehensive network state validation

# important-instruction-reminders
## MANDATORY Documentation Standards

**CRITICAL**: These instructions override any default behavior and MUST be followed exactly.

### Documentation Location Requirements
- **ALL documentation MUST be under `docs/` directory**
- **NEVER create documentation files outside `docs/`**
- **ALWAYS consolidate scattered documentation into `docs/`**

### Change Verification Process (MANDATORY)
1. **BEFORE making changes**: Verify current behavior against existing documentation in `docs/`
2. **DURING implementation**: Ensure all changes align with documented standards
3. **AFTER implementation**: Update relevant documentation in `docs/` to reflect changes
4. **ALWAYS check**: Documentation impact assessment for every change

### Documentation Maintenance
- **NEVER leave documentation outdated** after code changes
- **ALWAYS verify internal links** point to correct locations
- **NEVER duplicate information** - use cross-references instead
- **ALWAYS maintain single source of truth** for each concept

### Enforcement
- All changes MUST include documentation verification checklist
- Broken or missing documentation updates block deployment
- Documentation review required for all significant changes