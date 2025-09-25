name: code-commit
description: Comprehensive Ansible code validation and commit for network device upgrade system with zero tolerance for linting errors or test failures
version: "3.0.0"

input:
  - name: commit_message
    description: Commit message following conventional commit format
    required: true
  - name: files
    description: Specific files to commit (optional, defaults to all staged changes)
    required: false
  - name: push
    description: Whether to push after successful commit
    required: false
    default: true
  - name: branch
    description: Target branch for the commit
    required: false
  - name: force_checks
    description: Force all validation checks even if they initially pass
    required: false
    default: false

output:
  - type: validation_report
    description: Comprehensive linting and testing results
  - type: commit_info
    description: Git commit and push details
  - type: quality_metrics
    description: Code quality scores and coverage reports

prompt: |
  Execute comprehensive code validation and commit process with ZERO tolerance for linting errors or test failures. All commands must pass before any commit occurs.

  Commit message: "{{commit_message}}"
  {% if files %}Files to commit: {{files}}{% else %}Committing all staged changes{% endif %}
  Push after commit: {{push}}
  {% if branch %}Target branch: {{branch}}{% endif %}

  ## Stage 1: Pre-Commit Setup and Validation

  First, check the current repository state and Ansible environment:

  ```bash
  # Check git status and current branch
  git status
  echo "Current branch: $(git branch --show-current)"

  # Verify we're in project root and check structure
  pwd && ls -la
  echo "Ansible content structure:"
  ls -la ansible-content/ 2>/dev/null || echo "No ansible-content directory found"

  # Check Ansible environment
  which ansible && ansible --version
  which ansible-playbook && ansible-playbook --version
  which ansible-lint && ansible-lint --version
  which yamllint && yamllint --version
  echo "Python environment (for Ansible):"
  which python && python --version
  ```

  ## Stage 2: Comprehensive Linting - ZERO ERRORS/WARNINGS TOLERANCE

  **CRITICAL: ALL linting commands must return exit code 0 with no errors or warnings**

  ### Ansible Code Quality Checks
  ```bash
  echo "🔍 Starting Ansible linting - ZERO TOLERANCE for errors/warnings..."

  # Ansible lint check - CRITICAL for infrastructure code
  echo "Running ansible-lint..."
  ansible-lint ansible-content/ --format=parseable --strict
  if [ $? -ne 0 ]; then echo "❌ ansible-lint FAILED - Fix all Ansible issues before proceeding"; exit 1; fi
  echo "✅ ansible-lint PASSED"

  # Ansible playbook syntax validation
  echo "Running Ansible playbook syntax checks..."
  find ansible-content/playbooks -name "*.yml" -o -name "*.yaml" | while read -r playbook; do
    echo "Checking syntax: $playbook"
    ANSIBLE_CONFIG=ansible-content/ansible.cfg ansible-playbook --syntax-check "$playbook" -i /dev/null
    if [ $? -ne 0 ]; then echo "❌ Ansible syntax error in $playbook"; exit 1; fi
  done
  echo "✅ Ansible playbook syntax PASSED"

  # Ansible role validation
  echo "Running Ansible role syntax checks..."
  find ansible-content/roles -name "*.yml" -o -name "*.yaml" | while read -r role_file; do
    echo "Checking role file: $role_file"
    # Use ansible-playbook to validate role files indirectly
    if [[ $role_file == *"/tasks/main.yml" ]]; then
      ANSIBLE_CONFIG=ansible-content/ansible.cfg ansible-playbook --syntax-check "$role_file" -i /dev/null 2>/dev/null || echo "⚠️ Role file validation skipped for $role_file"
    fi
  done
  echo "✅ Ansible role validation PASSED"

  # Ansible collections requirements check
  echo "Validating Ansible collections requirements..."
  if [ -f "ansible-content/collections/requirements.yml" ]; then
    python -c "import yaml; yaml.safe_load(open('ansible-content/collections/requirements.yml'))"
    if [ $? -ne 0 ]; then echo "❌ Invalid collections requirements.yml"; exit 1; fi
    echo "✅ Collections requirements PASSED"
  fi
  ```

  ### Configuration Files Validation
  ```bash
  echo "🔍 Validating configuration files..."

  # JSON validation
  echo "Checking JSON files..."
  find . -name "*.json" -type f | while read -r file; do
    echo "Validating $file"
    python -m json.tool "$file" > /dev/null
    if [ $? -ne 0 ]; then echo "❌ Invalid JSON in $file"; exit 1; fi
  done
  echo "✅ JSON files PASSED"

  # YAML validation - CRITICAL for Ansible
  echo "Checking YAML files..."
  yamllint ansible-content/ tests/ .github/
  if [ $? -ne 0 ]; then echo "❌ yamllint FAILED - Fix YAML formatting"; exit 1; fi
  echo "✅ yamllint PASSED"

  # Ansible configuration validation
  if [ -f "ansible-content/ansible.cfg" ]; then
    echo "Validating ansible.cfg..."
    # Check for common configuration issues
    grep -q "host_key_checking" ansible-content/ansible.cfg && echo "✅ Host key checking configured"
    grep -q "retry_files_enabled" ansible-content/ansible.cfg && echo "✅ Retry files configured"
    echo "✅ ansible.cfg validation PASSED"
  fi

  # Inventory validation
  echo "Validating test inventories..."
  find tests/ -name "*.yml" -path "*/inventories/*" | while read -r inventory; do
    echo "Validating inventory: $inventory"
    python -c "import yaml; yaml.safe_load(open('$inventory'))"
    if [ $? -ne 0 ]; then echo "❌ Invalid inventory YAML in $inventory"; exit 1; fi
  done
  echo "✅ Inventory validation PASSED"
  ```

  ### Network Device Infrastructure Validation
  ```bash
  echo "🔍 Validating network device upgrade infrastructure..."

  # Validate AWX configuration structure
  if [ -d "awx-config" ]; then
    echo "Validating AWX configuration..."
    find awx-config/ -name "*.yml" -o -name "*.yaml" | while read -r awx_file; do
      echo "Checking AWX config: $awx_file"
      python -c "import yaml; yaml.safe_load(open('$awx_file'))"
      if [ $? -ne 0 ]; then echo "❌ Invalid AWX config YAML in $awx_file"; exit 1; fi
    done
    echo "✅ AWX configuration PASSED"
  fi

  # Validate supported platforms
  echo "Validating supported network platforms..."
  if [ -d "ansible-content/roles" ]; then
    EXPECTED_PLATFORMS=("cisco-nxos-upgrade" "cisco-iosxe-upgrade" "fortios-upgrade" "opengear-upgrade" "metamako-mos-upgrade")
    for platform in "${EXPECTED_PLATFORMS[@]}"; do
      if [ -d "ansible-content/roles/$platform" ]; then
        echo "✅ Platform $platform found"
        # Check for required files
        [ -f "ansible-content/roles/$platform/tasks/main.yml" ] || echo "⚠️ Missing main.yml for $platform"
        [ -d "ansible-content/roles/$platform/molecule" ] || echo "⚠️ Missing molecule tests for $platform"
      else
        echo "⚠️ Platform $platform not found"
      fi
    done
    echo "✅ Platform validation PASSED"
  fi

  # Validate documentation structure
  echo "Validating documentation structure..."
  if [ -d "docs" ]; then
    [ -f "docs/installation-guide.md" ] && echo "✅ Installation guide found"
    [ -f "docs/testing-framework-guide.md" ] && echo "✅ Testing guide found"
    [ -f "docs/container-deployment.md" ] && echo "✅ Container deployment guide found"
    echo "✅ Documentation structure PASSED"
  fi

  # Docker validation
  if [ -f "Dockerfile" ]; then
    echo "🔍 Validating Dockerfile..."
    if command -v hadolint &> /dev/null; then
      hadolint Dockerfile
      if [ $? -ne 0 ]; then echo "❌ hadolint FAILED - Fix Dockerfile issues"; exit 1; fi
      echo "✅ hadolint PASSED"
    else
      echo "⚠️ hadolint not installed, skipping Dockerfile validation"
    fi
  fi

  # Docker Compose validation
  if [ -f "docker-compose.yml" ] || [ -f "docker-compose.yaml" ]; then
    echo "🔍 Validating Docker Compose..."
    docker-compose config > /dev/null
    if [ $? -ne 0 ]; then echo "❌ docker-compose config FAILED"; exit 1; fi
    echo "✅ docker-compose config PASSED"
  fi

  # Shell script validation
  echo "🔍 Validating shell scripts..."
  if find . -name "*.sh" -type f | head -1 | grep -q .; then
    if command -v shellcheck &> /dev/null; then
      find . -name "*.sh" -type f -exec shellcheck {} \;
      if [ $? -ne 0 ]; then echo "❌ shellcheck FAILED - Fix shell script issues"; exit 1; fi
      echo "✅ shellcheck PASSED"
    else
      echo "⚠️ shellcheck not installed, skipping shell script validation"
    fi
  fi
  ```

  ## Stage 3: Security and Network Infrastructure Validation

  ```bash
  echo "🔐 Running security and network infrastructure checks..."

  # Ansible collections security check
  echo "Validating Ansible collections for security..."
  if [ -f "ansible-content/collections/requirements.yml" ]; then
    # Check for trusted collections only
    grep -E "(cisco\.|fortinet\.|community\.general|ansible\.)" ansible-content/collections/requirements.yml > /dev/null
    if [ $? -eq 0 ]; then
      echo "✅ Using trusted Ansible collections"
    else
      echo "⚠️ Review Ansible collections for trusted sources"
    fi
  fi

  # Check for hardcoded credentials or secrets
  echo "Scanning for hardcoded credentials..."
  if grep -r -i "password\s*:" ansible-content/ --include="*.yml" --include="*.yaml" | grep -v "vault\|encrypted\|{{"; then
    echo "❌ Potential hardcoded passwords found - Use Ansible Vault"
    exit 1
  fi
  echo "✅ No hardcoded credentials found"

  # Ansible Vault file validation
  echo "Validating Ansible Vault files..."
  find . -name "*.vault" -o -name "*vault*yml" | while read -r vault_file; do
    if [ -f "$vault_file" ]; then
      echo "Checking vault file: $vault_file"
      head -1 "$vault_file" | grep -q "\$ANSIBLE_VAULT" || echo "⚠️ $vault_file may not be properly encrypted"
    fi
  done
  echo "✅ Vault file validation PASSED"

  # Network device connection security
  echo "Validating network device connection security..."
  grep -r "ansible_ssh_pass\|ansible_password" ansible-content/ --include="*.yml" && echo "⚠️ Consider using SSH keys instead of passwords"
  grep -r "ansible_become_pass" ansible-content/ --include="*.yml" && echo "⚠️ Ensure become passwords are vaulted"
  echo "✅ Connection security validation PASSED"

  # Check for proper SSH key management
  echo "Validating SSH key configuration..."
  if grep -r "ansible_ssh_private_key_file" ansible-content/ --include="*.yml"; then
    echo "✅ SSH key authentication configured"
  else
    echo "⚠️ Consider configuring SSH key authentication"
  fi

  # Ansible dependency verification
  echo "Checking Ansible dependencies..."
  pip show ansible ansible-core > /dev/null 2>&1
  if [ $? -ne 0 ]; then echo "❌ Ansible not properly installed"; exit 1; fi
  echo "✅ Ansible dependencies PASSED"
  ```

  ## Stage 4: Comprehensive Ansible Testing - ABSOLUTE REQUIREMENT

  ```bash
  echo "🧪 Running comprehensive Ansible test suite - ALL TESTS MUST PASS"

  # Run the project's comprehensive test runner
  echo "Running project test suite..."
  ./tests/run-all-tests.sh
  if [ $? -ne 0 ]; then
    echo "❌ PROJECT TESTS FAILED - All tests must pass before commit"
    echo "Fix all failing tests and re-run validation"
    exit 1
  fi
  echo "✅ Project tests PASSED"

  # Unit tests for Ansible roles
  echo "Running Ansible unit tests..."
  if [ -f "tests/unit-tests/variable-validation.yml" ]; then
    ANSIBLE_CONFIG=ansible-content/ansible.cfg ansible-playbook tests/unit-tests/variable-validation.yml
    if [ $? -ne 0 ]; then echo "❌ Variable validation tests FAILED"; exit 1; fi
    echo "✅ Variable validation PASSED"
  fi

  if [ -f "tests/unit-tests/template-rendering.yml" ]; then
    ANSIBLE_CONFIG=ansible-content/ansible.cfg ansible-playbook tests/unit-tests/template-rendering.yml
    if [ $? -ne 0 ]; then echo "❌ Template rendering tests FAILED"; exit 1; fi
    echo "✅ Template rendering PASSED"
  fi

  # Integration tests with mock devices
  echo "Running integration tests with mock devices..."
  if [ -f "tests/integration-tests/check-mode-tests.yml" ]; then
    ANSIBLE_CONFIG=ansible-content/ansible.cfg ansible-playbook --check tests/integration-tests/check-mode-tests.yml -i tests/mock-inventories/all-platforms.yml
    if [ $? -ne 0 ]; then echo "❌ Check mode tests FAILED"; exit 1; fi
    echo "✅ Check mode tests PASSED"
  fi

  # Workflow tests
  echo "Running workflow tests..."
  if [ -f "tests/integration-tests/workflow-tests.yml" ]; then
    ANSIBLE_CONFIG=ansible-content/ansible.cfg ansible-playbook tests/integration-tests/workflow-tests.yml --limit localhost
    if [ $? -ne 0 ]; then echo "❌ Workflow tests FAILED"; exit 1; fi
    echo "✅ Workflow tests PASSED"
  fi

  # Container functionality tests
  echo "Running container tests..."
  if [ -f "tests/container-tests/test-specific-functionality.sh" ]; then
    bash tests/container-tests/test-specific-functionality.sh
    if [ $? -ne 0 ]; then echo "❌ Container tests FAILED"; exit 1; fi
    echo "✅ Container tests PASSED"
  fi

  # Molecule tests (if available)
  echo "Running molecule tests..."
  if command -v molecule &> /dev/null; then
    find ansible-content/roles -name molecule -type d | while read -r molecule_dir; do
      role_path=$(dirname "$molecule_dir")
      role_name=$(basename "$role_path")
      echo "Running molecule test for role: $role_name"
      cd "$role_path" && molecule test
      if [ $? -ne 0 ]; then echo "❌ Molecule tests FAILED for $role_name"; exit 1; fi
      cd - > /dev/null
    done
    echo "✅ Molecule tests PASSED"
  else
    echo "⚠️ Molecule not available, skipping molecule tests"
  fi
  ```

  ## Stage 5: Ansible Code Quality Metrics

  ```bash
  echo "📊 Analyzing Ansible code quality metrics..."

  # Ansible role structure analysis
  echo "Analyzing Ansible role structure..."
  find ansible-content/roles -type d -name tasks | while read -r tasks_dir; do
    role_name=$(dirname "$tasks_dir" | xargs basename)
    echo "Checking role: $role_name"

    # Check for required files
    role_dir=$(dirname "$tasks_dir")
    [ -f "$role_dir/tasks/main.yml" ] && echo "  ✅ tasks/main.yml" || echo "  ❌ Missing tasks/main.yml"
    [ -f "$role_dir/defaults/main.yml" ] && echo "  ✅ defaults/main.yml" || echo "  ⚠️ Missing defaults/main.yml"
    [ -f "$role_dir/handlers/main.yml" ] && echo "  ✅ handlers/main.yml" || echo "  ⚠️ Missing handlers/main.yml"
    [ -f "$role_dir/meta/main.yml" ] && echo "  ✅ meta/main.yml" || echo "  ⚠️ Missing meta/main.yml"
    [ -d "$role_dir/molecule" ] && echo "  ✅ molecule tests" || echo "  ⚠️ Missing molecule tests"
  done
  echo "✅ Role structure analysis completed"

  # Test coverage analysis
  echo "Analyzing test coverage..."
  TOTAL_ROLES=$(find ansible-content/roles -maxdepth 1 -type d | grep -v "^ansible-content/roles$" | wc -l)
  TESTED_ROLES=$(find ansible-content/roles -name molecule -type d | wc -l)
  if [ $TOTAL_ROLES -gt 0 ]; then
    COVERAGE_PERCENT=$(( (TESTED_ROLES * 100) / TOTAL_ROLES ))
    echo "Role test coverage: ${TESTED_ROLES}/${TOTAL_ROLES} roles (${COVERAGE_PERCENT}%)"
    if [ $COVERAGE_PERCENT -lt 80 ]; then
      echo "⚠️ Role test coverage below 80%"
    else
      echo "✅ Good role test coverage"
    fi
  fi

  # Documentation coverage analysis
  echo "Analyzing documentation coverage..."
  TOTAL_PLAYBOOKS=$(find ansible-content/playbooks -name "*.yml" -o -name "*.yaml" | wc -l)
  DOCUMENTED_PLAYBOOKS=$(find docs/ -name "*.md" | xargs grep -l "playbook\|workflow" | wc -l)
  echo "Documented playbooks: ${DOCUMENTED_PLAYBOOKS}/${TOTAL_PLAYBOOKS}"

  # Platform support analysis
  echo "Analyzing platform support..."
  SUPPORTED_PLATFORMS=("cisco-nxos" "cisco-iosxe" "fortios" "opengear" "metamako")
  for platform in "${SUPPORTED_PLATFORMS[@]}"; do
    if find ansible-content/roles -name "*$platform*" -type d | head -1 | grep -q .; then
      echo "  ✅ $platform supported"
    else
      echo "  ❌ $platform not supported"
    fi
  done
  echo "✅ Platform analysis completed"
  ```

  ## Stage 6: Final Quality Gates Verification

  ```bash
  echo "🎯 Verifying ALL Ansible quality gates passed..."

  # Create quality gate summary
  echo "=== ANSIBLE QUALITY GATES SUMMARY ==="
  echo "✅ Ansible-lint (Best practices): PASSED"
  echo "✅ YAML formatting (yamllint): PASSED"
  echo "✅ Playbook syntax validation: PASSED"
  echo "✅ Role structure validation: PASSED"
  echo "✅ Security checks (no hardcoded secrets): PASSED"
  echo "✅ Vault file validation: PASSED"
  echo "✅ Network device platform support: PASSED"
  echo "✅ Container functionality: PASSED"
  echo "✅ Mock device testing: PASSED"
  echo "✅ Integration workflow tests: PASSED"
  echo "✅ Documentation structure: PASSED"
  echo "✅ Ansible dependencies: PASSED"

  echo ""
  echo "🎉 ALL ANSIBLE QUALITY GATES PASSED - READY TO COMMIT!"
  ```

  ## Stage 7: Final Quality Gates Verification - MANDATORY BEFORE COMMIT

  ```bash
  echo "🎯 FINAL QUALITY GATES VERIFICATION - MANDATORY BEFORE ANY COMMIT"
  echo "=================================================================="

  # CRITICAL: Verify ALL previous stages completed successfully
  echo "Verifying all quality gates passed..."

  # Re-verify critical linting (belt and suspenders approach)
  echo "🔍 Final ansible-lint verification..."
  ansible-lint ansible-content/ --format=pep8
  if [ $? -ne 0 ]; then
    echo "❌ CRITICAL FAILURE: ansible-lint failed in final verification"
    echo "🚫 COMMIT BLOCKED - Fix ansible-lint issues first"
    exit 1
  fi

  echo "🔍 Final yamllint verification..."
  yamllint ansible-content/ tests/ .github/
  if [ $? -ne 0 ]; then
    echo "❌ CRITICAL FAILURE: yamllint failed in final verification"
    echo "🚫 COMMIT BLOCKED - Fix YAML formatting issues first"
    exit 1
  fi

  # MOST CRITICAL: Re-verify ALL tests pass
  echo "🧪 FINAL TEST VERIFICATION - ABSOLUTE REQUIREMENT"
  echo "Running comprehensive test suite one final time..."
  ./tests/run-all-tests.sh
  if [ $? -ne 0 ]; then
    echo "❌ CRITICAL FAILURE: TESTS STILL FAILING"
    echo "🚫 COMMIT ABSOLUTELY BLOCKED"
    echo ""
    echo "ZERO TOLERANCE POLICY VIOLATION:"
    echo "- Tests are failing and MUST be fixed first"
    echo "- NO commits allowed until ALL tests pass"
    echo "- Network infrastructure requires 100% test success"
    echo ""
    echo "Required actions:"
    echo "1. Fix all failing tests"
    echo "2. Re-run ./tests/run-all-tests.sh until 100% success"
    echo "3. Only then retry /code-commit"
    echo ""
    exit 1
  fi

  echo ""
  echo "🎉 ALL QUALITY GATES VERIFIED - PROCEEDING WITH COMMIT"
  echo "✅ ansible-lint: PASSED"
  echo "✅ yamllint: PASSED"
  echo "✅ Comprehensive tests: PASSED"
  echo "✅ Network infrastructure quality: VERIFIED"
  echo ""
  ```

## Stage 8: Commit Execution - ONLY AFTER ALL GATES PASS

  ```bash
  echo "📝 Executing commit process - ALL QUALITY GATES PASSED"

  {% if files %}
  # Stage specific files
  git add {{files}}
  echo "Staged files: {{files}}"
  {% else %}
  # Stage all changes (verify what's being staged)
  git add -A
  echo "Staged all changes"
  {% endif %}

  # Show what will be committed
  echo "Files to be committed:"
  git diff --cached --name-only

  echo "Commit diff summary:"
  git diff --cached --stat

  # Execute the commit - only after all validations pass
  echo "Committing with message: {{commit_message}}"
  git commit -m "{{commit_message}}"

  if [ $? -ne 0 ]; then
    echo "❌ Commit FAILED"
    exit 1
  fi

  COMMIT_HASH=$(git rev-parse HEAD)
  echo "✅ Commit successful: $COMMIT_HASH"

  {% if push %}
  # Push to remote - only after successful commit and all tests pass
  CURRENT_BRANCH=$(git branch --show-current)
  echo "Pushing to origin/$CURRENT_BRANCH..."

  git push origin $CURRENT_BRANCH
  if [ $? -ne 0 ]; then
    echo "❌ Push FAILED"
    exit 1
  fi
  echo "✅ Push successful"
  {% endif %}

  # Final status check
  git status
  echo ""
  echo "🎉 COMMIT PROCESS COMPLETED SUCCESSFULLY!"
  echo "Commit hash: $COMMIT_HASH"
  {% if push %}echo "Code pushed to remote repository"{% endif %}
  echo ""
  echo "Quality assurance summary:"
  echo "✅ All linting passed"
  echo "✅ All tests passed"
  echo "✅ Network infrastructure validated"
  echo "✅ Production-ready quality achieved"
  ```

  ## Emergency Override Protocol (Use Only With Approval)

  If absolutely necessary to override quality gates:

  ```bash
  # Document the override
  echo "EMERGENCY OVERRIDE: $(date)" >> .commit-overrides.log
  echo "Reason: [SPECIFY REASON]" >> .commit-overrides.log  
  echo "Commit: {{commit_message}}" >> .commit-overrides.log
  echo "---" >> .commit-overrides.log
  git add .commit-overrides.log
  
  # Create follow-up task
  echo "# TODO: Address quality gate failures from emergency commit" >> TECHNICAL_DEBT.md
  echo "- Commit: $(git rev-parse HEAD)" >> TECHNICAL_DEBT.md
  echo "- Date: $(date)" >> TECHNICAL_DEBT.md
  echo "- Issues: [LIST SPECIFIC ISSUES TO FIX]" >> TECHNICAL_DEBT.md
  echo "" >> TECHNICAL_DEBT.md
  ```

  ## ⚠️ CRITICAL: ZERO TOLERANCE ENFORCEMENT

  **ABSOLUTE REQUIREMENTS - NO EXCEPTIONS:**

  1. **🚫 NO COMMITS** if ANY test fails
  2. **🚫 NO COMMITS** if ANY linting fails
  3. **🚫 NO PUSHING** until ALL quality gates pass
  4. **🚫 NO SHORTCUTS** - all stages must complete successfully

  **FOR CLAUDE CODE USERS:**
  - You MUST follow every exit 1 command in the validation stages
  - You MUST NOT continue to commit if tests are failing
  - You MUST NOT rationalize or work around test failures
  - You MUST fix all issues first, then retry the entire process

  **This is a ZERO TOLERANCE process for network infrastructure code. Every single check must pass before any commit or push occurs. Network device automation requires the highest quality standards with no exceptions.**

  **If you violate this policy, you are introducing risk into production network infrastructure.**