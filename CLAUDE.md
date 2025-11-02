# CLAUDE.md

Project guidance for developers and automation systems working with the Network Device Upgrade Management System.

---

## Project Overview

**Network device upgrade management system** for 1000+ heterogeneous network devices. Automates firmware upgrades across multiple vendor platforms using Ansible with AWX and NetBox as native systemd services.

**Key Technologies**: Ansible 11.0.0, AWX, NetBox, Grafana, InfluxDB v2, Redis
**Supported Platforms**: Cisco NX-OS, Cisco IOS-XE, FortiOS, Opengear, Metamako MOS
**Main Workflow**: `ansible-content/playbooks/main-upgrade-workflow.yml` (8-step tag-based execution)

---

## Critical Standards (Zero Tolerance - No Exceptions)

### 1. Code Quality

- **Generate error-free code**: ALL code MUST be syntactically correct and functionally working on first generation
- **Pass linting**: ALL code MUST pass `ansible-lint` and `yamllint` with 0 errors/warnings
- **Pass tests**: ALL code MUST pass full test suite (22 tests)
- **Test updates**: Code changes MUST include test file updates
- **Exit code 0**: All validation steps MUST return exit code 0

### 2. YAML Formatting (MANDATORY)

- ❌ **NEVER** use folded scalars (`|`, `>`, `>-`) in: conditionals, paths, when clauses, debug messages
- ✅ **ALWAYS** use YAML list syntax for messages:
  ```yaml
  # CORRECT
  - name: Display results
    debug:
      msg:
        - "Line 1"
        - "Line 2: {{ variable }}"

  # WRONG
  - name: Display results
    debug:
      msg: |
        Line 1
        Line 2: {{ variable }}
  ```

### 3. Variable Management (MANDATORY)

- ❌ **NEVER** use `| default()` in playbooks, tasks, or when conditionals
- ✅ Variables MUST be defined in `group_vars/all.yml` or `roles/*/defaults/main.yml`
- Exception: `| default(omit)` allowed for optional Ansible module parameters only
- Exception: `| default()` allowed ONLY in `roles/*/defaults/main.yml`
- ❌ **NEVER** use `and` in when conditionals - use YAML list syntax instead

### 4. Platform-Specific Organization (MANDATORY)

All platform-specific tasks MUST be organized under a single block with ONE when clause:

```yaml
# CORRECT: Single when clause
- name: NX-OS Validation
  when: platform == 'nxos'
  block:
    - name: Assert facts available
      assert:
        that:
          - ansible_network_resources is defined

    - name: BGP validation
      when: bgp_enabled | bool  # Feature condition INSIDE block only
      include_tasks: bgp-validation.yml

    - name: Interface validation
      include_tasks: interface-validation.yml
```

**Benefits**:
- When condition evaluated once, not per task
- Clear platform boundary
- Single point to modify platform logic
- Prevents accidental cross-platform execution

### 5. Comprehensive Analysis (Required for any audit/review)

When performing analysis (documentation audits, code reviews, refactoring):

1. **Inventory Phase**: Document ALL files using multiple search methods (glob patterns, grep, ripgrep)
   - State total count: "X files found"
   - Document search patterns used

2. **Analysis Phase**: Read and analyze each file
   - Map to purpose/category
   - Identify issues, stale content, relationships

3. **Cross-Verification Phase**: Verify findings are complete
   - Use MULTIPLE search tools
   - Check for missing files
   - Verify 100% coverage (not sampling)

4. **Documentation Phase**: Report results
   - Document ALL search patterns used
   - List complete inventory with purposes
   - State: "100% of X files analyzed"

---

## Deprecated Playbooks (Scheduled for Removal)

The following playbooks are **deprecated** and will be removed in v5.0.0. Use `main-upgrade-workflow.yml` with tag-based execution instead:

- `health-check.yml` → Use `main-upgrade-workflow.yml --tags step1`
- `network-validation.yml` → Use `main-upgrade-workflow.yml --tags step5` or `--tags step7`
- `image-loading.yml` → Use `main-upgrade-workflow.yml --tags step4`
- `image-installation.yml` → Use `main-upgrade-workflow.yml --tags step6`
- `emergency-rollback.yml` → Use `main-upgrade-workflow.yml --tags step8`

**Active Playbooks** (still supported as separate operational tools):
- `compliance-audit.yml` - Separate operational task
- `config-backup.yml` - Useful for ad-hoc backups

---

## Project Structure

```
ansible-content/
  playbooks/
    main-upgrade-workflow.yml          # Master workflow (8 steps, tag-based)
    health-check.yml                   # Deprecated
    network-validation.yml             # Deprecated
    config-backup.yml
    compliance-audit.yml
  roles/
    network-validation/
      tasks/
        main.yml                       # Calls all validation tasks
        arp-validation.yml             # Standardized validation pattern
        routing-validation.yml
        bfd-validation.yml
        multicast-validation.yml       # Template for pattern
        network-resource-validation.yml
        bgp-validation.yml
        interface-validation.yml
      defaults/main.yml                # Excluded fields for normalization

tests/
  run-all-tests.sh                     # Run this before every commit
  unit-tests/
  integration-tests/
  vendor-tests/
  validation-tests/

docs/
  README.md                            # Documentation hub
  user-guides/                         # User-facing documentation
  platform-guides/                     # Platform-specific guides
  deployment/                          # Deployment guides
  testing/                             # Testing documentation
  architecture/                        # Architecture documentation
  internal/                            # Developer reference
    network-validation-data-types.md   # All validation data types
    baseline-comparison-examples.md    # Real examples
```

---

## Essential References

### For Development Setup
→ See [Complete Project Guide](README.md) for installation and configuration

### For Test Execution
→ See [Pre-Commit Setup](docs/testing/pre-commit-setup.md) for quality gates

### For Understanding Tag-Based Workflow
→ See [Workflow Architecture](docs/architecture/workflow-architecture.md)

### For Network Validation Implementation
→ See [Network Validation Data Types](docs/internal/network-validation-data-types.md)

### For Platform-Specific Details
→ See [Platform Implementation Status](docs/platform-guides/platform-implementation-status.md)

---

## Network Validation Pattern (Required for all validation tasks)

All validation tasks follow this standardized structure:

```yaml
- name: Initialize status
  set_fact:
    comparison_status: NOT_RUN

- name: Main Validation Block
  block:
    - name: Gather facts
      # ... data collection, no conditionals ...

    - name: Validate Data Type
      when: feature_enabled | bool  # Optional: feature-specific condition
      block:
        - name: Normalize data (exclude time-sensitive fields)
          set_fact:
            normalized: "{{ data | dict2items | rejectattr('key', 'in', ['age', 'time_stamp']) | list | items2dict }}"

        - name: Compare normalized data
          set_fact:
            diff: "{{ normalized | difference(baseline_normalized) }}"

        - name: Report comparison results
          debug:
            msg:
              - "Validation Results:"
              - "Added: {{ diff | length }} items"

- name: Set final comparison status
  set_fact:
    comparison_status: "{{ 'PASS' if validation_passed else 'FAIL' }}"
```

**Key Principles**:
- Empty data naturally returns empty difference() - DON'T create conditionals for empty data
- Report results INSIDE the data-type blocks (not after)
- Initialize status ONCE at start, set final status ONCE at end

**Data Types Reference**:
- **Normalize** (exclude time fields): BGP, ARP, Routing (RIB/FIB), BFD, Multicast (PIM/IGMP)
- **Raw comparison**: Network Resources, MAC operational
- See `docs/internal/network-validation-data-types.md` for all excluded fields

---

## Pre-Commit Quality Checklist (MANDATORY)

**ALL items MUST pass with exit code 0. ZERO tolerance.**

```bash
# 1. Run all tests (must pass 100%)
./tests/run-all-tests.sh
# Expected: Passed: 22, Failed: 0

# 2. Syntax validation (with required extra_vars)
ansible-playbook --syntax-check ansible-content/playbooks/main-upgrade-workflow.yml \
  --extra-vars="target_hosts=localhost target_firmware=test.bin maintenance_window=true max_concurrent=1"
ansible-playbook --syntax-check ansible-content/playbooks/health-check.yml \
  --extra-vars="target_hosts=localhost"
ansible-playbook --syntax-check ansible-content/playbooks/config-backup.yml

# 3. Linting validation (exit code 0)
ansible-lint ansible-content/ --offline --parseable-severity
yamllint ansible-content/

# 4. Verify consistency
# For any code change:
# - Find ALL related instances (use grep, ripgrep, manual search)
# - Apply changes everywhere consistently
# - Document search patterns used
```

---

## Common Mistakes to Avoid

### Mistake 1: Empty Data Handling
❌ **WRONG** - Creating conditions for empty data
```yaml
- when: data is defined and data | length > 0
  set_fact: normalized: "{{ data | ... }}"
```
✅ **RIGHT** - Just normalize, let empty pass through naturally
```yaml
- set_fact: normalized: "{{ data | ... }}"
```
**Key**: Normalization of empty data returns empty naturally.

### Mistake 2: Reporting Location
❌ **WRONG** - Reporting separated from validation
```yaml
- block:
    - normalize
    - compare
- name: Report  # Separated - WRONG
```
✅ **RIGHT** - Reporting inside the block
```yaml
- block:
    - normalize
    - compare
    - report  # INSIDE block
```

### Mistake 3: Status Management
❌ **WRONG** - Set multiple times
```yaml
- set_fact: status: NOT_RUN
- when: condition
  set_fact: status: PASS
- when: not condition
  set_fact: status: NOT_RUN  # Set AGAIN
```
✅ **RIGHT** - Set once at start, once at end
```yaml
- set_fact: status: NOT_RUN  # ONCE at start
# ... all logic ...
- set_fact: status: "{{ 'PASS' if ok else 'FAIL' }}"  # ONCE at end
```

### Mistake 4: Incomplete Analysis
❌ **WRONG** - Claim comprehensive without evidence
```
"I reviewed all documentation files"
(Actually sampled/missed some)
```
✅ **RIGHT** - Document search strategy and coverage
```
Search methods: glob "docs/**/*.md" → 28 files, grep "pattern" → 5 matches
Coverage: 100% of 28 files analyzed
Search patterns used: [list them]
```

### Mistake 5: Inconsistency Across Codebase
❌ **WRONG** - Fix one task, ignore similar ones
✅ **RIGHT** - Search ALL instances, fix ALL, verify ALL
1. Find ALL instances: `grep -r "pattern" .`
2. List all locations
3. Apply change to every location
4. Verify with re-search

---

## Test Suite

**22 tests** covering:
- Unit tests (variables, templates, workflow logic)
- Integration tests (end-to-end workflows)
- Vendor tests (platform-specific functionality)
- Validation tests (comprehensive validation)
- Syntax validation (all Ansible files)
- Linting (YAML, Ansible standards)

Run before every commit:
```bash
./tests/run-all-tests.sh
```

Expected result: `Passed: 22, Failed: 0`

---

## When You Need More Detail

- **Installation/Setup**: Read [README.md](README.md)
- **Testing/Pre-Commit**: Read [Pre-Commit Setup](docs/testing/pre-commit-setup.md)
- **Workflow Details**: Read [Workflow Architecture](docs/architecture/workflow-architecture.md)
- **Validation Patterns**: Read [Network Validation Data Types](docs/internal/network-validation-data-types.md)
- **Platform Details**: Read [Platform Implementation Status](docs/platform-guides/platform-implementation-status.md)
- **Deployment**: Read [Deployment Guides](docs/deployment/)

---

**Last Updated**: November 2, 2025
**System Version**: 4.0.0
**Documentation Version**: 3.0.0
