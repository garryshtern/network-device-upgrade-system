# Claude Code Instructions - Network Device Upgrade System

**Automatically loaded at session start. Use this to code effectively and avoid mistakes.**

---

## CRITICAL: Mistakes to Avoid (Do Not Repeat)

### 1. Empty Data Handling ❌→✅
```yaml
# WRONG: Creating conditions for empty data
- when: data is defined and data | length > 0
  set_fact: normalized: "{{ data | ... }}"

# RIGHT: Just normalize, let empty pass through
- set_fact: normalized: "{{ data | ... }}"
```
**Key**: "Normalization of empty data returns empty data"

### 2. Reporting Location ❌→✅
```yaml
# WRONG
- block:
    - normalize
    - compare
- name: Report   # SEPARATED

# RIGHT
- block:
    - normalize
    - compare
    - report    # INSIDE block
```

### 3. Status Management ❌→✅
```yaml
# WRONG: Set multiple times
- set_fact: status: NOT_RUN
- when: cond1
  set_fact: status: PASS
- when: cond2
  set_fact: status: NOT_RUN  # Set again

# RIGHT: Once at start, once at end
- set_fact: status: NOT_RUN  # ONCE
# ... logic ...
- set_fact: status: "{{ 'PASS' if ok else 'FAIL' }}"  # ONCE
```

### 4. Incomplete Analysis ❌→✅
```
WRONG: "I reviewed all X files"
RIGHT: "Reviewed 28 files using: grep X, ripgrep Y, manual Z. 100% coverage."
```
**Key**: Document search patterns, state exact coverage

### 5. Inconsistency ❌→✅
```
WRONG: Fix one task, ignore similar ones
RIGHT: Find ALL instances (grep, ripgrep, manual), fix ALL, verify ALL
```

---

## Code Standards (Zero Tolerance)

**YAML Rules**:
- ❌ NEVER folded scalars (`|`, `>`) in: conditionals, paths, when, debug msg
- ✅ ALWAYS YAML list syntax for messages
```yaml
# RIGHT
debug:
  msg:
    - "Line 1"
    - "Line 2: {{ var }}"

# WRONG
debug:
  msg: |
    Line 1
    Line 2: {{ var }}
```

**Variables**:
- ❌ NO `| default()` in playbooks/tasks/conditionals
- ✅ Put in `group_vars/all.yml` or `roles/*/defaults/main.yml`
- Exception: `| default(omit)` for optional module params only

**Platform Organization (MANDATORY)**:
```yaml
# RIGHT: Single when clause per platform
- name: NX-OS Validation
  when: platform == 'nxos'
  block:
    - name: BGP
      when: bgp_enabled | bool  # Feature conditions INSIDE only
      # ...
```

---

## Network Validation Template

**All validation tasks follow this pattern:**

```yaml
- set_fact: comparison_status: NOT_RUN

- name: Main Validation
  block:
    - name: Gather facts
      # ... no conditionals here ...

    - name: Validate Data Type
      when: feature_enabled | bool  # Feature condition if needed
      block:
        - set_fact:
            normalized: "{{ data | dict2items | rejectattr('key', 'in', ['age', 'time_stamp']) | list | items2dict }}"
        - set_fact:
            diff: "{{ normalized | difference(baseline_normalized) }}"
        - debug:
            msg:
              - "Results:"
              - "Added: {{ diff | length }}"

- set_fact: comparison_status: "{{ 'PASS' if validation_ok else 'FAIL' }}"
```

**Normalization Rules**:
- Normalize: BGP, ARP, Routing (RIB/FIB), BFD, Multicast (PIM/IGMP)
- Raw comparison: Network Resources, MAC
- See `docs/internal/network-validation-data-types.md` for excluded fields

---

## Pre-Commit Checklist (MANDATORY)

All must pass. Zero tolerance.

```bash
# 1. TESTS (22 tests, exit code 0)
./tests/run-all-tests.sh
# Expected: Passed: 22, Failed: 0

# 2. SYNTAX (with required extra_vars)
ansible-playbook --syntax-check ansible-content/playbooks/main-upgrade-workflow.yml \
  --extra-vars="target_hosts=localhost target_firmware=test.bin maintenance_window=true max_concurrent=1"
ansible-playbook --syntax-check ansible-content/playbooks/health-check.yml \
  --extra-vars="target_hosts=localhost"
ansible-playbook --syntax-check ansible-content/playbooks/config-backup.yml

# 3. LINTING (0 errors)
ansible-lint ansible-content/ --offline --parseable-severity
yamllint ansible-content/

# 4. CONSISTENCY
# For any code change:
# - Find ALL instances (grep, ripgrep, manual)
# - Apply change everywhere
# - Document search patterns used
```

---

## Quick Decision Tree

**Simple change (1-2 files)**:
1. Read file
2. Make change
3. Run tests
4. Commit

**Medium change (3-10 files)**:
1. Find ALL related files (comprehensive search)
2. Make changes systematically
3. Verify consistency (re-search)
4. Run tests
5. Commit

**Complex change (10+ files)**:
1. Understand patterns (read examples)
2. Find ALL instances (document strategy)
3. Make changes systematically
4. Verify consistency (multiple search methods)
5. Run tests
6. Multiple commits

**Analysis/Audit**:
1. **Inventory**: List ALL files (glob patterns), state count
2. **Analysis**: Read each, map purpose, note issues
3. **Verification**: Cross-verify with multiple search tools
4. **Documentation**: Report with search patterns, state "100% coverage"

---

## When Uncertain

- "Am I done analyzing?" → Check: multiple search methods? Total count stated? Search patterns documented? If any no → keep searching
- "Is this consistent?" → Check: ALL similar patterns found? Change applied everywhere? If any no → search more
- "Tests passing?" → Run full suite, check exit code 0, show "Passed: 22"

---

## Essential Reference

**Main Workflow**: `ansible-content/playbooks/main-upgrade-workflow.yml` (8 steps, tag-based)
**Test Suite**: 22 tests (run with `./tests/run-all-tests.sh`)
**Platforms**: Cisco NX-OS, IOS-XE, FortiOS, Opengear, Metamako MOS
**Tech Stack**: Ansible 11.0.0, AWX, NetBox, Grafana

**Key Files**:
- `docs/internal/network-validation-data-types.md` → All validation data types
- `CLAUDE.md` → Detailed standards (reference if needed)

---

## Last Lessons (November 2025)

1. **Empty data**: Returns empty naturally, don't condition it
2. **Block organization**: Group normalize + compare + report together
3. **Status**: Initialize once, set once (never middle)
4. **Consistency**: Check ALL similar tasks, not just obvious
5. **Analysis**: Document search strategy, state 100% coverage
6. **Documentation**: Must match implementation exactly

---

**Load this at session start. Reference before committing. Run tests before pushing.**
