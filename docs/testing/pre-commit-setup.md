# Pre-commit Hooks Setup Guide

This project uses [pre-commit](https://pre-commit.com/) to enforce code quality standards automatically before commits.

---

## Quick Setup

```bash
# Install pre-commit
pip install pre-commit

# Install the git hook scripts
pre-commit install

# (Optional) Run against all files
pre-commit run --all-files
```

---

## What Gets Checked

### Repository Hygiene
- ✅ **No backup files** - Prevents `.bak`, `.tmp`, `.old` files from being committed
- ✅ **Trailing whitespace** - Removes unnecessary spaces at line ends
- ✅ **End of file** - Ensures files end with a newline
- ✅ **Large files** - Prevents files over 1MB from being committed
- ✅ **Merge conflicts** - Detects unresolved merge conflict markers
- ✅ **Case conflicts** - Prevents filenames that differ only in case

### YAML & Ansible
- ✅ **YAML syntax** - Validates all YAML files
- ✅ **YAML linting** - Enforces YAML style with yamllint
- ✅ **Ansible linting** - Runs ansible-lint with production profile
  - Excludes: `.github/`, `tests/` directories

### Python Scripts
- ✅ **Black formatting** - Auto-formats Python code
- ✅ **Flake8 linting** - Enforces Python code style

### Shell Scripts
- ✅ **ShellCheck** - Lints bash/sh scripts for issues

### Security
- ✅ **Secret detection** - Scans for accidentally committed secrets
  - Uses `.secrets.baseline` for known false positives

### Documentation
- ✅ **Markdown linting** - Validates and auto-fixes Markdown files

---

## Configuration Files

### `.pre-commit-config.yaml`
Main configuration file defining all hooks and their versions.

### `.yamllint.yml`
YAML linting rules tailored for Ansible projects:
- Line length: 180 characters (warning)
- Ansible-friendly truthy values: `yes/no/on/off`
- Document markers optional
- Duplicate keys allowed (Ansible overrides)

### `.secrets.baseline`
Baseline file for detect-secrets to track known false positives.

---

## Daily Usage

### Automatic Checks
Pre-commit runs automatically on `git commit`. If checks fail:

```bash
# Example output
Check for backup files.........................................Failed
- hook id: no-backup-files
- exit code: 1

Found backup file: ansible-content/roles/example/main.yml.bak
```

Fix the issues and commit again:
```bash
rm ansible-content/roles/example/main.yml.bak
git add -A
git commit -m "fix: remove backup file"
```

### Manual Execution

Run all hooks manually:
```bash
pre-commit run --all-files
```

Run specific hook:
```bash
pre-commit run ansible-lint --all-files
pre-commit run yamllint --all-files
pre-commit run shellcheck --all-files
```

Run only on staged files:
```bash
pre-commit run
```

### Skip Hooks (Use Sparingly)

Skip all hooks for a specific commit:
```bash
git commit --no-verify -m "emergency fix"
```

Skip specific hook:
```bash
SKIP=ansible-lint git commit -m "WIP: ansible changes"
```

---

## Updating Hooks

Pre-commit hooks are updated automatically via `pre-commit.ci` weekly.

Manual update:
```bash
pre-commit autoupdate
```

---

## CI/CD Integration

Pre-commit hooks also run in GitHub Actions via [pre-commit.ci](https://pre-commit.ci/).

### Features
- ✅ Auto-fixes committed and pushed to PR
- ✅ Weekly auto-updates of hook versions
- ✅ Runs on all pull requests

### Configuration
See `ci:` section in `.pre-commit-config.yaml`

---

## Troubleshooting

### Hook Installation Failed
```bash
# Clean install
pre-commit uninstall
pre-commit clean
pre-commit install
```

### Ansible-lint Errors
```bash
# Test ansible-lint separately
ansible-lint ansible-content/ --profile=production
```

### YAML Lint Errors
```bash
# Test yamllint separately
yamllint ansible-content/ -c .yamllint.yml
```

### Secret Detection False Positives
If detect-secrets flags a false positive:

```bash
# Update baseline
detect-secrets scan --baseline .secrets.baseline

# Audit and approve
detect-secrets audit .secrets.baseline
```

### Skip Problematic Hook Temporarily
Add to `.pre-commit-config.yaml`:
```yaml
- repo: https://github.com/ansible/ansible-lint
  rev: v24.2.0
  hooks:
    - id: ansible-lint
      stages: [manual]  # Only runs when explicitly called
```

---

## Best Practices

1. **Install early**: Set up pre-commit at the start of development
2. **Run regularly**: Use `pre-commit run --all-files` after major changes
3. **Fix incrementally**: Address issues as they arise, don't skip hooks
4. **Update often**: Keep hooks up-to-date with `pre-commit autoupdate`
5. **Team alignment**: Ensure all developers use the same pre-commit config

---

## Additional Resources

- [Pre-commit Documentation](https://pre-commit.com/)
- [Ansible-lint Rules](https://ansible-lint.readthedocs.io/)
- [YAMLlint Documentation](https://yamllint.readthedocs.io/)
- [Detect-secrets](https://github.com/Yelp/detect-secrets)
- [ShellCheck Wiki](https://www.shellcheck.net/wiki/)
