# Claude Code Working Guide for Network Device Upgrade System

**Purpose**: Practical guide for Claude Code to work efficiently with this codebase
**Last Updated**: November 2, 2025
**Status**: Active - Use this document when working on tasks

---

## Quick Navigation

- **[When Starting Any Task](#when-starting-any-task)** - Read this first
- **[Comprehensive Analysis](#comprehensive-analysis-checklist)** - For audits, reviews
- **[Parallel Task Execution](#parallel-task-decomposition-patterns)** - For speed
- **[Code Changes](#code-change-workflow)** - For implementing features/fixes
- **[Network Validation Work](#network-validation-patterns)** - For validation tasks
- **[Common Issues & Fixes](#common-issues-reference)** - Lessons learned
- **[Quality Checklist](#pre-commit-quality-checklist-summary)** - Before committing

---

## When Starting Any Task

### Step 1: Understand the Request
- Read the user's message completely
- Identify what's actually being asked (not assumptions)
- Ask clarifying questions if ambiguous

### Step 2: Choose Your Approach

**If the task is simple** (single file, clear scope):
- Just do it - no overthinking
- Run tests, verify, commit

**If the task is medium** (multiple files, some analysis needed):
- Create a todo list with 3-5 items
- Break it down into discrete steps
- Execute sequentially, marking each complete

**If the task is complex** (comprehensive, multiple phases):
- Create detailed todo list (5+ items)
- Identify opportunities for parallel work
- Use agents strategically (see [Parallel Task Execution](#parallel-task-decomposition-patterns))
- Track progress visually

### Step 3: Run Baseline Tests
```bash
# ALWAYS do this first
./tests/run-all-tests.sh
```
- Confirms current state is working
- Identifies if issues are pre-existing
- Provides baseline for comparison

### Step 4: Proceed with Work
- Follow appropriate section below based on task type
- Document search patterns you use (important for verification)
- Track what you check and what you find

### Step 5: Verify & Commit
- Run tests again (MUST pass 100%)
- Run syntax checks (provide required extra_vars)
- Commit with clear message
- Push to remote

---

## Comprehensive Analysis Checklist

**Use this when asked to audit, review, or analyze code/documentation**

### Phase 1: Inventory (What exists?)

**Action**: Create explicit list of ALL files in scope
```bash
# Example: Audit documentation files
glob: "docs/**/*.md"              # All doc files
glob: "ansible-content/**/*.yml"  # All YAML files
grep: "pattern"                   # Search for specific content
```

**Deliverable**:
- [ ] Explicit list of all files (don't estimate, don't sample)
- [ ] Total count stated (e.g., "28 documentation files")
- [ ] Search methods documented (what glob patterns, grep searches)

**Key Rule**: If you're not 100% sure you found EVERYTHING, keep searching. Use multiple methods.

### Phase 2: Analysis (What's in them?)

**Action**: Read/analyze each file in inventory

**Deliverable**:
- [ ] Purpose of each file documented
- [ ] Relationships between files noted
- [ ] Issues, stale content, dead links identified
- [ ] Organized by category

### Phase 3: Cross-Verification (Is anything missing?)

**Action**: Verify findings with MULTIPLE search methods

**Key Questions**:
- Are there files that SHOULD exist but don't?
- Are there dead links pointing to non-existent files?
- Is there duplicate/redundant content?
- Are findings complete, not a sample?

**Deliverable**:
- [ ] Used multiple search methods (grep, ripgrep, manual review)
- [ ] Verified completeness (not sampling)
- [ ] Cross-verified findings

### Phase 4: Documentation (What do you recommend?)

**Action**: Report findings with search patterns

**Deliverable**:
- [ ] Document ALL search patterns used (exact commands)
- [ ] List complete inventory with purposes
- [ ] Categorize issues (by severity, type, location)
- [ ] Provide specific recommendations (not vague suggestions)
- [ ] State coverage: "100% of X files analyzed"

**Example Good Report**:
```
Comprehensive Documentation Audit Results

Files Analyzed: 28 total documentation files
Search Methods Used:
  - glob "docs/**/*.md" → Found 28 files
  - grep "nonexistent" → Found 0 matches
  - Manual link verification → Found 3 dead links

Issues Found (Severity):
  HIGH: 3 dead links in docs/README.md (lines 185, 191, 204)
  MEDIUM: 2 duplicate files (baseline-comparison-*.md)
  LOW: 5 files with outdated dates

Recommendations:
  1. Remove dead links from docs/README.md
  2. Consolidate duplicate baseline-comparison files
  3. Update dates in archived analysis files

Coverage: 100% of 28 documentation files analyzed
```

---

## Parallel Task Decomposition Patterns

**Use when you want to work 3x faster**

### Pattern 1: Documentation Audit (Like Phase 2 of Recent Work)

**Traditional** (Sequential):
1. Scan all files → find all doc files → ~10 min
2. Read and analyze → ~20 min
3. Verify links → ~10 min
4. Create report → ~5 min
**Total: ~45 minutes**

**Optimized** (Parallel):
```
You: Call 3 agents in parallel
├─ Agent 1 (Explore): Scan all doc files, create inventory
│  └─ Delivers: Complete list of 28 files
│
├─ Agent 2 (general-purpose): Read and analyze files for accuracy
│  └─ Delivers: Purpose of each file, issues found
│
└─ Agent 3 (Explore): Verify links, check for dead references
   └─ Delivers: List of dead links, missing files

You: Merge results into single comprehensive report
```
**Total: ~15 minutes (1/3 original time)**

### Pattern 2: Code Quality Review (Multiple aspects)

**Parallel Approach**:
```
Agent 1: Syntax validation (yaml, ansible-lint)
Agent 2: Test execution and failure analysis
Agent 3: Search for specific code patterns across codebase
Agent 4: Documentation accuracy verification
```

**When to use**: Medium to large code changes affecting multiple areas

### Pattern 3: Comprehensive Refactoring

**Parallel Approach**:
```
Agent 1: Scan codebase, find all instances of pattern
Agent 2: Understand current implementation (architecture analysis)
Agent 3: Prepare test verification plan
You: Implement changes
Agent 4: Verify fixes across codebase (multiple search methods)
```

---

## Code Change Workflow

### For Small Changes (1-2 files)

1. **Read the file** (understand context)
2. **Make changes** (apply fix/feature)
3. **Run tests**: `./tests/run-all-tests.sh`
4. **Syntax check** (with required extra_vars)
5. **Commit** with clear message
6. **Push** to remote

### For Medium Changes (3-10 files)

1. **Create todo list** (3-5 items)
2. **Identify all affected files** (search comprehensively)
3. **Baseline tests** (verify current state)
4. **For each file**:
   - Read file
   - Understand patterns used elsewhere
   - Make consistent changes
   - Mark todo complete
5. **Comprehensive verification**:
   - Syntax check ALL modified files
   - Linting check
   - Run full test suite
   - Manual review for consistency
6. **Commit** each logical grouping
7. **Push** to remote

### For Large/Complex Changes

1. **Understand current state** (Plan agent or deep analysis)
2. **Create detailed todo list** (breakdown into phases)
3. **Document your search strategy** (how will you find all instances?)
4. **Phase-by-phase execution**:
   - Phase 1: Analysis & planning
   - Phase 2: Implementation
   - Phase 3: Verification across codebase
   - Phase 4: Testing
5. **Consider parallel work** (some phases can be parallel)
6. **Multiple commits** (one per logical change)
7. **Push** to remote

---

## Network Validation Patterns

**Use when working on network validation tasks**

### Standard Task Structure (All validation tasks use this)

```yaml
# 1. INITIALIZE STATUS (once, at file start)
- name: Initialize
  set_fact:
    comparison_status: NOT_RUN

# 2. MAIN VALIDATION BLOCK
- name: Main Validation
  block:
    # Collect data
    - name: Gather facts
      # ...

    # DATA-TYPE-SPECIFIC BLOCKS (repeat for each data type)
    - name: Validate ARP Data
      block:
        - name: Normalize ARP (remove time-sensitive fields)
          # ...

        - name: Compare normalized ARP data
          # Use difference() filter for delta

        - name: Report ARP comparison results
          # Report INSIDE the block

    - name: Validate BGP Data
      block:
        # Same pattern: normalize, compare, report inside block
        # ...

# 3. SET FINAL STATUS (once, at file end)
- name: Set comparison status
  set_fact:
    comparison_status: "{{ 'PASS' if all_passed else 'FAIL' }}"
```

### Key Principles

**Empty Data**:
- Normalization of empty data returns empty data
- DON'T create complex conditionals for this
- Just let it work naturally

**Block Organization**:
- Group: normalization + comparison + reporting together
- Report results INSIDE the block (not after)
- Keep related concerns together

**Status Management**:
- Initialize ONCE at file start: `NOT_RUN`
- Set final status ONCE at file end: `PASS` or `FAIL`
- Never set status multiple times in middle

**Data Types**:
- **Need normalization** (check `defaults/main.yml` for excluded fields):
  - BGP neighbors, BGP VRF, BGP summary
  - ARP operational, MAC operational
  - Routing (RIB/FIB), BFD sessions
  - PIM neighbors, PIM interface, IGMP groups

- **Raw comparison** (no normalization):
  - Network resources (complete tree)
  - Any data without excluded fields defined

### Reference
See `docs/internal/network-validation-data-types.md` for complete patterns

---

## Common Issues Reference

### Issue 1: Empty Data Handling
**Problem**: Creating complex conditional logic for empty data cases
**Solution**: Don't. Empty data naturally returns empty difference()
**Example**:
```yaml
# WRONG - unnecessary complexity
- when: arp_data is defined and arp_data | length > 0
  set_fact:
    normalized: "{{ arp_data | ... }}"

# RIGHT - just normalize, let empty pass through
- set_fact:
    normalized: "{{ arp_data | ... }}"
```

### Issue 2: Reporting Outside Blocks
**Problem**: Reporting tasks separated from validation blocks
**Solution**: Move reporting inside the data-type blocks
```yaml
# WRONG
- name: Validate
  block:
    - normalize data
    - compare data

- name: Report  # Separated

# RIGHT
- name: Validate ARP
  block:
    - normalize
    - compare
    - report  # Inside block
```

### Issue 3: Status Set Multiple Times
**Problem**: Status initialized, conditionally set, then set again
**Solution**: Initialize once, set once
```yaml
# WRONG
- set_fact:
    status: NOT_RUN

# ... some logic ...

- when: condition1
  set_fact:
    status: PASS

- when: condition2
  set_fact:
    status: FAIL

- when: not condition1 and not condition2
  set_fact:
    status: NOT_RUN  # Set again - wrong

# RIGHT
- set_fact:
    status: NOT_RUN  # Once, at start

# ... all validation logic ...

- set_fact:
    status: "{{ 'PASS' if all_passed else 'FAIL' }}"  # Once, at end
```

### Issue 4: Inconsistency Between Similar Tasks
**Problem**: One task has feature condition, others don't
**Solution**: Check ALL similar tasks, make them consistent
**Approach**:
1. Find all similar tasks: `grep -r "validation.yml"`
2. Compare them side-by-side
3. Make changes consistently across all
4. Test to verify consistency

### Issue 5: Incomplete Analysis
**Problem**: Claim comprehensive analysis but miss some items
**Solution**: Use multiple search methods, document what you checked
**How**:
1. List all search methods you used (specific commands)
2. State total count of files found
3. Cross-verify with different search tools
4. Explicitly state: "100% of X files analyzed"

---

## Pre-Commit Quality Checklist (Summary)

**Run this BEFORE every commit**

### 1. Tests MUST Pass
```bash
./tests/run-all-tests.sh
# Expected: ✅ Passed: 22, Failed: 0
```

### 2. Syntax Checks MUST Pass
```bash
# Main workflow
ansible-playbook --syntax-check ansible-content/playbooks/main-upgrade-workflow.yml \
  --extra-vars="target_hosts=localhost target_firmware=test.bin maintenance_window=true max_concurrent=1"

# Other playbooks
ansible-playbook --syntax-check ansible-content/playbooks/health-check.yml \
  --extra-vars="target_hosts=localhost"
ansible-playbook --syntax-check ansible-content/playbooks/config-backup.yml
# ... all playbooks
```

### 3. Linting MUST Pass
```bash
ansible-lint ansible-content/ --offline --parseable-severity
yamllint ansible-content/
# Expected: 0 errors, 0 warnings
```

### 4. Changes Are Consistent
- [ ] Found ALL instances of what you changed (not just obvious ones)
- [ ] Applied changes consistently everywhere
- [ ] Used multiple search methods to verify completeness
- [ ] Tested all changed code paths

### 5. Documentation Updated
- [ ] All documentation matches code changes
- [ ] No broken links
- [ ] No stale content references
- [ ] Internal links point to correct locations

### 6. Tests Updated
- [ ] Test files updated to match code changes
- [ ] New tests added for new functionality
- [ ] All tests pass with changes
- [ ] No test coverage reduced

---

## Quick Reference: Search Patterns

**When you need to find things**

### Find all files of a type
```bash
glob: "docs/**/*.md"              # All markdown files
glob: "ansible-content/**/*.yml"  # All YAML files
glob: "**/defaults/main.yml"      # All defaults files
glob: "**/*validation.yml"        # All validation tasks
```

### Search content
```bash
grep: "pattern"                   # Simple string search
grep: "when: bgp_enabled"         # Find conditionals
grep: "msg: |"                    # Find folded scalars in msg (don't use!)
grep: "| default()"               # Find problematic filters
```

### Cross-verify findings
```bash
# Use multiple tools:
1. glob for file discovery
2. grep for content verification
3. ripgrep (rg) for comprehensive search
4. Manual review of key sections
```

---

## Task Type Quick Reference

**When starting a task, identify the type and follow the pattern**

| Task Type | Scope | Approach | Time |
|-----------|-------|----------|------|
| **Single file edit** | 1 file | Just do it → test → commit | 5-10 min |
| **Multi-file fix** | 3-10 files | Search comprehensively → fix all → test → commit | 15-30 min |
| **Documentation audit** | 28+ files | 4-phase methodology or parallel (3 agents) | 45 min or 15 min parallel |
| **Code refactoring** | 10+ files, pattern change | Understand pattern → fix all → comprehensive test | 30-60 min |
| **Architecture change** | Multiple components | Plan first → implement phase-by-phase → comprehensive test | 2+ hours |

---

## When You're Unsure

### "Am I done with the analysis?"
- [ ] Did you use multiple search methods?
- [ ] Did you state a total count of files checked?
- [ ] Did you document search patterns you used?
- [ ] Could there be more instances you missed?

**If ANY are unchecked, keep searching**

### "Is this change consistent?"
- [ ] Found all similar code/patterns?
- [ ] Applied change everywhere consistently?
- [ ] Checked ALL roles, all tasks, all plays?
- [ ] Verified no exceptions/edge cases?

**If ANY are unchecked, search more thoroughly**

### "Are tests really passing?"
- [ ] Ran full test suite (not just subset)?
- [ ] Checked exit code is 0?
- [ ] Verified "Passed: 22" exactly?
- [ ] No failing tests hidden in output?

**Always show exact test output**

---

## Example Workflows

### Workflow 1: Simple Bug Fix
```
1. Understand issue
2. Find all instances: grep across codebase
3. Fix in one place
4. Verify fix is applied everywhere (shouldn't be multiple instances)
5. Run tests
6. Commit: "fix: [specific issue]"
7. Push
```

### Workflow 2: Documentation Audit
```
1. Inventory phase: Find all doc files (glob "docs/**/*.md")
2. Analysis phase: Read and categorize each file
3. Cross-verification: Use multiple search methods
   - grep for specific issues
   - Check links exist
   - Verify content accuracy
4. Documentation: Report findings with search patterns used
5. Commit: "docs: audit results and recommendations"
```

### Workflow 3: Network Validation Task
```
1. Read existing validation tasks to understand pattern
2. Create new task file following standardized structure
3. Initialize status once at start
4. Create main block
5. Create data-type-specific blocks (normalize, compare, report inside)
6. Set status once at end
7. Tests
8. Commit: "feat: add [data type] validation"
```

### Workflow 4: Refactoring (Multiple Files)
```
1. Understand current implementation (all instances)
2. Plan changes (document search strategy)
3. Identify all affected files:
   - Role task files: X files
   - Integration test updates: Y files
   - Unit test updates: Z files
4. Make changes systematically
5. Verify consistency:
   - Re-search for pattern
   - Use different search methods
   - Spot-check changed files
6. Comprehensive test run
7. Commit by logical phase
8. Push
```

---

## Key Reminders

🔴 **CRITICAL - Never Compromise**:
- All tests MUST pass (100%, not 95%)
- No syntax errors allowed
- No incomplete analyses
- Documentation must be accurate

🟠 **MANDATORY**:
- Document search patterns you use
- Verify completeness (use multiple methods)
- Consistency across codebase
- Tests updated with code changes

🟡 **IMPORTANT**:
- Think before implementing
- Use comprehensive search
- Communicate what you found
- Show your work

🟢 **BEST PRACTICE**:
- Create todo lists for complex tasks
- Use parallel execution for speed
- Reference existing patterns
- Learn from recent work

---

## Navigation Back to Main CLAUDE.md

For detailed standards and requirements, see:
- `CLAUDE.md` - Complete project guidance
- `docs/internal/network-validation-data-types.md` - Validation reference
- `CONVERSATION_SUMMARY.md` - Historical lessons learned
- `CLAUDE_IMPROVEMENT_ANALYSIS.md` - Future enhancement ideas

---

**This document is YOUR working guide. Reference it when starting tasks to ensure consistency, quality, and efficiency.**

