name: fix-github-workflows
description: Comprehensively fix all GitHub Actions workflow failures for Ansible network device upgrade system
version: "2.0.0"

input:
  - name: repo_path
    description: Path to the repository (defaults to current directory)
    required: false
    default: "."
  - name: workflow_filter
    description: Filter to specific workflow names (comma-separated)
    required: false
  - name: dry_run
    description: Analyze issues without making changes
    required: false
    default: false
  - name: skip_tests
    description: Skip running tests locally (faster but less thorough)
    required: false
    default: false

output:
  - type: workflow_status
    description: Current status of all workflows
  - type: fixes_applied
    description: Detailed list of all fixes applied
  - type: verification_results
    description: Results of local verification runs
  - type: commit_summary
    description: Summary of commits made

prompt: |
  I need you to comprehensively fix all GitHub Actions workflow failures for this Ansible-based network device upgrade system. Please follow this systematic approach:

  ## 1. Initial Assessment

  **Repository Analysis:**
  ```bash
  # Examine repository structure
  pwd && ls -la
  echo "Repository: {{repo_path}}"

  # Check project guidelines
  [ -f "CLAUDE.md" ] && echo "✅ CLAUDE.md found" || echo "⚠️ No CLAUDE.md"

  # Verify git status
  git status
  git branch --show-current
  git log --oneline -3

  # Check Ansible project structure
  ls -la ansible-content/ 2>/dev/null && echo "✅ Ansible content found"
  ls -la tests/ 2>/dev/null && echo "✅ Test directory found"
  ```

  **Workflow Discovery:**
  ```bash
  # List all GitHub workflows
  echo "=== GitHub Workflows ==="
  find .github/workflows -name "*.yml" -o -name "*.yaml" | sort

  # Parse workflow structure
  for workflow in .github/workflows/*.yml .github/workflows/*.yaml; do
    if [ -f "$workflow" ]; then
      echo "Analyzing workflow: $workflow"
      grep -E "^name:|^on:|^jobs:" "$workflow" | head -10
      echo "---"
    fi
  done
  ```

  ## 2. GitHub Actions Status Analysis

  **Fetch Latest Run Status:**
  ```bash
  # Get workflow run status using GitHub CLI
  echo "=== Workflow Run Status ==="
  gh run list --limit 10

  # Get detailed failure information
  FAILED_RUNS=$(gh run list --status=failure --limit 5 --json databaseId --jq '.[].databaseId')
  for run_id in $FAILED_RUNS; do
    echo "Analyzing failed run: $run_id"
    gh run view $run_id
    echo "---"
  done
  ```

  {% if workflow_filter %}
  **Focus on specific workflows: {{workflow_filter}}**
  {% endif %}

  **Deep Failure Analysis:**
  Look for these common Ansible/network automation workflow failures:
  - ansible-lint violations and best practice failures
  - yamllint formatting issues
  - Ansible playbook syntax errors
  - Role structure and dependency issues
  - Mock device testing failures
  - Container build and deployment issues
  - Network platform compatibility problems
  - Secret management and vault issues

  ## 3. Systematic Issue Resolution

  **Ansible Code Quality Issues:**
  ```bash
  echo "🔍 Fixing Ansible code quality issues..."

  # Run ansible-lint and fix violations
  ansible-lint ansible-content/ --format=pep8 > ansible-lint-issues.txt
  if [ -s ansible-lint-issues.txt ]; then
    echo "❌ Found ansible-lint violations:"
    cat ansible-lint-issues.txt
    # Apply fixes based on violations found
  else
    echo "✅ No ansible-lint violations"
  fi

  # Fix YAML formatting issues
  yamllint ansible-content/ tests/ .github/ > yamllint-issues.txt 2>&1
  if [ $? -ne 0 ]; then
    echo "❌ Found yamllint issues:"
    head -20 yamllint-issues.txt
    # Fix line length, indentation, and other YAML issues
  else
    echo "✅ YAML formatting looks good"
  fi

  # Validate Ansible playbook syntax
  find ansible-content/playbooks -name "*.yml" | while read playbook; do
    echo "Checking syntax: $playbook"
    ANSIBLE_CONFIG=ansible-content/ansible.cfg ansible-playbook --syntax-check "$playbook" -i /dev/null
  done
  ```

  **Container and Docker Issues:**
  ```bash
  echo "🐳 Fixing container-related issues..."

  # Validate Dockerfile
  if [ -f "Dockerfile" ]; then
    echo "Checking Dockerfile..."
    # Run hadolint if available
    command -v hadolint >/dev/null && hadolint Dockerfile

    # Check for common issues
    grep -n "USER root" Dockerfile && echo "⚠️ Review root user usage"
    grep -n "COPY.*--chown" Dockerfile && echo "✅ Using proper file ownership"
  fi

  # Test container functionality
  if [ -f "tests/container-tests/test-specific-functionality.sh" ]; then
    echo "Running container tests..."
    bash tests/container-tests/test-specific-functionality.sh
  fi
  ```

  **Network Platform Testing Issues:**
  ```bash
  echo "🌐 Fixing network platform testing issues..."

  # Validate supported platforms
  EXPECTED_PLATFORMS=("cisco-nxos-upgrade" "cisco-iosxe-upgrade" "fortios-upgrade" "opengear-upgrade" "metamako-mos-upgrade")
  for platform in "${EXPECTED_PLATFORMS[@]}"; do
    if [ -d "ansible-content/roles/$platform" ]; then
      echo "✅ Platform $platform found"
      # Check role structure
      [ -f "ansible-content/roles/$platform/tasks/main.yml" ] || echo "❌ Missing main.yml for $platform"
      [ -d "ansible-content/roles/$platform/molecule" ] || echo "⚠️ Missing molecule tests for $platform"
    else
      echo "❌ Platform $platform missing"
    fi
  done

  # Test mock device integrations
  if [ -d "tests/mock-inventories" ]; then
    echo "Testing mock inventories..."
    find tests/mock-inventories -name "*.yml" | while read inventory; do
      echo "Validating: $inventory"
      python -c "import yaml; yaml.safe_load(open('$inventory'))"
    done
  fi
  ```

  **Dependency and Collection Issues:**
  ```bash
  echo "📦 Fixing Ansible dependency issues..."

  # Install/update Ansible collections
  if [ -f "ansible-content/collections/requirements.yml" ]; then
    echo "Installing Ansible collections..."
    ansible-galaxy collection install -r ansible-content/collections/requirements.yml --force
  fi

  # Verify Python dependencies
  echo "Checking Python environment..."
  python --version
  pip list | grep -E "(ansible|yaml|jinja)"

  # Check for collection compatibility
  ansible-galaxy collection list | grep -E "(cisco|fortinet|community)"
  ```

  ## 4. GitHub Actions Workflow Fixes

  **Common Workflow Issues:**
  ```bash
  echo "🔧 Fixing GitHub Actions workflow issues..."

  # Check for deprecated actions
  find .github/workflows -name "*.yml" -exec grep -l "actions/setup-python@v[12]" {} \; | while read workflow; do
    echo "Updating deprecated Python setup in: $workflow"
    # Update to latest action versions
  done

  # Fix caching issues
  grep -r "cache.*node_modules\|cache.*pip" .github/workflows/ || echo "Consider adding dependency caching"

  # Check for missing environment variables
  grep -r "env:" .github/workflows/ | grep -E "(ANSIBLE|GITHUB_TOKEN)"

  # Validate workflow YAML syntax
  find .github/workflows -name "*.yml" | while read workflow; do
    echo "Validating workflow YAML: $workflow"
    python -c "import yaml; yaml.safe_load(open('$workflow'))"
  done
  ```

  **Security and Permissions:**
  ```bash
  echo "🔐 Checking security and permissions..."

  # Check for hardcoded secrets
  grep -r -i "password\|token\|key" .github/workflows/ | grep -v "secrets\." && echo "⚠️ Potential hardcoded secrets found"

  # Verify proper secret usage
  grep -r "secrets\." .github/workflows/ && echo "✅ Using GitHub secrets properly"

  # Check workflow permissions
  grep -A5 "permissions:" .github/workflows/*.yml && echo "✅ Permissions configured"
  ```

  ## 5. Local Verification
  {% if not skip_tests %}
  **Run Comprehensive Test Suite:**
  ```bash
  echo "🧪 Running comprehensive verification..."

  # Run project test suite
  ./tests/run-all-tests.sh

  # Run Ansible-specific validations
  ANSIBLE_CONFIG=ansible-content/ansible.cfg ansible-playbook --check tests/integration-tests/check-mode-tests.yml -i tests/mock-inventories/all-platforms.yml

  # Test container functionality
  bash tests/container-tests/test-specific-functionality.sh

  # Verify documentation
  find docs/ -name "*.md" -exec grep -l "broken\|TODO\|FIXME" {} \; || echo "✅ Documentation looks clean"
  ```
  {% endif %}

  ## 6. Documentation & Standards Compliance

  **Follow Network Infrastructure Standards:**
  - Adhere to CLAUDE.md Ansible project guidelines
  - Maintain network device compatibility
  - Ensure all platforms (Cisco, FortiOS, Opengear, Metamako) remain supported
  - Update container deployment documentation if needed
  - Verify security practices for network automation

  **Testing Standards:**
  - Ensure mock device testing covers all scenarios
  - Maintain test coverage for network platforms
  - Add regression tests for fixed workflow issues
  - Verify integration tests work with all supported devices

  ## 7. Git Management & Commits

  **Semantic Commit Strategy:**
  ```bash
  # Group fixes into logical commits
  git add .github/workflows/
  git commit -m "ci: fix GitHub Actions workflow failures and update deprecated actions"

  git add ansible-content/
  git commit -m "fix: resolve ansible-lint violations and YAML formatting issues"

  git add tests/
  git commit -m "test: fix mock device testing and container functionality tests"

  git add docs/
  git commit -m "docs: update documentation for workflow changes"
  ```

  **Network Infrastructure Commit Guidelines:**
  - Use conventional commits for infrastructure changes
  - Reference specific workflow failures in commit messages
  - Ensure commits are atomic and can be reverted safely
  - Tag commits that affect production deployment

  ## 8. Final Verification & Reporting

  **GitHub Actions Verification:**
  ```bash
  echo "🚀 Final verification..."

  # Push changes and monitor
  git push origin main

  # Wait and check workflow status
  sleep 30
  gh run list --limit 5

  # Verify all workflows pass
  gh run watch || echo "❌ Some workflows still failing"
  ```

  **Network Infrastructure Summary:**
  - Document all Ansible role fixes applied
  - List container and deployment improvements
  - Report on network platform compatibility
  - Note any changes to supported device types
  - Provide recommendations for maintaining workflow health

  ## 9. Network-Specific Considerations

  **Ansible Best Practices:**
  - Ensure idempotency in all playbooks
  - Verify proper error handling for network failures
  - Check timeout configurations for device connections
  - Validate backup and rollback procedures

  **Container Security:**
  - Verify privilege drop mechanisms work correctly
  - Ensure SSH key management is secure
  - Check for proper secret handling in containers
  - Validate network device authentication flows

  **Platform Compatibility:**
  - Test against all supported network platforms
  - Verify version compatibility matrices
  - Check for deprecated network modules
  - Ensure mock testing covers edge cases

  {% if dry_run %}
  **DRY RUN MODE**: Only analyze and report issues without making changes or commits.
  {% endif %}

  Begin the comprehensive workflow failure analysis and fixing process for the network device upgrade system at: {{repo_path}}