# Claude Code Context Guide - Network Device Upgrade System

**Purpose**: Complete, context-ready reference for Claude Code to work effectively on this codebase
**Use**: Load at start of session, reference throughout
**Optimization**: Fits within context window, prevents repeated mistakes, includes coding standards

---

## Quick Facts

**Project**: Network device upgrade management system (1000+ devices, 5 platforms)
**Tech Stack**: Ansible 11.0.0, AWX, NetBox, Grafana, InfluxDB, Redis
**Main Workflow**: `ansible-content/playbooks/main-upgrade-workflow.yml` (8 steps, tag-based execution)
**Test Suite**: 22 tests, ALL must pass, run with `./tests/run-all-tests.sh`
**Platforms**: Cisco NX-OS, Cisco IOS-XE, FortiOS, Opengear, Metamako MOS

---

## CRITICAL: Do Not Repeat These Mistakes

### Mistake 1: Empty Data Handling
❌ **WRONG** - Creating complex conditionals for empty data
```yaml
- when: data is defined and data | length > 0
  set_fact:
    normalized: "{{ data | ... }}"
```

✅ **RIGHT** - Just normalize, let empty pass through
```yaml
- set_fact:
    normalized: "{{ data | ... }}"
# Empty data naturally returns empty difference()
```
**Key**: "Normalization of empty data returns empty data. Why create conditions?"

### Mistake 2: Reporting Outside Blocks
❌ **WRONG** - Reporting separated from validation
```yaml
- name: Validate
  block:
    - normalize
    - compare
- name: Report  # Separated - WRONG
```

✅ **RIGHT** - Reporting inside block
```yaml
- name: Validate
  block:
    - normalize
    - compare
    - report  # INSIDE block
```

### Mistake 3: Status Set Multiple Times
❌ **WRONG** - Initialize, conditionally set, set again
```yaml
- set_fact: status: NOT_RUN
# ... logic ...
- when: condition1
  set_fact: status: PASS
- when: condition2
  set_fact: status: FAIL
- when: not condition1 and not condition2
  set_fact: status: NOT_RUN  # Set AGAIN
```

✅ **RIGHT** - Initialize once, set once
```yaml
- set_fact: status: NOT_RUN  # ONCE at start
# ... all validation logic ...
- set_fact: status: "{{ 'PASS' if all_passed else 'FAIL' }}"  # ONCE at end
```

### Mistake 4: Incomplete Analysis (Critical)
❌ **WRONG** - Claim comprehensive but miss items
```
"I found X files and reviewed them all"
(Actually sampled/missed some)
```

✅ **RIGHT** - Document search strategy and coverage
```
Search methods used:
  - glob "docs/**/*.md" → 28 files
  - grep "pattern" → 5 matches
  - ripgrep verification → confirmed

Coverage: 100% of 28 files analyzed
Search patterns: [list them]
```

### Mistake 5: Inconsistency Across Codebase
❌ **WRONG** - Fix one task, ignore similar ones
```
One task has: when: bgp_enabled
Others don't - left unchanged
```

✅ **RIGHT** - Search ALL, fix ALL
```
1. Find ALL instances: grep -r "bgp"
2. List them: [10 files found]
3. Apply change consistently to all 10
4. Verify with re-search
```

---

## Code Standards (Zero Tolerance)

### YAML Formatting Rules
- **NEVER use folded scalars (`|`, `>`, `>-`) in**: conditionals, paths, when clauses, debug msg
- **ALWAYS use YAML list syntax for messages**:
  ```yaml
  # RIGHT
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

### Variable Management Rules
- **NEVER** use `| default()` in playbooks/tasks
- **NEVER** use `| default()` in when conditionals
- **NEVER** use `and` in when conditionals (use YAML list format)
- Exception: `| default(omit)` allowed for optional module parameters
- Exception: `| default()` allowed ONLY in `roles/*/defaults/main.yml`
- All variables must be in `group_vars/all.yml` or role defaults

### Platform-Specific Task Organization (MANDATORY)
**MUST**: Single block with ONE when clause per platform
```yaml
# RIGHT - single when clause
- name: NX-OS Validation
  when: platform == 'nxos'
  block:
    - assert facts available
    - name: BGP validation
      when: bgp_enabled | bool  # Feature condition inside block only
      # ...
    - name: Interface validation
      # ...

# WRONG - redundant platform checks everywhere
- include_tasks: bgp.yml
  when:
    - platform == 'nxos'  # Redundant
    - bgp_enabled | bool
```

---

## Network Validation Patterns

**All validation tasks follow this structure** (use as template):

```yaml
- name: Initialize status
  set_fact:
    comparison_status: NOT_RUN

- name: Main Validation Block
  block:
    # Collect data (no conditions here)
    - name: Gather facts
      # ...

    # Data-type-specific blocks (repeat for each data type)
    - name: Validate ARP Data
      when: arp_enabled | bool  # Feature condition if needed
      block:
        - name: Normalize ARP (exclude time-sensitive fields)
          set_fact:
            arp_normalized: "{{ arp_operational | dict2items | rejectattr('key', 'in', ['age', 'time_stamp']) | list | items2dict }}"

        - name: Compare normalized ARP
          set_fact:
            arp_diff: "{{ arp_normalized | difference(arp_baseline_normalized) }}"

        - name: Report ARP results
          debug:
            msg:
              - "ARP Comparison Results:"
              - "Added: {{ arp_diff.added | length }}"

    # Repeat for other data types (BGP, routing, BFD, multicast, etc.)

- name: Set final comparison status
  set_fact:
    comparison_status: "{{ 'PASS' if all_validations_passed else 'FAIL' }}"
```

**Data Types & Normalization**:
- **Normalize** (exclude time fields): BGP, ARP, Routing (RIB/FIB), BFD, Multicast (PIM/IGMP)
- **Raw comparison** (no normalization): Network Resources, MAC operational
- See `docs/internal/network-validation-data-types.md` for all excluded fields

---

## Pre-Commit Quality Checklist (MANDATORY)

**ALL must pass. ZERO tolerance for failures.**

```bash
# 1. TESTS MUST PASS (exit code 0)
./tests/run-all-tests.sh
# Expected: Passed: 22, Failed: 0

# 2. SYNTAX VALIDATION (provide all required extra_vars)
ansible-playbook --syntax-check ansible-content/playbooks/main-upgrade-workflow.yml \
  --extra-vars="target_hosts=localhost target_firmware=test.bin maintenance_window=true max_concurrent=1"
ansible-playbook --syntax-check ansible-content/playbooks/health-check.yml \
  --extra-vars="target_hosts=localhost"
ansible-playbook --syntax-check ansible-content/playbooks/config-backup.yml

# 3. LINTING (exit code 0)
ansible-lint ansible-content/ --offline --parseable-severity
yamllint ansible-content/

# 4. VERIFY CONSISTENCY
# For ANY code change, verify:
# - Found ALL instances (use grep, ripgrep, manual review)
# - Applied change everywhere, not just obvious places
# - Document search patterns used
```

**Test Count**: 22 tests (not 23, not 20 - exactly 22)

---

## Common Commands

```bash
# Test suite
./tests/run-all-tests.sh

# Syntax check (ALWAYS include extra_vars)
ansible-playbook --syntax-check <file> --extra-vars="..."

# Check mode (test without making changes)
ansible-playbook --check --diff <file> --extra_vars="..."

# Git operations
git status
git add <file>
git commit -m "message"
git push origin branch

# File search (use these to find things)
grep -r "pattern" .
rg "pattern" .
find . -name "*.yml"
```

---

## Project Structure (Key Files)

```
ansible-content/
  playbooks/
    main-upgrade-workflow.yml          ← Master workflow (8 steps, tag-based)
    health-check.yml                   ← Deprecated
    network-validation.yml             ← Deprecated
    config-backup.yml
    compliance-audit.yml
  roles/
    network-validation/
      tasks/
        main.yml                       ← Calls all validation tasks
        arp-validation.yml             ← Standardized pattern
        routing-validation.yml         ← Standardized pattern
        bfd-validation.yml             ← Standardized pattern
        multicast-validation.yml       ← Standardized pattern (template)
        network-resource-validation.yml
        bgp-validation.yml
        interface-validation.yml
      defaults/main.yml                ← Excluded fields for normalization

tests/
  run-all-tests.sh                     ← Run this before every commit
  unit-tests/
  integration-tests/
  vendor-tests/
  validation-tests/

docs/
  CLAUDE.md                            ← Project standards (read if unsure)
  README.md                            ← User documentation
  internal/
    network-validation-data-types.md   ← Reference for all data types
    baseline-comparison-examples.md    ← Real examples
```

---

## Tag-Based Workflow Reference

Main workflow uses tags for step execution. Each step depends directly on STEP 1 (connectivity):

```bash
# STEP 1: Connectivity check only
ansible-playbook main-upgrade-workflow.yml --tags step1 -e target_hosts=... -e max_concurrent=5

# STEP 2: Version check (auto-runs step1 first via main workflow)
ansible-playbook main-upgrade-workflow.yml --tags step2 -e target_hosts=... -e max_concurrent=5

# ... continue for steps 3-8 ...

# Full workflow (all 8 steps)
ansible-playbook main-upgrade-workflow.yml -e target_hosts=... -e target_firmware=... -e max_concurrent=5 -e maintenance_window=true

# POST-UPGRADE VALIDATION ONLY (requires STEP 5 baseline)
ansible-playbook main-upgrade-workflow.yml --tags step7 -e target_hosts=... -e max_concurrent=5

# EMERGENCY ROLLBACK
ansible-playbook main-upgrade-workflow.yml --tags step8 -e target_hosts=... -e max_concurrent=5
```

**Required extra_vars**:
- All steps: `target_hosts`, `max_concurrent`
- Steps 4-7: `target_firmware`
- Step 6 only: `maintenance_window=true` (safety flag)

---

## When You're Uncertain

### "Am I done with analysis?"
- [ ] Used multiple search methods (grep, ripgrep, manual)?
- [ ] Stated total count of files checked?
- [ ] Documented search patterns used?
- [ ] Could more instances exist?

**If ANY unchecked → Keep searching**

### "Is this change consistent?"
- [ ] Found ALL similar patterns (not just obvious)?
- [ ] Applied change everywhere?
- [ ] Checked all roles, tasks, plays?
- [ ] Verified no exceptions/edge cases?

**If ANY unchecked → Search more comprehensively**

### "Are tests actually passing?"
- [ ] Ran full suite (`./tests/run-all-tests.sh`)?
- [ ] Exit code is exactly 0?
- [ ] Output shows "Passed: 22"?
- [ ] No failures hidden in output?

**Show exact test output in verification**

---

## How to Approach Different Tasks

### Simple Change (1-2 files)
1. Understand context (read related files)
2. Make change
3. Run tests
4. Commit

### Medium Change (3-10 files)
1. Create todo list (3-5 items)
2. Search comprehensively (find ALL related files)
3. Make changes systematically
4. Verify consistency (re-search pattern)
5. Run tests
6. Commit

### Complex Change (10+ files or multi-phase)
1. Understand existing patterns (read multiple examples)
2. Create detailed todo list
3. Search comprehensively (document strategy)
4. Make changes systematically
5. Verify consistency (multiple search methods)
6. Run tests
7. Multiple commits if needed

### Analysis/Audit Task
1. **Inventory Phase**: List ALL files (use glob patterns)
   - Document search methods
   - State total count
2. **Analysis Phase**: Read/analyze each file
   - Map to purpose
   - Identify issues
3. **Verification Phase**: Cross-verify findings
   - Use multiple search tools
   - Verify 100% coverage
   - Check for missing files
4. **Documentation Phase**: Report findings
   - Document search patterns used
   - Categorize issues
   - Provide recommendations
   - State: "100% of X files analyzed"

---

## Recent Lessons (November 2025)

### Lesson 1: Empty Data
"Normalization of empty data returns empty data. Why are you checking for all these conditions?"
→ **Don't create complex conditionals for natural behaviors**

### Lesson 2: Block Organization
"Reporting should be part of the block"
→ **Group normalization + comparison + reporting together**

### Lesson 3: Status Management
"Set a default at the start, and then set it to a value at the end, only"
→ **Initialize once, finalize once (never in middle)**

### Lesson 4: Consistency
"Look at main again. Make sure it is consistent!"
→ **Check ALL similar tasks, not just obvious ones**

### Lesson 5: Thoroughness
"Did you analyze ALL of the codebase and ALL of the documentation?"
→ **Use multiple search methods, state 100% coverage**

### Lesson 6: Documentation
"The goal is to make sure documentation is current and correct"
→ **Documentation must match implementation exactly**

---

## File-Specific Notes

### CLAUDE.md
- Contains complete standards (read if needing detail)
- Has Table of Contents for navigation
- Agent-Based Workflow Guidance section (lines 805-1003)

### docs/internal/network-validation-data-types.md
- Reference for all 11 validation data types
- Shows excluded fields for normalization
- Contains implementation examples

### Main Workflow (main-upgrade-workflow.yml)
- **8 Steps** (tag-based execution):
  - Step 1: Connectivity (STEP 1 only)
  - Step 2: Version check
  - Step 3: Space check
  - Step 4: Image upload
  - Step 5: Config backup + pre-validation
  - Step 6: Installation + reboot
  - Step 7: Post-validation
  - Step 8: Emergency rollback
- **Dependency Model**: Each step depends directly on STEP 1; main workflow manages additional dependencies via tags

### Test Suite (22 tests)
- Unit tests (variables, templates, logic)
- Integration tests (workflows, multi-platform)
- Vendor tests (platform-specific)
- Validation tests (comprehensive)
- Syntax validation
- Linting checks

---

## Avoiding Context Window Issues

**This file is optimized to**:
- Fit in context window
- Be loaded at session start
- Prevent repeated mistakes
- Contain all essential coding standards
- Include quick reference for common issues
- Avoid redundancy with CLAUDE.md (which you can reference if needed detail)

**When you need more detail**:
- Syntax rules → CLAUDE.md (Code Standards section)
- Validation patterns → docs/internal/network-validation-data-types.md
- Project guidance → CLAUDE.md (complete reference)

---

## Quick Reference: Do's and Don'ts

### ✅ DO

- Use YAML list syntax for messages
- Define variables in group_vars or role defaults
- Initialize status once, set once
- Group related tasks in blocks
- Report INSIDE blocks
- Search comprehensively (multiple methods)
- Document search patterns
- Run full test suite before commit
- Verify consistency across codebase
- Reference related files when making changes

### ❌ DON'T

- Use folded scalars in conditionals or paths
- Use `| default()` in playbooks (exception: role defaults, omit parameter)
- Use `and` in when conditionals
- Create conditionals for empty data edge cases
- Separate reporting from validation logic
- Set status multiple times
- Fix just obvious instances
- Claim comprehensive without documenting coverage
- Leave documentation inaccurate after code changes
- Commit without passing all 22 tests

---

**Load this file at the start of your session and reference it when making decisions about code changes, analysis approaches, or when uncertain about patterns.**
