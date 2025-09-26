name: code-commit
description: Validate and commit Ansible code with comprehensive checks
version: "4.0.0"

input:
  - name: commit_message
    description: Commit message following conventional commit format
    required: true
  - name: push
    description: Whether to push after successful commit
    required: false
    default: true

output:
  - type: validation_report
    description: Linting and testing results
  - type: commit_info
    description: Git commit details

prompt: |
  Execute code validation and commit with zero tolerance for linting errors.

  Commit message: "{{commit_message}}"
  Push after commit: {{push}}

  ## 1. Pre-Commit Validation

  **Check repository state:**
  ```bash
  git status
  echo "Current branch: $(git branch --show-current)"
  pwd && ls -la | grep -E "(ansible-content|tests|\.github)"
  ```

  ## 2. Run All Quality Checks

  **Ansible linting (must pass):**
  ```bash
  echo "🔧 Running ansible-lint..."
  if command -v ansible-lint >/dev/null; then
    ansible-lint ansible-content/ --format=pep8 || {
      echo "❌ ansible-lint failed - commit blocked"
      exit 1
    }
  fi
  ```

  **YAML validation (must pass):**
  ```bash
  echo "📝 Running yamllint..."
  if command -v yamllint >/dev/null; then
    yamllint ansible-content/ tests/ .github/ || {
      echo "❌ yamllint failed - commit blocked"
      exit 1
    }
  fi
  ```

  **Test suite (must pass):**
  ```bash
  echo "🧪 Running test suite..."
  if [ -f "tests/run-all-tests.sh" ]; then
    ./tests/run-all-tests.sh || {
      echo "❌ Test suite failed - commit blocked"
      exit 1
    }
  fi
  ```

  ## 3. Commit and Push

  **Only commit if all checks pass:**
  ```bash
  # All validations passed - safe to commit
  git add .
  git commit -m "{{commit_message}}

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"

  {% if push %}
  git push origin main
  echo "✅ Changes committed and pushed successfully"
  {% else %}
  echo "✅ Changes committed successfully (not pushed)"
  {% endif %}
  ```

  Zero tolerance policy - any validation failure blocks the commit.