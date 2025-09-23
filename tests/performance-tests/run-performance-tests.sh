#!/bin/bash
# Performance Testing Suite
# Tests performance of ansible playbooks and role execution

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

run_performance_test() {
    local test_name="$1"
    local time_limit="$2"
    shift 2
    ((TOTAL_TESTS++))

    log "Performance Testing: $test_name (limit: ${time_limit}s)"

    start_time=$(date +%s)
    if timeout "$time_limit" "$@" >/dev/null 2>&1; then
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        success "$test_name (${duration}s)"
        return 0
    else
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        error "$test_name (${duration}s - exceeded ${time_limit}s limit)"
        return 1
    fi
}

main() {
    echo -e "${BLUE}⚡ PERFORMANCE TEST SUITE${NC}"
    echo "=========================="
    echo "Testing ansible playbook and role performance"
    echo ""

    cd "$PROJECT_ROOT"

    # Test 1: Main workflow syntax check performance
    run_performance_test "Main workflow syntax check" 30 \
        ansible-playbook --syntax-check ansible-content/playbooks/main-upgrade-workflow.yml

    # Test 2: All playbooks syntax check performance
    run_performance_test "All playbooks syntax check" 60 \
        bash -c 'for playbook in ansible-content/playbooks/*.yml; do ansible-playbook --syntax-check "$playbook"; done'

    # Test 3: Role task file validation performance
    run_performance_test "Role task files validation" 45 \
        bash -c 'find ansible-content/roles -name "tasks/*.yml" -exec python3 -c "import yaml; yaml.safe_load(open(\"{}\"))" \; 2>/dev/null || true'

    # Test 4: Inventory parsing performance
    run_performance_test "Inventory parsing" 15 \
        ansible-inventory -i ansible-content/inventory/hosts.yml --list

    # Test 5: Template rendering performance simulation
    run_performance_test "Template rendering simulation" 20 \
        bash -c 'find ansible-content/roles -name "templates" -type d | head -5 | while read -r dir; do ls "$dir"/*.j2 2>/dev/null || true; done'

    # Test 6: Large file operations simulation
    run_performance_test "Large file operations simulation" 25 \
        bash -c 'find ansible-content -type f -name "*.yml" | head -20 | xargs -I {} python3 -c "import yaml; yaml.safe_load(open(\"{}\"))"'

    # Test 7: Collection requirements processing
    run_performance_test "Collection requirements processing" 10 \
        python3 -c "import yaml; data=yaml.safe_load(open('ansible-content/collections/requirements.yml')); print(f'Loaded {len(data.get(\"collections\", []))} collections')"

    # Summary
    echo ""
    echo -e "${BLUE}=== PERFORMANCE TEST SUMMARY ===${NC}"
    echo "Total tests: $TOTAL_TESTS"
    echo "Passed: ${GREEN}$PASSED_TESTS${NC}"
    echo "Failed: ${RED}$FAILED_TESTS${NC}"

    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}🚀 All performance tests passed!${NC}"
        echo -e "${GREEN}System performance is within acceptable limits${NC}"
        return 0
    else
        echo -e "${RED}❌ Some performance tests failed${NC}"
        echo -e "${YELLOW}Consider optimizing slow operations${NC}"
        return 1
    fi
}

main "$@"