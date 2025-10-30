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

4. **YAML Formatting Standards** (MANDATORY):
   - **NEVER use folded scalars (`|`, `>`, `>-`) for `msg` parameters in debug/fail tasks**
   - **ALWAYS use YAML list syntax for messages**
   - Example CORRECT:
     ```yaml
     - name: Display results
       ansible.builtin.debug:
         msg:
           - "Line 1"
           - "Line 2: {{ variable }}"
           - "Line 3"
     ```
   - Example INCORRECT:
     ```yaml
     - name: Display results
       ansible.builtin.debug:
         msg: |
           Line 1
           Line 2: {{ variable }}
           Line 3
     ```
   - Folded scalars in messages cause maintenance issues and inconsistent formatting
   - Use inline conditionals in list items if needed: `"{{ 'text' if condition else '' }}"`

5. **Variable Management** (MANDATORY):
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

## Deprecated Playbooks

**IMPORTANT**: The following playbooks are deprecated and will be removed in a future version. Use `main-upgrade-workflow.yml` with tag-based execution instead:

- `health-check.yml` → Use `main-upgrade-workflow.yml --tags step1`
- `network-validation.yml` → Use `main-upgrade-workflow.yml --tags step5` (pre-upgrade) or `--tags step7` (post-upgrade)
- `image-loading.yml` → Use `main-upgrade-workflow.yml --tags step4`
- `image-installation.yml` → Use `main-upgrade-workflow.yml --tags step6`
- `emergency-rollback.yml` → Use `main-upgrade-workflow.yml --tags step8`

**Active Playbooks** (still supported as separate operational tools):
- `compliance-audit.yml` - Separate operational task
- `config-backup.yml` - Useful for ad-hoc backups

Tag-based execution provides automatic dependency resolution and ensures all prerequisites are met before running each step. See the "Tag-Based Workflow Execution" section for detailed examples.

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

**Requires: Ansible 11.0.0 with ansible-core 2.18.10 and Python 3.13.x**.

### Setup & Testing - QUALITY FIRST APPROACH

**MANDATORY: ALL commands MUST return 0 exit code before proceeding**

```bash
# Install Ansible 11.0.0 (includes ansible-core 2.18.10)
pip install ansible==11.0.0

# Install Ansible collections
ansible-galaxy collection install -r ansible-content/collections/requirements.yml --force

# CRITICAL: Run comprehensive test suite - MUST achieve 100% pass rate
./tests/run-all-tests.sh

# REQUIRED: Syntax validation - MUST pass without errors
# CRITICAL: ALWAYS provide ALL required extra_vars to avoid "undefined variable" errors
ansible-playbook --syntax-check ansible-content/playbooks/main-upgrade-workflow.yml \
  --extra-vars="target_hosts=localhost target_firmware=test.bin maintenance_window=true max_concurrent=1"

# REQUIRED: Check mode validation - MUST work without errors
ansible-playbook --check ansible-content/playbooks/health-check.yml \
  --extra-vars="target_hosts=localhost"

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
# CRITICAL: ALWAYS provide required extra_vars for playbooks that need them
ansible-playbook --syntax-check ansible-content/playbooks/main-upgrade-workflow.yml \
  --extra-vars="target_hosts=localhost target_firmware=test.bin maintenance_window=true max_concurrent=1"
ansible-playbook --syntax-check ansible-content/playbooks/health-check.yml \
  --extra-vars="target_hosts=localhost"
ansible-playbook --syntax-check ansible-content/playbooks/config-backup.yml
ansible-playbook --syntax-check ansible-content/playbooks/compliance-audit.yml
ansible-playbook --syntax-check ansible-content/playbooks/image-installation.yml
ansible-playbook --syntax-check ansible-content/playbooks/network-validation.yml

# 3. Linting validation (exit code MUST be 0)
ansible-lint ansible-content/ --offline --parseable-severity
yamllint ansible-content/

# 4. Test suite validation (MUST achieve 100% pass rate)
./tests/run-all-tests.sh | grep "Passed:" | grep "23"

# 5. Check mode validation
# CRITICAL: ALWAYS provide required extra_vars
ansible-playbook --check --diff ansible-content/playbooks/main-upgrade-workflow.yml \
  --extra-vars="target_hosts=localhost target_firmware=test.bin maintenance_window=true max_concurrent=1"

# ALL CHECKS MUST PASS BEFORE COMMIT
# CODE CHANGES WITHOUT CORRESPONDING TEST UPDATES ARE BLOCKED
```

### Troubleshooting

**Common Issue: `ModuleNotFoundError: No module named 'ansible.module_utils.six.moves'`**

This issue is resolved in Ansible 11.0.0+. Update to required version:

```bash
# Clean install required versions
pip uninstall ansible ansible-core ansible-base -y
pip install ansible==11.0.0

# Install latest collection versions (as of October 30, 2025)
ansible-galaxy collection install \
  cisco.nxos:11.0.0 \
  cisco.ios:11.1.1 \
  fortinet.fortios:2.4.0 \
  ansible.netcommon:8.1.0 \
  community.general:11.4.0 \
  ansible.utils:6.0.0 \
  community.crypto:3.0.5 \
  ansible.posix:1.6.2 \
  netbox.netbox:3.21.0 \
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
- Pre-installed Ansible 11.0.0 & Python 3.13.x
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
   - Run `ansible-playbook --syntax-check` on all modified playbooks **WITH REQUIRED EXTRA_VARS**
   - Run test suites - MUST achieve 100% pass rate
   - Verify all changes work in check mode (`--check --diff`) **WITH REQUIRED EXTRA_VARS**

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

#### **Syntax Validation with Extra Variables (CRITICAL)**

**MANDATORY: ALWAYS provide ALL required extra_vars when running ansible-playbook --syntax-check**

Many playbooks use runtime variables (target_hosts, target_firmware, max_concurrent, etc.) that MUST be provided during syntax validation to avoid "undefined variable" errors.

**NEVER run syntax checks without required extra_vars:**
```bash
# ❌ WRONG - Will fail with "undefined variable" errors
ansible-playbook --syntax-check ansible-content/playbooks/main-upgrade-workflow.yml

# ✅ CORRECT - Provides all required variables
ansible-playbook --syntax-check ansible-content/playbooks/main-upgrade-workflow.yml \
  --extra-vars="target_hosts=localhost target_firmware=test.bin maintenance_window=true max_concurrent=1"
```

**Required extra_vars by playbook:**
- `main-upgrade-workflow.yml`: target_hosts, target_firmware, maintenance_window, max_concurrent
- `health-check.yml`: target_hosts (DEPRECATED - use main-upgrade-workflow.yml --tags step1)
- `config-backup.yml`: (none - can run without extra_vars)
- `compliance-audit.yml`: (none - can run without extra_vars)
- `image-installation.yml`: (none - can run without extra_vars) (DEPRECATED - use main-upgrade-workflow.yml --tags step6)
- `network-validation.yml`: (none - can run without extra_vars) (DEPRECATED - use main-upgrade-workflow.yml --tags step5 or step7)
- `image-loading.yml`: (DEPRECATED - use main-upgrade-workflow.yml --tags step4)

**This requirement applies to:**
- Manual syntax checks during development
- Pre-commit validation scripts
- CI/CD pipeline syntax validation
- Check mode execution (`--check --diff`)
- Tag-based workflow execution (see "Tag-Based Workflow Execution" section)

**Rationale:** Providing extra_vars ensures syntax validation catches ALL errors, not just YAML structure issues. Without proper variables, syntax checks may pass but playbooks will fail at runtime.

**Note:** When using tag-based workflow execution with `main-upgrade-workflow.yml`, the same extra_vars requirements apply. See the "Tag-Based Workflow Execution" section for detailed examples of running individual steps with proper variables.

#### **Platform-Specific Task Organization (MANDATORY)**

**CRITICAL: All platform-specific tasks MUST be organized under a single block with ONE when clause**

- **Single Block Design**: Group all tasks for a specific platform under one block
- **One When Clause**: Use a single `when: platform == 'platform_name'` at the block level
- **No Redundant Conditionals**: Do NOT repeat platform checks on individual tasks within the block
- **Strict Platform Gating**: Prevents cross-platform fact access and module execution
- **Fail-Fast Validation**: Assert required facts/variables at the start of the block

**Example - CORRECT:**
```yaml
- name: NX-OS Network Validation
  when: platform == 'nxos'  # Single when clause
  block:
    - name: Enforce NX-OS facts availability
      ansible.builtin.assert:
        that:
          - ansible_network_resources is defined

    - name: Run BGP validation
      ansible.builtin.include_tasks: bgp-validation.yml
      when: bgp_enabled | bool  # Only feature-specific conditions inside block

    - name: Run interface validation
      ansible.builtin.include_tasks: interface-validation.yml

    - name: Run routing validation
      ansible.builtin.include_tasks: routing-validation.yml
```

**Example - INCORRECT:**
```yaml
# WRONG: Redundant platform checks on every task
- name: Run BGP validation
  ansible.builtin.include_tasks: bgp-validation.yml
  when:
    - platform == 'nxos'  # Redundant
    - bgp_enabled | bool

- name: Run interface validation
  ansible.builtin.include_tasks: interface-validation.yml
  when: platform == 'nxos'  # Redundant

- name: Run routing validation
  ansible.builtin.include_tasks: routing-validation.yml
  when: platform == 'nxos'  # Redundant
```

**Benefits:**
- **Performance**: When condition evaluated once, not per task
- **Readability**: Clear platform boundary, easier to understand
- **Maintainability**: Single point to modify platform logic
- **Safety**: Prevents accidental cross-platform execution
- **Efficiency**: Ansible skips entire block if condition false

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

## Tag-Based Workflow Execution

The main upgrade workflow (`ansible-content/playbooks/main-upgrade-workflow.yml`) uses a tag-based execution model with automatic dependency resolution, allowing you to run individual upgrade steps or the entire workflow seamlessly.

### Overview

The workflow is divided into 8 sequential steps, with a streamlined dependency model. Each step depends directly on STEP 1 (connectivity), while additional dependencies are managed automatically through tag-based execution in the main workflow. This design provides maximum flexibility while maintaining safety.

### Workflow Steps

The 8-step upgrade workflow:

1. **STEP 1 - Connectivity Check** (`step1`, `connectivity`)
   - Verifies SSH/NETCONF connectivity to target devices
   - Dependencies: None (can run standalone)
   - Essential first step to validate device accessibility

2. **STEP 2 - Version Check** (`step2`, `version_check`)
   - Collects current firmware version information
   - Dependencies: STEP 1 (directly); STEP 2 requires version data from STEP 1 (via tags in main workflow)
   - Validates current device state before upgrade

3. **STEP 3 - Space Check** (`step3`, `space_check`)
   - Verifies sufficient flash/disk space for firmware
   - Dependencies: STEP 1 (directly); STEPS 2-3 (via tags in main workflow)
   - Prevents upgrade failures due to insufficient storage

4. **STEP 4 - Image Upload** (`step4`, `image_upload`)
   - Uploads firmware image to devices
   - Verifies SHA512 hash after upload (mandatory)
   - Dependencies: STEP 1 (directly); STEPS 2-4 (via tags in main workflow)
   - Requires `target_firmware` variable

5. **STEP 5 - Config Backup & Pre-Validation** (`step5`, `config_backup`, `pre_validation`)
   - Backs up running configuration
   - Captures pre-upgrade network state baseline
   - Dependencies: STEP 1 (directly); STEPS 2-5 (via tags in main workflow)
   - Creates comparison baseline for post-upgrade validation

6. **STEP 6 - Image Installation** (`step6`, `install`, `reboot`)
   - Installs firmware and reboots devices
   - Dependencies: STEP 1 (directly); STEPS 2-6 (via tags in main workflow)
   - Requires `maintenance_window=true` for safety
   - **CRITICAL**: This step causes service interruption

7. **STEP 7 - Post-Upgrade Validation** (`step7`, `post_validation`)
   - Validates post-upgrade network state
   - Compares against STEP 5 baseline
   - Dependencies: STEP 1 (directly); STEPS 2-7 (via tags in main workflow)
   - Requires previous execution of STEP 5 to establish baseline

8. **STEP 8 - Emergency Rollback** (`step8`, `emergency_rollback`)
   - Restores device to previous firmware and configuration
   - Triggered when STEP 7 validation fails or manually invoked
   - Dependencies: STEP 1 (directly); rollback triggers from STEP 7 rescue block
   - Provides automatic recovery from failed upgrades

### Tag-Based Execution Examples

#### Bare-Metal Ansible Execution

```bash
# STEP 1: Run connectivity check only (no dependencies)
ansible-playbook ansible-content/playbooks/main-upgrade-workflow.yml \
  --tags step1 \
  -e target_hosts=nxos-switches \
  -e max_concurrent=5

# STEP 2: Run version check (auto-runs step1 first)
ansible-playbook ansible-content/playbooks/main-upgrade-workflow.yml \
  --tags step2 \
  -e target_hosts=nxos-switches \
  -e max_concurrent=5

# STEP 3: Run space check (auto-runs steps 1-2 first)
ansible-playbook ansible-content/playbooks/main-upgrade-workflow.yml \
  --tags step3 \
  -e target_hosts=nxos-switches \
  -e max_concurrent=5

# STEP 4: Upload firmware image (auto-runs steps 1-3 first)
ansible-playbook ansible-content/playbooks/main-upgrade-workflow.yml \
  --tags step4 \
  -e target_hosts=nxos-switches \
  -e target_firmware=nxos.10.3.3.bin \
  -e max_concurrent=5

# STEP 5: Backup config and capture pre-upgrade baseline (auto-runs steps 1-4 first)
ansible-playbook ansible-content/playbooks/main-upgrade-workflow.yml \
  --tags step5 \
  -e target_hosts=nxos-switches \
  -e target_firmware=nxos.10.3.3.bin \
  -e max_concurrent=5

# STEP 6: Install firmware and reboot (auto-runs steps 1-5 first)
# CRITICAL: Requires maintenance_window=true for safety
ansible-playbook ansible-content/playbooks/main-upgrade-workflow.yml \
  --tags step6 \
  -e target_hosts=nxos-switches \
  -e target_firmware=nxos.10.3.3.bin \
  -e max_concurrent=5 \
  -e maintenance_window=true

# STEP 7: Post-upgrade validation (auto-runs steps 1-6 first)
# Requires STEP 5 baseline from previous run
ansible-playbook ansible-content/playbooks/main-upgrade-workflow.yml \
  --tags step7 \
  -e target_hosts=nxos-switches \
  -e target_firmware=nxos.10.3.3.bin \
  -e max_concurrent=5 \
  -e maintenance_window=true

# Alternative: Run STEP 7 standalone (requires STEP 5 baseline exists)
ansible-playbook ansible-content/playbooks/main-upgrade-workflow.yml \
  --tags step7 \
  -e target_hosts=nxos-switches \
  -e max_concurrent=5

# STEP 8: Emergency rollback (manual invocation or triggered by STEP 7 failure)
ansible-playbook ansible-content/playbooks/main-upgrade-workflow.yml \
  --tags step8 \
  -e target_hosts=nxos-switches \
  -e max_concurrent=5
```

#### Container-Based Execution

All examples above work in container environments using Docker or Podman:

```bash
# Docker example - Run connectivity check
docker run --rm \
  -v $(pwd)/inventory:/inventory:ro \
  -v $(pwd)/firmware:/firmware:ro \
  ghcr.io/garryshtern/network-device-upgrade-system:latest \
  ansible-playbook ansible-content/playbooks/main-upgrade-workflow.yml \
  --tags step1 \
  -e target_hosts=nxos-switches \
  -e max_concurrent=5

# Podman example - Run full upgrade through installation
podman run --rm \
  -v $(pwd)/inventory:/inventory:ro \
  -v $(pwd)/firmware:/firmware:ro \
  ghcr.io/garryshtern/network-device-upgrade-system:latest \
  ansible-playbook ansible-content/playbooks/main-upgrade-workflow.yml \
  --tags step6 \
  -e target_hosts=nxos-switches \
  -e target_firmware=nxos.10.3.3.bin \
  -e max_concurrent=5 \
  -e maintenance_window=true
```

### Available Tags Reference

**Step Tags** (with automatic dependency resolution via main workflow):
- `step1` - Connectivity check (no dependencies)
- `step2` - Version check (depends on step1 directly; steps 1-2 via tags)
- `step3` - Space check (depends on step1 directly; steps 1-3 via tags)
- `step4` - Image upload (depends on step1 directly; steps 1-4 via tags)
- `step5` - Config backup & pre-validation (depends on step1 directly; steps 1-5 via tags)
- `step6` - Image installation & reboot (depends on step1 directly; steps 1-6 via tags)
- `step7` - Post-upgrade validation (depends on step1 directly; steps 1-7 via tags)
- `step8` - Emergency rollback (depends on step1 directly; triggered by step7 or manual)

**Functional Tags** (alternative names for specific operations):
- `connectivity` - Same as step1
- `version_check` - Same as step2
- `space_check` - Same as step3
- `image_upload` - Same as step4
- `config_backup` - Included in step5
- `pre_validation` - Included in step5
- `install` - Included in step6
- `reboot` - Included in step6
- `post_validation` - Same as step7
- `emergency_rollback` - Same as step8

### Automatic Dependency Resolution

**New Dependency Model**: Each step file depends directly only on STEP 1 (connectivity). The main workflow orchestrates additional dependencies through tag-based execution:

- Running `--tags step1` executes only step 1
- Running `--tags step2` executes steps 1-2 (main workflow ensures step1 runs first)
- Running `--tags step3` executes steps 1-3 (main workflow ensures steps 1-2 run first)
- Running `--tags step4` executes steps 1-4 (main workflow ensures steps 1-3 run first)
- Running `--tags step5` executes steps 1-5 (main workflow ensures steps 1-4 run first)
- Running `--tags step6` executes steps 1-6 (main workflow ensures steps 1-5 run first)
- Running `--tags step7` executes steps 1-7 (main workflow ensures steps 1-6 run first)
- Running `--tags step8` executes steps 1+8 (emergency rollback with connectivity check)

**Key Benefits of This Model**:
- **Simplified Step Files**: Each step only includes STEP 1 directly
- **Flexible Execution**: Steps can be run individually or in combination
- **Automatic Orchestration**: Main workflow manages execution order via tags
- **Clear Dependencies**: Direct dependency (STEP 1) vs. orchestrated dependencies (via tags)

This design eliminates the need for:
- Complex nested task inclusions in step files
- Multiple playbook invocations
- Manual dependency tracking
- Separate playbook files for each operation

### Common Workflows

**Pre-Upgrade Validation Only:**
```bash
# Run all pre-upgrade checks without installation
ansible-playbook ansible-content/playbooks/main-upgrade-workflow.yml \
  --tags step5 \
  -e target_hosts=production-switches \
  -e target_firmware=firmware.bin \
  -e max_concurrent=10
```

**Installation Only (after manual validation):**
```bash
# Requires previous successful execution of steps 1-5
ansible-playbook ansible-content/playbooks/main-upgrade-workflow.yml \
  --tags step6 \
  -e target_hosts=production-switches \
  -e target_firmware=firmware.bin \
  -e max_concurrent=10 \
  -e maintenance_window=true
```

**Post-Upgrade Validation Only:**
```bash
# After devices have rebooted and stabilized
# Requires STEP 5 baseline from previous run
ansible-playbook ansible-content/playbooks/main-upgrade-workflow.yml \
  --tags step7 \
  -e target_hosts=production-switches \
  -e max_concurrent=10
```

**Full Workflow Execution:**
```bash
# Run all steps (no --tags parameter)
ansible-playbook ansible-content/playbooks/main-upgrade-workflow.yml \
  -e target_hosts=production-switches \
  -e target_firmware=firmware.bin \
  -e max_concurrent=10 \
  -e maintenance_window=true
```

### Required Variables

**Essential variables for all steps:**
- `target_hosts` - Ansible inventory group or hostname
- `max_concurrent` - Maximum concurrent device operations (default: 5)

**Required for steps 4-7:**
- `target_firmware` - Firmware filename (must exist in firmware directory)

**Required for step 6 (installation):**
- `maintenance_window=true` - Safety flag to prevent accidental reboots

**Optional variables:**
- `firmware_hash_algorithm` - Hash algorithm for verification (default: sha512)
- `firmware_hash_file_extension` - Hash file extension (default: .sha512sum)
- `skip_hash_verification` - Skip hash verification (NOT RECOMMENDED, default: false)

### Benefits of Tag-Based Execution

1. **Unified Playbook**: Single playbook for all upgrade operations
2. **Automatic Dependencies**: No manual tracking of prerequisite steps
3. **Flexible Execution**: Run any step or combination of steps
4. **Safety**: Built-in validation prevents skipping critical steps
5. **Container Compatible**: Works seamlessly with Docker/Podman
6. **Simplified Workflow**: Eliminates need for multiple playbook files
7. **Consistent Behavior**: Same playbook in development and production
8. **Clear Progression**: Step numbers indicate execution order

### Migration from Legacy Approach

**Before (multiple playbook invocations):**
```bash
ansible-playbook health-check.yml -e target_hosts=switches
ansible-playbook config-backup.yml -e target_hosts=switches
ansible-playbook network-validation.yml -e target_hosts=switches
ansible-playbook image-installation.yml -e target_hosts=switches -e target_firmware=fw.bin
```

**After (unified tag-based approach):**
```bash
ansible-playbook main-upgrade-workflow.yml --tags step5 \
  -e target_hosts=switches -e target_firmware=fw.bin -e max_concurrent=5
```

The tag-based model provides the same functionality with improved consistency, automatic dependency management, and simplified execution.

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

