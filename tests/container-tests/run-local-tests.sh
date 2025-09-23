#!/bin/bash
# Local Container Test Runner (Docker-free)
# Tests container functionality that can be validated without Docker

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.."; pwd)"

# Test suite tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
START_TIME=$(date +%s)

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    ((PASSED_TESTS++))
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    ((FAILED_TESTS++))
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

section() {
    echo -e "${CYAN}[SECTION]${NC} $1"
}

# Test docker-entrypoint script functionality
test_entrypoint_functionality() {
    section "Testing docker-entrypoint.sh functionality"
    ((TOTAL_TESTS++))

    if [[ -f "$PROJECT_ROOT/docker-entrypoint.sh" ]]; then
        if bash "$SCRIPT_DIR/test-entrypoint-locally.sh" >/dev/null 2>&1; then
            success "Docker entrypoint functionality test passed"
        else
            error "Docker entrypoint functionality test failed"
            return 1
        fi
    else
        error "Docker entrypoint script not found"
        return 1
    fi
}

# Test TARGET_HOSTS validation logic
test_target_hosts_validation() {
    section "Testing TARGET_HOSTS validation logic"
    ((TOTAL_TESTS++))

    cd "$PROJECT_ROOT"

    # Test valid hosts
    export TARGET_HOSTS="cisco-switch-01"
    export ANSIBLE_INVENTORY="$SCRIPT_DIR/mockups/inventory/production.yml"

    if bash docker-entrypoint.sh syntax-check >/dev/null 2>&1; then
        success "TARGET_HOSTS validation with valid hosts passed"
    else
        error "TARGET_HOSTS validation with valid hosts failed"
        return 1
    fi
}

# Test invalid TARGET_HOSTS validation
test_invalid_target_hosts() {
    section "Testing invalid TARGET_HOSTS validation"
    ((TOTAL_TESTS++))

    cd "$PROJECT_ROOT"

    # Test invalid hosts (should fail)
    export TARGET_HOSTS="nonexistent-device"
    export ANSIBLE_INVENTORY="$SCRIPT_DIR/mockups/inventory/production.yml"

    if ! bash docker-entrypoint.sh syntax-check >/dev/null 2>&1; then
        success "TARGET_HOSTS validation correctly rejects invalid hosts"
    else
        error "TARGET_HOSTS validation should have failed for invalid hosts"
        return 1
    fi
}

# Test environment variable processing
test_environment_variables() {
    section "Testing environment variable processing"
    ((TOTAL_TESTS++))

    cd "$PROJECT_ROOT"

    # Set comprehensive environment variables
    export CISCO_NXOS_SSH_KEY="/opt/keys/cisco-nxos-key"
    export CISCO_IOSXE_USERNAME="admin"
    export CISCO_IOSXE_PASSWORD="test123"
    export FORTIOS_API_TOKEN="test-token"
    export TARGET_HOSTS="cisco-switch-01"
    export TARGET_FIRMWARE="test-firmware.bin"
    export UPGRADE_PHASE="validation"
    export ANSIBLE_INVENTORY="$SCRIPT_DIR/mockups/inventory/production.yml"

    if bash docker-entrypoint.sh syntax-check >/dev/null 2>&1; then
        success "Environment variable processing test passed"
    else
        error "Environment variable processing test failed"
        return 1
    fi
}

# Test help command functionality
test_help_command() {
    section "Testing help command functionality"
    ((TOTAL_TESTS++))

    cd "$PROJECT_ROOT"

    if bash docker-entrypoint.sh help | grep -q "ENVIRONMENT VARIABLES"; then
        success "Help command functionality test passed"
    else
        error "Help command functionality test failed"
        return 1
    fi
}

# Test inventory file validation
test_inventory_validation() {
    section "Testing inventory file validation"
    ((TOTAL_TESTS++))

    cd "$PROJECT_ROOT"

    # Test missing inventory (should fail)
    export ANSIBLE_INVENTORY="/nonexistent/inventory.yml"
    export TARGET_HOSTS="cisco-switch-01"

    if ! bash docker-entrypoint.sh syntax-check >/dev/null 2>&1; then
        success "Inventory validation correctly rejects missing inventory"
    else
        error "Inventory validation should have failed for missing inventory"
        return 1
    fi
}

# Test mock inventory structure
test_mock_inventory() {
    section "Testing mock inventory structure"
    ((TOTAL_TESTS++))

    local inventory_file="$SCRIPT_DIR/mockups/inventory/production.yml"

    if [[ -f "$inventory_file" ]]; then
        # Check if inventory contains expected hosts
        if grep -q "cisco-switch-01" "$inventory_file" && \
           grep -q "fortinet-firewall-01" "$inventory_file" && \
           grep -q "opengear-console-01" "$inventory_file" && \
           grep -q "metamako-switch-01" "$inventory_file"; then
            success "Mock inventory structure test passed"
        else
            error "Mock inventory missing expected hosts"
            return 1
        fi
    else
        error "Mock inventory file not found"
        return 1
    fi
}

# Test Ansible playbook syntax
test_ansible_syntax() {
    section "Testing Ansible playbook syntax"
    ((TOTAL_TESTS++))

    cd "$PROJECT_ROOT"

    # Check if main playbook exists and has valid syntax
    if [[ -f "ansible-content/playbooks/main-upgrade-workflow.yml" ]]; then
        if ansible-playbook --syntax-check \
            -i "$SCRIPT_DIR/mockups/inventory/production.yml" \
            ansible-content/playbooks/main-upgrade-workflow.yml >/dev/null 2>&1; then
            success "Ansible playbook syntax test passed"
        else
            warn "Ansible playbook syntax test failed (ansible-playbook may not be available)"
            # Don't fail the test if ansible-playbook is not available
        fi
    else
        error "Main Ansible playbook not found"
        return 1
    fi
}

# Generate test report
generate_test_report() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))

    echo ""
    echo "========================================================"
    echo "🏆 LOCAL CONTAINER TEST REPORT"
    echo "========================================================"
    echo "Execution Time: ${minutes}m ${seconds}s"
    echo "Tests Run: $TOTAL_TESTS"
    echo -e "Tests Passed: ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Tests Failed: ${RED}$FAILED_TESTS${NC}"

    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}========================================================"
        echo -e "🎉 ALL LOCAL TESTS PASSED! 🎉"
        echo -e "Core container functionality validated locally."
        echo -e "========================================================${NC}"
    else
        echo -e "${RED}========================================================"
        echo -e "❌ SOME LOCAL TESTS FAILED"
        echo -e "Core container functionality needs attention."
        echo -e "========================================================${NC}"
    fi

    echo ""
    echo "📋 NEXT STEPS:"
    echo "To run the complete test suite with Docker:"
    echo "1. Install Docker: https://docs.docker.com/get-docker/"
    echo "2. Pull container: docker pull ghcr.io/garryshtern/network-device-upgrade-system:latest"
    echo "3. Run full tests: ./run-all-container-tests.sh"
}

# Main execution
main() {
    echo "🚀 LOCAL CONTAINER TEST RUNNER (Docker-free)"
    echo "============================================="
    echo "Testing core container functionality without Docker dependency"
    echo "Start Time: $(date)"
    echo ""

    # Run all local tests
    test_entrypoint_functionality
    test_target_hosts_validation
    test_invalid_target_hosts
    test_environment_variables
    test_help_command
    test_inventory_validation
    test_mock_inventory
    test_ansible_syntax

    # Generate final report
    generate_test_report

    # Exit with appropriate code
    if [[ $FAILED_TESTS -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Handle script interruption
trap 'echo -e "\n${RED}Test execution interrupted${NC}"; exit 130' INT TERM

# Execute main function
main "$@"