#!/bin/bash
# Network Device Upgrade System - Test Runner
# Executes all test suites and generates comprehensive report

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ANSIBLE_CONTENT_DIR="$PROJECT_ROOT/ansible-content"
TEST_RESULTS_DIR="$SCRIPT_DIR/results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create results directory
mkdir -p "$TEST_RESULTS_DIR"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Network Device Upgrade System Tests${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Test run started: $(date)"
echo -e "Project root: $PROJECT_ROOT"
echo ""

# Function to run a test suite
run_test_suite() {
    local test_name="$1"
    local test_file="$2"
    local result_file="$TEST_RESULTS_DIR/${test_name}_${TIMESTAMP}.log"
    
    echo -e "${YELLOW}Running $test_name tests...${NC}"
    
    if cd "$ANSIBLE_CONTENT_DIR" && ansible-playbook "$test_file" > "$result_file" 2>&1; then
        echo -e "${GREEN}✓ $test_name tests PASSED${NC}"
        return 0
    else
        echo -e "${RED}✗ $test_name tests FAILED${NC}"
        echo -e "${RED}  Last 30 lines of output:${NC}"
        echo -e "${RED}  ========================${NC}"
        tail -30 "$result_file" | sed 's/^/  /'
        echo -e "${RED}  ========================${NC}"
        echo -e "${RED}  Full log: $result_file${NC}"
        return 1
    fi
}

# Function to run syntax checks
run_syntax_checks() {
    echo -e "${YELLOW}Running Ansible syntax checks...${NC}"
    local failed=0
    
    # Check all playbooks with required runtime variables
    for playbook in "$ANSIBLE_CONTENT_DIR/playbooks"/*.yml; do
        if [ -f "$playbook" ]; then
            if ansible-playbook --syntax-check "$playbook" \
                -e "target_hosts=localhost" \
                -e "upgrade_phase=validation" \
                -e "target_firmware=test.bin" \
                -e "max_concurrent=1" \
                -e "platform_firmware=test.bin" \
                >/dev/null 2>&1; then
                echo -e "${GREEN}✓ $(basename "$playbook")${NC}"
            else
                echo -e "${RED}✗ $(basename "$playbook")${NC}"
                failed=$((failed + 1))
            fi
        fi
    done
    
    # Check role tasks using YAML validation (not ansible syntax check)
    find "$ANSIBLE_CONTENT_DIR/roles" -name "*.yml" -path "*/tasks/*" | while read -r task_file; do
        if python3 -c "import yaml; yaml.safe_load(open('$task_file'))" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ $(basename "$(dirname "$(dirname "$task_file")")/")/$(basename "$task_file")${NC}"
        else
            echo -e "${RED}✗ $(basename "$(dirname "$(dirname "$task_file")")/")/$(basename "$task_file")${NC}"
            failed=$((failed + 1))
        fi
    done
    
    return $failed
}

# Function to check dependencies
check_dependencies() {
    echo -e "${YELLOW}Checking dependencies...${NC}"
    
    local missing=0
    
    # Check for ansible
    if command -v ansible-playbook >/dev/null 2>&1; then
        echo -e "${GREEN}✓ ansible-playbook found${NC}"
    else
        echo -e "${RED}✗ ansible-playbook not found${NC}"
        missing=$((missing + 1))
    fi
    
    # Check for ansible-lint
    if command -v ansible-lint >/dev/null 2>&1; then
        echo -e "${GREEN}✓ ansible-lint found${NC}"
    else
        echo -e "${YELLOW}! ansible-lint not found (optional)${NC}"
    fi
    
    # Check for yamllint
    if command -v yamllint >/dev/null 2>&1; then
        echo -e "${GREEN}✓ yamllint found${NC}"
    else
        echo -e "${YELLOW}! yamllint not found (optional)${NC}"
    fi
    
    # Check Python for YAML validation
    if python3 -c "import yaml" 2>/dev/null; then
        echo -e "${GREEN}✓ Python YAML module found${NC}"
    else
        echo -e "${RED}✗ Python YAML module not found${NC}"
        missing=$((missing + 1))
    fi
    
    if [ $missing -gt 0 ]; then
        echo -e "${RED}Missing $missing required dependencies${NC}"
        return 1
    fi
    
    return 0
}

# Function to generate final report
generate_report() {
    local total_tests="$1"
    local passed_tests="$2"
    local failed_tests="$3"
    
    local report_file="$TEST_RESULTS_DIR/test_report_${TIMESTAMP}.txt"
    
    cat > "$report_file" << EOF
Network Device Upgrade System - Test Report
==========================================
Test run: $(date)
Project root: $PROJECT_ROOT

Summary:
- Total test suites: $total_tests
- Passed: $passed_tests
- Failed: $failed_tests
- Success rate: $(( passed_tests * 100 / total_tests ))%

Test Results:
EOF
    
    # Append individual test results
    for result_file in "$TEST_RESULTS_DIR"/*_${TIMESTAMP}.log; do
        if [ -f "$result_file" ]; then
            echo "" >> "$report_file"
            echo "=== $(basename "$result_file" .log) ===" >> "$report_file"
            tail -20 "$result_file" >> "$report_file"
        fi
    done
    
    echo -e "${BLUE}Full report saved to: $report_file${NC}"
}

# Main test execution
main() {
    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    
    # Check dependencies first
    if ! check_dependencies; then
        echo -e "${RED}Dependency check failed. Please install missing dependencies.${NC}"
        exit 1
    fi
    
    echo ""
    
    # Run syntax checks first
    echo -e "${BLUE}Phase 1: Syntax Validation${NC}"
    if run_syntax_checks; then
        echo -e "${GREEN}✓ Syntax checks completed${NC}"
    else
        echo -e "${RED}✗ Syntax check failures detected${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}Phase 2: Test Suites${NC}"
    
    # Ansible-based test suites to run
    test_suites=(
        "Syntax_Tests:../tests/ansible-tests/syntax-tests.yml"
        "Workflow_Integration:../tests/integration-tests/workflow-tests.yml"
        "Multi_Platform_Integration:../tests/integration-tests/multi-platform-integration-tests.yml"
        "Secure_Transfer_Integration:../tests/integration-tests/secure-transfer-integration-tests.yml"
        "Network_Error_Simulation:../tests/error-scenarios/network_error_tests.yml"
        "Device_Error_Simulation:../tests/error-scenarios/device_error_tests.yml"
        "Concurrent_Upgrade_Errors:../tests/error-scenarios/concurrent_upgrade_tests.yml"
        "Edge_Case_Error_Tests:../tests/error-scenarios/edge_case_tests.yml"
        "Production_Readiness_UAT:../tests/uat-tests/production_readiness_suite.yml"
        "Network_Validation:../tests/validation-tests/network-validation-tests.yml"
        "Comprehensive_Validation:../tests/validation-tests/comprehensive-validation-tests.yml"
        "Cisco_NXOS_Tests:../tests/vendor-tests/cisco-nxos-tests.yml"
        "Opengear_Multi_Arch_Tests:../tests/vendor-tests/opengear-tests.yml"
    )

    # Shell-based test suites to run
    shell_test_suites=(
        "YAML_Validation:tests/validation-scripts/run-yaml-tests.sh"
        "Performance_Tests:tests/performance-tests/run-performance-tests.sh"
        "Error_Simulation:tests/error-scenarios/run-error-simulation-tests.sh"
        "Container_Tests:tests/container-tests/run-all-container-tests.sh"
    )

    # Playbook-specific test suites
    playbook_test_suites=(
        "Emergency_Rollback:tests/playbook-tests/emergency-rollback/run-emergency-rollback-tests.sh"
        "Network_Validation:tests/playbook-tests/network-validation/run-network-validation-tests.sh"
        "Config_Backup:tests/playbook-tests/config-backup/run-config-backup-tests.sh"
        "Compliance_Audit:tests/playbook-tests/compliance-audit/run-compliance-audit-tests.sh"
        "Image_Loading:tests/playbook-tests/image-loading/run-image-loading-tests.sh"
    )
    
    # Run each Ansible test suite
    for test_suite in "${test_suites[@]}"; do
        test_name="${test_suite%%:*}"
        test_file="${test_suite#*:}"
        total_tests=$((total_tests + 1))

        if run_test_suite "$test_name" "$test_file"; then
            passed_tests=$((passed_tests + 1))
        else
            failed_tests=$((failed_tests + 1))
        fi
        echo ""
    done

    echo ""
    echo -e "${BLUE}Phase 3: Playbook Test Suites${NC}"

    # Run each playbook test suite
    for test_suite in "${playbook_test_suites[@]}"; do
        test_name="${test_suite%%:*}"
        test_script="${test_suite#*:}"
        total_tests=$((total_tests + 1))

        echo -e "${YELLOW}Running $test_name tests...${NC}"

        if cd "$PROJECT_ROOT" && chmod +x "$test_script" && "$test_script" > "$TEST_RESULTS_DIR/${test_name}_${TIMESTAMP}.log" 2>&1; then
            echo -e "${GREEN}✓ $test_name tests PASSED${NC}"
            passed_tests=$((passed_tests + 1))
        else
            echo -e "${RED}✗ $test_name tests FAILED${NC}"
            echo -e "${RED}  Last 30 lines of output:${NC}"
            echo -e "${RED}  ========================${NC}"
            tail -30 "$TEST_RESULTS_DIR/${test_name}_${TIMESTAMP}.log" | sed 's/^/  /'
            echo -e "${RED}  ========================${NC}"
            failed_tests=$((failed_tests + 1))
        fi
        echo ""
    done

    echo ""
    echo -e "${BLUE}Phase 4: Shell Test Suites${NC}"

    # Run each shell test suite
    for test_suite in "${shell_test_suites[@]}"; do
        test_name="${test_suite%%:*}"
        test_script="${test_suite#*:}"
        total_tests=$((total_tests + 1))

        echo -e "${YELLOW}Running $test_name tests...${NC}"

        if cd "$PROJECT_ROOT" && chmod +x "$test_script" && "$test_script" > "$TEST_RESULTS_DIR/${test_name}_${TIMESTAMP}.log" 2>&1; then
            echo -e "${GREEN}✓ $test_name tests PASSED${NC}"
            passed_tests=$((passed_tests + 1))
        else
            echo -e "${RED}✗ $test_name tests FAILED${NC}"
            echo -e "${RED}  Last 30 lines of output:${NC}"
            echo -e "${RED}  ========================${NC}"
            tail -30 "$TEST_RESULTS_DIR/${test_name}_${TIMESTAMP}.log" | sed 's/^/  /'
            echo -e "${RED}  ========================${NC}"
            failed_tests=$((failed_tests + 1))
        fi
        echo ""
    done
    
    # Generate final report
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Test Summary${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "Total test suites: $total_tests"
    echo -e "Passed: ${GREEN}$passed_tests${NC}"
    echo -e "Failed: ${RED}$failed_tests${NC}"
    
    if [ $failed_tests -eq 0 ]; then
        echo -e "${GREEN}🎉 All tests passed!${NC}"
    else
        echo -e "${RED}❌ $failed_tests test suite(s) failed${NC}"
    fi
    
    generate_report "$total_tests" "$passed_tests" "$failed_tests"
    
    # Exit with error code if any tests failed
    [ $failed_tests -eq 0 ]
}

# Run main function
main "$@"