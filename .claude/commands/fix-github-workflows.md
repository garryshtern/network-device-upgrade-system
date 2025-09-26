name: fix-github-workflows
description: Fix GitHub Actions workflow failures for network device upgrade system
version: "3.0.0"

input:
  - name: workflow_name
    description: Specific workflow to fix (optional)
    required: false
  - name: dry_run
    description: Analyze issues without making changes
    required: false
    default: false

output:
  - type: workflow_status
    description: Current status of workflows
  - type: fixes_applied
    description: List of fixes applied

prompt: |
  Fix GitHub Actions workflow failures for this Ansible network device upgrade system.

  ## 1. Check Workflow Status First

  **Always start by checking current workflow status:**
  ```bash
  echo "🔍 Checking current workflow status..."
  gh run list --limit 10

  # Get specific failed run details
  echo "📋 Latest workflow runs:"
  gh run list --limit 3 --json status,conclusion,name,databaseId | \
    jq -r '.[] | "\(.name): \(.status)/\(.conclusion) (ID: \(.databaseId))"'

  # Check for any currently running workflows
  RUNNING_WORKFLOWS=$(gh run list --status=in_progress --limit 5 --json databaseId --jq '.[].databaseId' | tr '\n' ' ')
  if [ -n "$RUNNING_WORKFLOWS" ]; then
    echo "⚠️  Workflows currently running: $RUNNING_WORKFLOWS"
    echo "💡 Consider waiting for completion or checking specific failures"
  else
    echo "✅ No workflows currently running"
  fi
  ```

  **If workflows are failing, get detailed error information:**
  ```bash
  # Get latest failed run
  FAILED_RUN=$(gh run list --status=failure --limit 1 --json databaseId --jq '.[0].databaseId')
  if [ -n "$FAILED_RUN" ]; then
    echo "🔍 Analyzing latest failed run: $FAILED_RUN"
    gh run view $FAILED_RUN
    echo "📋 Getting failed job logs..."
    gh run view $FAILED_RUN --log-failed | tail -50
  fi
  ```

  ## 2. Identify and Fix Common Issues

  **Container functionality issues (priority fix):**
  ```bash
  # Check container test failures
  echo "🐳 Checking container functionality..."
  if [ -f "tests/container-tests/run-all-container-tests.sh" ]; then
    # Look for permission issues
    grep -r "Permission denied" tests/container-tests/ || echo "No permission issues found"

    # Check for shared library usage
    ls -la tests/container-tests/lib/ || echo "No shared library found"

    # Verify test scripts use shared library
    grep -l "source.*lib/test-common.sh" tests/container-tests/*.sh || echo "Scripts may not be using shared library"
  fi
  ```

  **Ansible linting issues:**
  ```bash
  echo "🔧 Checking Ansible linting..."
  if command -v ansible-lint >/dev/null; then
    ansible-lint ansible-content/ --format=pep8 | head -20
  fi

  if command -v yamllint >/dev/null; then
    yamllint ansible-content/ tests/ | head -20
  fi
  ```

  **Fix common workflow file issues:**
  ```bash
  echo "📝 Checking workflow files..."

  # Check for deprecated actions
  find .github/workflows -name "*.yml" -exec grep -l "actions/setup-python@v[12]" {} \; | while read file; do
    echo "Updating deprecated actions in: $file"
  done

  # Validate workflow YAML
  find .github/workflows -name "*.yml" | while read file; do
    python -c "import yaml; yaml.safe_load(open('$file'))" 2>&1 | grep -v "^$" && echo "❌ YAML issue in $file"
  done
  ```

  ## 3. Apply Targeted Fixes

  {% if not dry_run %}
  **Make targeted fixes based on failures found:**
  - Fix container test permission conflicts by ensuring shared library usage
  - Update deprecated GitHub Actions versions
  - Fix Ansible linting violations
  - Correct YAML formatting issues
  - Update Python/Ansible versions if needed

  **Commit fixes systematically:**
  ```bash
  # Commit workflow fixes
  if git diff --quiet .github/workflows/; then
    echo "No workflow changes to commit"
  else
    git add .github/workflows/
    git commit -m "ci: fix GitHub Actions workflow issues"
  fi

  # Commit test fixes
  if git diff --quiet tests/; then
    echo "No test changes to commit"
  else
    git add tests/
    git commit -m "test: fix container functionality and permission issues"
  fi
  ```
  {% endif %}

  ## 4. Verify Fixes

  ```bash
  echo "✅ Verifying fixes..."

  {% if not dry_run %}
  # Push changes
  git push origin main

  # Wait and check new run
  echo "⏳ Waiting for new workflow run..."
  sleep 10
  gh run list --limit 3
  {% else %}
  echo "🔍 DRY RUN: Would push changes and verify workflow status"
  {% endif %}
  ```

  {% if workflow_name %}
  **Focus on specific workflow: {{workflow_name}}**
  {% endif %}

  {% if dry_run %}
  **DRY RUN MODE**: Only analyze issues without making changes
  {% endif %}

  Start by checking the current workflow status, then systematically fix identified issues.