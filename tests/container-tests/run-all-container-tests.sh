#!/bin/bash
# Master Container Test Runner
# Executes all container tests in sequence with comprehensive reporting

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
CONTAINER_IMAGE="${CONTAINER_IMAGE:-ghcr.io/garryshtern/network-device-upgrade-system:latest}"

# Test suite tracking
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0
START_TIME=$(date +%s)

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

section() {
    echo -e "${CYAN}[SECTION]${NC} $1"
}

# Run individual test suite
run_test_suite() {
    local suite_name="$1"
    local test_script="$2"

    ((TOTAL_SUITES++))
    section "Running test suite: $suite_name"
    log "Script: $test_script"

    if [[ ! -f "$test_script" ]]; then
        error "Test script not found: $test_script"
        ((FAILED_SUITES++))
        return 1
    fi

    # Make script executable
    chmod +x "$test_script"

    # Run the test suite
    if bash "$test_script"; then
        success "Test suite '$suite_name' PASSED"
        ((PASSED_SUITES++))
        return 0
    else
        error "Test suite '$suite_name' FAILED"
        ((FAILED_SUITES++))
        return 1
    fi
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."

    # Check Docker availability
    if ! command -v docker &> /dev/null; then
        warn "Docker is not installed or not in PATH - Container tests skipped"
        warn "Container tests are optional for development environments"
        warn "Install Docker to run full container validation suite"
        exit 0  # Exit successfully since containers are optional
    fi

    # Check Docker daemon
    if ! docker info &> /dev/null; then
        error "Docker daemon is not running"
        exit 1
    fi

    # Check container image availability
    if docker images | grep -q "network-device-upgrade-system"; then
        success "Container image found locally"
    else
        log "Pulling container image: $CONTAINER_IMAGE"
        if docker pull "$CONTAINER_IMAGE"; then
            success "Container image pulled successfully"
        else
            error "Failed to pull container image: $CONTAINER_IMAGE"
            exit 1
        fi
    fi

    success "Prerequisites check completed"
}

# Setup test environment
setup_test_environment() {
    log "Setting up test environment..."

    # Ensure mockup directories exist
    mkdir -p "$SCRIPT_DIR/mockups/keys"
    mkdir -p "$SCRIPT_DIR/mockups/tokens"
    mkdir -p "$SCRIPT_DIR/mockups/firmware"

    # Set correct permissions
    chmod 600 "$SCRIPT_DIR/mockups/keys"/* 2>/dev/null || true

    success "Test environment setup completed"
}

# Generate test report
generate_test_report() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))

    echo ""
    echo "========================================================"
    echo "🏆 COMPREHENSIVE CONTAINER TEST REPORT"
    echo "========================================================"
    echo "Container Image: $CONTAINER_IMAGE"
    echo "Execution Time: ${minutes}m ${seconds}s"
    echo "Test Suites Run: $TOTAL_SUITES"
    echo -e "Suites Passed: ${GREEN}$PASSED_SUITES${NC}"
    echo -e "Suites Failed: ${RED}$FAILED_SUITES${NC}"

    if [[ $FAILED_SUITES -eq 0 ]]; then
        echo -e "${GREEN}========================================================"
        echo -e "🎉 ALL CONTAINER TEST SUITES PASSED! 🎉"
        echo -e "Container functionality is fully validated and ready."
        echo -e "========================================================${NC}"
    else
        echo -e "${RED}========================================================"
        echo -e "❌ SOME CONTAINER TEST SUITES FAILED"
        echo -e "Container functionality requires attention."
        echo -e "========================================================${NC}"
    fi

    # Create results directory and detailed test result file
    mkdir -p "$SCRIPT_DIR/results"
    local report_file="$SCRIPT_DIR/results/test-results-$(date +%Y%m%d-%H%M%S).log"
    {
        echo "Container Test Execution Report"
        echo "Generated: $(date)"
        echo "Container Image: $CONTAINER_IMAGE"
        echo "Total Duration: ${minutes}m ${seconds}s"
        echo "Total Suites: $TOTAL_SUITES"
        echo "Passed Suites: $PASSED_SUITES"
        echo "Failed Suites: $FAILED_SUITES"
        echo "Success Rate: $(( (PASSED_SUITES * 100) / TOTAL_SUITES ))%"
    } > "$report_file"

    log "Detailed test report saved to: $report_file"
}

# Main test execution
main() {
    echo "🚀 MASTER CONTAINER TEST SUITE RUNNER"
    echo "====================================="
    echo "Testing container functionality with comprehensive mock device scenarios"
    echo "Container Image: $CONTAINER_IMAGE"
    echo "Start Time: $(date)"
    echo ""

    # Setup
    check_prerequisites
    setup_test_environment

    echo ""
    section "Starting test suite execution..."
    echo ""

    # Run all test suites in logical order

    # 1. Basic entrypoint functionality (local tests)
    run_test_suite "Local Entrypoint Tests" "$SCRIPT_DIR/test-entrypoint-locally.sh"

    # 2. Environment variable processing
    run_test_suite "Environment Variable Tests" "$SCRIPT_DIR/test-container-env-vars.sh"

    # 3. Comprehensive container functionality
    run_test_suite "Comprehensive Functionality Tests" "$SCRIPT_DIR/test-comprehensive-container-functionality.sh"

    # 4. Mock device interactions
    run_test_suite "Mock Device Interaction Tests" "$SCRIPT_DIR/test-mock-device-interactions.sh"

    # 5. SSH key privilege drop mechanism
    run_test_suite "SSH Key Privilege Drop Tests" "$SCRIPT_DIR/test-ssh-key-privilege-drop.sh"

    # 6. Specific functionality validation (SSH keys, API tokens, firmware versions)
    run_test_suite "Specific Functionality Tests" "$SCRIPT_DIR/test-specific-functionality.sh"

    # Generate final report
    generate_test_report

    # Exit with appropriate code
    if [[ $FAILED_SUITES -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Handle script interruption
trap 'echo -e "\n${RED}Test execution interrupted${NC}"; exit 130' INT TERM

# Execute main function with all arguments
main "$@"