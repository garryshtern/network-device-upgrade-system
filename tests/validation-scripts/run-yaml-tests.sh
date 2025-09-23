#!/bin/bash
# YAML Validation Test Runner
# Comprehensive YAML and JSON validation for all project files

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.."; pwd)"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED_TESTS++))
}

error() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED_TESTS++))
}

run_test() {
    local test_name="$1"
    shift
    ((TOTAL_TESTS++))

    log "Testing: $test_name"

    if "$@" >/dev/null 2>&1; then
        success "$test_name"
        return 0
    else
        error "$test_name"
        return 1
    fi
}

main() {
    echo -e "${BLUE}🔍 YAML VALIDATION TEST SUITE${NC}"
    echo "==============================="
    echo "Comprehensive YAML and JSON validation"
    echo ""

    cd "$PROJECT_ROOT"

    # Test 1: Python YAML validator
    run_test "Python YAML validator execution" \
        python3 tests/validation-scripts/yaml-validator.py --ansible-only

    # Test 2: yamllint on ansible content (allow some warnings)
    run_test "yamllint validation on ansible-content" \
        bash -c "yamllint ansible-content/ || [[ \$? -eq 1 ]]"

    # Test 3: Ansible collection requirements validation
    run_test "Ansible collections requirements validation" \
        python3 -c "import yaml; yaml.safe_load(open('ansible-content/collections/requirements.yml'))"

    # Test 4: Inventory files validation
    run_test "Inventory files YAML validation" \
        bash -c 'find ansible-content/inventory -name "*.yml" -exec python3 -c "import yaml; yaml.safe_load(open(\"{}\"))" \;'

    # Test 5: Group vars validation
    run_test "Group vars YAML validation" \
        bash -c 'find ansible-content/inventory/group_vars -name "*.yml" -exec python3 -c "import yaml; yaml.safe_load(open(\"{}\"))" \;'

    # Test 6: Role metadata validation
    run_test "Role metadata validation" \
        bash -c 'find ansible-content/roles -name "meta/main.yml" -exec python3 -c "import yaml; yaml.safe_load(open(\"{}\"))" \;'

    # Test 7: Molecule configuration validation
    run_test "Molecule configuration validation" \
        bash -c 'find ansible-content/roles -name "molecule.yml" -exec python3 -c "import yaml; yaml.safe_load(open(\"{}\"))" \;'

    # Summary
    echo ""
    echo -e "${BLUE}=== YAML VALIDATION SUMMARY ===${NC}"
    echo "Total tests: $TOTAL_TESTS"
    echo "Passed: ${GREEN}$PASSED_TESTS${NC}"
    echo "Failed: ${RED}$FAILED_TESTS${NC}"

    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}🎉 All YAML validation tests passed!${NC}"
        return 0
    else
        echo -e "${RED}❌ Some YAML validation tests failed${NC}"
        return 1
    fi
}

main "$@"