name: review-ansible-tests
description: Review Ansible playbooks and roles to ensure comprehensive test coverage
version: "1.0.0"

input:
  - name: project_path
    description: Path to the Ansible project (defaults to current directory)
    required: false
    default: "."

output:
  - type: analysis
    description: Detailed test coverage analysis report
  - type: recommendations
    description: Actionable recommendations for improving test coverage

prompt: |
  I need you to analyze the Ansible project structure and ensure comprehensive test coverage. Please:

  1. **Scan Project Structure:**
     - Find all playbooks (*.yml files that are main entry points)
     - Identify all roles in roles/ directories
     - Locate existing test files and directories

  2. **Test Coverage Analysis:**
     - Check each playbook for corresponding tests
     - Verify each role has appropriate tests (molecule, unit tests, etc.)
     - Identify any untested components

  3. **Test Framework Assessment:**
     - Evaluate existing Molecule configurations
     - Check for pytest-ansible or other testing frameworks
     - Review test scenarios and coverage

  4. **Generate Report:**
     - List all playbooks and their test status
     - List all roles and their test status  
     - Identify missing tests and gaps
     - Suggest testing strategies for untested components

  5. **Recommendations:**
     - Prioritize which components need tests most urgently
     - Suggest appropriate test types (molecule, integration, unit)
     - Provide example test structures for missing components
     - Recommend CI/CD integration approaches

  Please start by examining the project at: {{project_path}}

  Focus on:
  - Molecule test scenarios
  - Test playbooks in tests/ directories
  - Integration tests
  - Inventory and variable testing
  - Idempotency tests
  - Multi-platform testing scenarios

  Provide a clear action plan for achieving comprehensive test coverage.
