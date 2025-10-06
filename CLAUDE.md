# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Project Overview

Network device upgrade management system for 1000+ heterogeneous network devices. Automates firmware upgrades across multiple vendor platforms using Ansible with AWX and NetBox as native systemd services.

### **Claude Code Operating Standards**

**CRITICAL: These standards override any default behavior and MUST be followed exactly.**

1. **Code Generation Requirements**:
   - Generate ONLY error-free, syntactically correct, and functionally working code
   - ALL code MUST pass ansible-lint and yamllint validation on first generation
   - NO syntax errors, linting warnings, or logical errors are acceptable
   - Code MUST be tested and verified before presenting to user

2. **Quality Validation Process**:
   - Run syntax checks on ALL generated Ansible files
   - Verify proper YAML formatting and structure
   - Test functionality in check mode before deployment
   - Ensure all test suites pass

3. **Error Prevention**:
   - Never use folded scalars in functional contexts (conditionals, paths, logic)
   - Implement comprehensive error handling with block/rescue patterns
   - Validate all Ansible task syntax against current best practices

4. **Variable Management** (MANDATORY):
   - **NEVER use `| default()` filter in playbooks or tasks**
   - **NEVER use `| default()` filter in when conditionals**
   - **NEVER use `and` in when conditionals** - use YAML list format instead
   - ALL variables MUST be properly defined in `group_vars/all.yml` or role defaults
   - Variables should have explicit values, not runtime defaults
   - This ensures proper variable resolution during syntax checks and execution
   - Exception: `| default(omit)` is allowed for optional Ansible module parameters only
   - Exception: `| default()` is allowed ONLY in role defaults files (`roles/*/defaults/main.yml`)
   - Conditionals must use defined variables from group_vars or role defaults
   - When conditionals MUST use YAML list syntax (one condition per list item) for clarity and maintainability

5. **Testing Integration**:
   - Run relevant tests after any code changes
   - Verify that changes don't break existing functionality
   - Maintain or improve overall system reliability
   - Document any test impacts or requirements

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

### Setup & Testing - QUALITY FIRST APPROACH

**MANDATORY: ALL commands MUST return 0 exit code before proceeding**

```bash
# Install latest Ansible version (includes ansible-core 2.19.2)
pip install --upgrade ansible

# Install Ansible collections
ansible-galaxy collection install -r ansible-content/collections/requirements.yml --force

# CRITICAL: Run comprehensive test suite - MUST achieve 100% pass rate
./tests/run-all-tests.sh

# REQUIRED: Syntax validation - MUST pass without errors
ansible-playbook --syntax-check ansible-content/playbooks/main-upgrade-workflow.yml

# REQUIRED: Check mode validation - MUST work without errors
ansible-playbook --check ansible-content/playbooks/health-check.yml

# CRITICAL: Linting validation - MUST return 0 errors/warnings
ansible-lint ansible-content/playbooks/
yamllint ansible-content/

# QUALITY GATES: All commands above MUST succeed before code changes
```

### Pre-Commit Quality Checklist (MANDATORY)

**⚠️ ZERO TOLERANCE: Any failures below BLOCK all commits**

```bash
# 1. Test update verification (MANDATORY - exit code MUST be 0)
# CRITICAL: Verify ALL tests updated to match code changes
./tests/run-all-tests.sh
# - Verify tests pass with your changes
# - Confirm tests actually test modified code
# - Check test coverage includes new/modified functionality
# - Ensure tests verify correct behavior, not just pass

# 2. Syntax validation (exit code MUST be 0)
find ansible-content -name "*.yml" -exec ansible-playbook --syntax-check {} \;

# 3. Linting validation (exit code MUST be 0)
ansible-lint ansible-content/ --offline --parseable-severity
yamllint ansible-content/

# 4. Test suite validation (MUST achieve 100% pass rate)
./tests/run-all-tests.sh | grep "Passed:" | grep "23"

# 5. Check mode validation
ansible-playbook --check --diff ansible-content/playbooks/main-upgrade-workflow.yml

# ALL CHECKS MUST PASS BEFORE COMMIT
# CODE CHANGES WITHOUT CORRESPONDING TEST UPDATES ARE BLOCKED
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

**Prerequisites:**
- Docker 20.10+ OR Podman 3.0+
- 2GB RAM, 1GB disk space

**Quick Start:**
```bash
# Docker
docker pull ghcr.io/garryshtern/network-device-upgrade-system:latest
docker run --rm ghcr.io/garryshtern/network-device-upgrade-system:latest help

# Podman (RHEL8/9 compatible - recommended for enterprise)
podman pull ghcr.io/garryshtern/network-device-upgrade-system:latest
podman run --rm ghcr.io/garryshtern/network-device-upgrade-system:latest help
```

**Container Features:**
- Alpine-based (minimal ~200MB)
- Non-root execution (UID 1000)
- RHEL8/9 podman compatible
- Multi-architecture (amd64/arm64)
- Pre-installed Ansible 12.0.0 & Python 3.13.7
- FortiOS multi-step upgrade support

**Installation:** See [Container Deployment Guide](docs/container-deployment.md) for complete Docker/Podman installation instructions and platform-specific setup.

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

## Code Standards - ZERO TOLERANCE QUALITY POLICY

**CRITICAL: ALL CODE MUST BE ERROR-FREE AND FUNCTIONAL**

### **Absolute Requirements (NO EXCEPTIONS)**

- **Code Quality**: Code MUST be 100% error-free with ZERO syntactical, logical, or runtime errors
- **Linting Compliance**: Code MUST pass ALL ansible-lint and yamllint checks without warnings or errors
- **Syntax Validation**: ALL Ansible playbooks, roles, and YAML files MUST pass syntax validation
- **Functional Testing**: Code MUST pass ALL relevant test suites before deployment
- **Test Pass Rate**: 100% test suite pass rate REQUIRED for any code changes
- **Zero Tolerance**: Any syntax errors, linting failures, or test failures BLOCK all commits

### **Quality Assurance Process (MANDATORY)**

1. **Pre-Development Validation**:
   - Verify existing code functionality before making changes
   - Run baseline tests to establish current working state
   - Document any pre-existing issues separately

2. **Development Standards**:
   - Write code that passes ALL linting rules on first attempt
   - Use proper YAML syntax following established patterns
   - Implement proper error handling with meaningful error messages
   - Ensure idempotency for all Ansible tasks

3. **Pre-Commit Validation (REQUIRED)**:
   - Run `ansible-lint ansible-content/` - MUST return 0 errors
   - Run `yamllint ansible-content/` - MUST return 0 errors
   - Run `ansible-playbook --syntax-check` on all modified playbooks
   - Run test suites - MUST achieve 100% pass rate
   - Verify all changes work in check mode (`--check --diff`)

4. **Code Review Requirements**:
   - Systematic search for ALL instances of patterns being fixed
   - Verify fixes across ENTIRE codebase, not just obvious instances
   - Use multiple search methods (grep, ripgrep, manual review) for critical issues
   - Document search patterns used and verify completeness
   - Test edge cases and error conditions

### **Specific Technical Standards**

- **Ansible Best Practices**: Follow official Ansible guidelines strictly
- **YAML Formatting**: Consistent indentation, proper quoting, no folded scalars in conditionals
- **File Paths**: Use direct string concatenation, not folded scalars that insert spaces
- **Boolean Expressions**: Never use folded scalars (`>-`) in `when` clauses or assertions
- **Error Handling**: Implement comprehensive error handling with block/rescue patterns
- **Idempotency**: All tasks MUST support check mode and be idempotent
- **Security**: All sensitive data encrypted with Ansible Vault, no hardcoded secrets
- **Performance**: Code MUST not introduce performance regressions
- **Documentation**: ALL changes MUST include corresponding documentation updates

### **Testing Standards**

**⚠️ MANDATORY: ALL CODE CHANGES REQUIRE TEST UPDATES**

#### Test Update Requirements (ZERO TOLERANCE)
- **Test Synchronization**: ALL code changes MUST be accompanied by corresponding test updates
- **Verification Accuracy**: Tests MUST accurately verify the new/modified behavior
- **Test Correctness**: Tests MUST be updated to ensure they test code changes correctly
- **Coverage Maintenance**: Code changes MUST NOT reduce test coverage
- **Regression Prevention**: Updated tests MUST prevent regression of fixed issues
- **NO EXCEPTIONS**: Commits without test updates are BLOCKED

#### Mandatory Test Update Process
1. **BEFORE Code Changes**:
   - Identify ALL affected test files (unit, integration, validation, vendor)
   - Document which tests need updates to verify changes
   - Run baseline tests to establish current behavior

2. **DURING Development**:
   - Update test files in parallel with code changes
   - Ensure tests verify new behavior, not just old behavior
   - Add new test cases for new functionality
   - Update existing test cases to match modified behavior
   - Add negative test cases for error scenarios

3. **AFTER Code Changes**:
   - Verify ALL affected tests pass with changes
   - Confirm tests actually test the modified code paths
   - Run complete test suite to detect regressions
   - Update test documentation if test structure changed
   - Verify 100% test pass rate maintained

#### Test File Categories Requiring Updates
- **Unit Tests** (`tests/unit-tests/`): Variable validation, template rendering, workflow logic
- **Integration Tests** (`tests/integration-tests/`): End-to-end workflow testing
- **Vendor Tests** (`tests/vendor-tests/`): Platform-specific functionality
- **Validation Tests** (`tests/validation-tests/`): Comprehensive validation suites
- **Mock Inventories** (`tests/mock-inventories/`): Test device configurations
- **Error Scenario Tests** (`tests/error-scenarios/`): Failure condition testing
- **Playbook Tests** (`tests/playbook-tests/`): Individual playbook validation

#### Test Update Examples (MANDATORY PATTERNS)
- **Variable Changes**: Update `variable-validation.yml` with new/modified variables
- **Template Changes**: Update `template-rendering.yml` to test new template logic
- **Role Changes**: Update corresponding vendor test files (`cisco-nxos-tests.yml`, etc.)
- **Playbook Changes**: Update `check-mode-tests.yml` and workflow test files
- **Platform Changes**: Update platform-specific tests and mock inventories
- **Security Changes**: Update authentication and secure transfer tests
- **Error Handling**: Add/update error scenario tests

#### Test Verification Requirements
- **Unit Tests**: All new functionality MUST have corresponding unit tests
- **Integration Tests**: Complex workflows MUST have integration test coverage
- **Syntax Tests**: ALL Ansible files MUST pass syntax validation
- **Linting Tests**: ALL files MUST pass ansible-lint and yamllint
- **Functional Tests**: Code MUST demonstrate working functionality
- **Error Scenarios**: Error handling MUST be tested with negative test cases
- **Correctness Validation**: Tests MUST verify behavior matches code changes

### **Enforcement Mechanisms**

- **Automated Validation**: CI/CD pipeline MUST block deployments with any failures
- **Manual Verification**: Code reviewers MUST verify all quality standards
- **Test Suite Integration**: All changes MUST maintain or improve test pass rates
- **Test Update Verification**: Code reviewers MUST verify tests updated for code changes
- **Test Correctness Review**: Verify tests actually test modified code, not just pass
- **Documentation Updates**: Technical documentation MUST reflect all changes
- **Quality Gates**: No commits allowed without passing ALL validation steps
- **Test Synchronization Gate**: No commits allowed without corresponding test updates

### **Systematic Code Review Process (MANDATORY)**

- Use comprehensive search patterns to catch ALL variations of issues
- Verify fixes across ENTIRE codebase, not just obvious instances
- Use multiple search methods (grep, ripgrep, manual review) for critical issues
- Document search patterns used and verify completeness
- When fixing syntax issues like folded scalars, check ALL files systematically

### YAML Linting Policy (CRITICAL)
- **Functionality FIRST**: NEVER break Ansible functionality for linting compliance
- **Folded scalars FORBIDDEN**: In conditionals, file paths, boolean expressions, and Jinja2 logic
- **Safe folding ONLY**: Messages, descriptions, and non-functional text content
- **Validation REQUIRED**: All YAML changes MUST pass ansible-playbook --syntax-check
- **Testing MANDATORY**: Run test suites after any YAML modifications
- **Use Safe Fixer**: tools/yaml-fixers/fix_yaml_syntax.py preserves functionality
- Validate that fixes don't introduce new issues elsewhere


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
## MANDATORY Code Quality and Documentation Standards

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
- Use automated tools to check for broken links and outdated content
- Regular audits to ensure compliance with documentation standards
- Document search patterns used for verification and fixes
- Verify fixes across ENTIRE codebase, not just obvious instances
- Use multiple search methods (grep, ripgrep, manual review) for critical issues
- Document search patterns used and verify completeness
- When fixing syntax issues like folded scalars, check ALL files systematically

