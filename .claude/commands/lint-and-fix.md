name: lint-and-fix
description: Run Ansible linting and auto-fix issues for network device upgrade system
version: "3.0.0"

input:
  - name: target_path
    description: Path to lint (defaults to ansible-content)
    required: false
    default: "ansible-content"
  - name: dry_run
    description: Show what would be fixed without making changes
    required: false
    default: false

output:
  - type: fixes
    description: Summary of fixes applied
  - type: remaining_issues
    description: Issues that require manual intervention

prompt: |
  Run comprehensive Ansible linting and auto-fix for this network device upgrade system.

  Target: {{target_path}}
  {% if dry_run %}**DRY RUN MODE** - Show issues without fixing{% endif %}

  ## 1. Ansible Linting

  **Run ansible-lint:**
  ```bash
  echo "🔧 Running ansible-lint on {{target_path}}"
  if command -v ansible-lint >/dev/null; then
    ansible-lint {{target_path}} --format=pep8

    {% if not dry_run %}
    # Apply auto-fixable rules
    ansible-lint {{target_path}} --fix
    {% endif %}
  else
    echo "⚠️ ansible-lint not found - install with: pip install ansible-lint"
  fi
  ```

  ## 2. YAML Formatting

  **Run yamllint:**
  ```bash
  echo "📝 Running yamllint"
  if command -v yamllint >/dev/null; then
    yamllint {{target_path}} tests/ .github/workflows/

    {% if not dry_run %}
    # Fix basic YAML issues (trailing spaces, line endings)
    find {{target_path}} -name "*.yml" -o -name "*.yaml" | while read file; do
      # Remove trailing whitespace
      sed -i 's/[[:space:]]*$//' "$file"
    done
    {% endif %}
  else
    echo "⚠️ yamllint not found - install with: pip install yamllint"
  fi
  ```

  ## 3. Ansible Playbook Syntax

  **Validate playbook syntax:**
  ```bash
  echo "✅ Checking Ansible playbook syntax"
  if [ -d "{{target_path}}/playbooks" ]; then
    find {{target_path}}/playbooks -name "*.yml" | while read playbook; do
      echo "Checking: $playbook"
      ANSIBLE_CONFIG={{target_path}}/ansible.cfg ansible-playbook --syntax-check "$playbook" -i /dev/null
    done
  fi
  ```

  ## 4. Summary

  **Report results:**
  ```bash
  {% if not dry_run %}
  echo "🎯 Linting completed. Check git diff for changes:"
  git diff --name-only

  if [ -n "$(git diff --name-only)" ]; then
    echo "📝 Changes made. Consider committing with:"
    echo "git add ."
    echo "git commit -m 'fix: resolve ansible-lint and yaml formatting issues'"
  else
    echo "✅ No changes needed - all files are already compliant"
  fi
  {% else %}
  echo "🔍 DRY RUN completed - no changes made"
  {% endif %}
  ```

  Focus on network device upgrade playbooks and roles for Cisco, FortiOS, and Opengear platforms.