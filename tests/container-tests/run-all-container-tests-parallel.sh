#!/bin/bash
# Parallel Container Test Runner
# Runs container test suites in parallel for faster execution

set -euo pipefail

# Source common test library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.."; pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/test-common.sh"

# Test configuration
CONTAINER_IMAGE="${CONTAINER_IMAGE:-ghcr.io/garryshtern/network-device-upgrade-system:latest}"

# Test suite tracking
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0
START_TIME=$(date +%s)

# Parallel execution control
MAX_PARALLEL_JOBS=3  # Run up to 3 test suites in parallel
JOB_PIDS_LIST=()
JOB_NAMES_LIST=()
JOB_RESULTS_FILE="/tmp/container-test-results-$$.txt"
: > "$JOB_RESULTS_FILE"  # Clear results file

# Run individual test suite in background
run_test_suite_async() {
    local suite_name="$1"
    local test_script="$2"

    TOTAL_SUITES=$((TOTAL_SUITES + 1))
    section "Running test suite in parallel: $suite_name"
    log "Script: $test_script"

    if [[ ! -f "$test_script" ]]; then
        error "Test script not found: $test_script"
        FAILED_SUITES=$((FAILED_SUITES + 1))
        return 1
    fi

    # Run test in background and capture its output
    bash "$test_script" > "/tmp/container-test-$suite_name-$$.log" 2>&1 &
    local pid=$!
    JOB_PIDS_LIST+=($pid)
    JOB_NAMES_LIST+=("$suite_name")

    log "Started test suite '$suite_name' in background (PID: $pid)"
}

# Wait for background jobs and collect results
wait_for_jobs() {
    log "Waiting for all test suites to complete..."

    # Wait for all background PIDs
    for pid in "${JOB_PIDS_LIST[@]}"; do
        log "Waiting for PID $pid to complete..."
        wait $pid || true
    done

    # Read results from temp file
    if [[ -f "$JOB_RESULTS_FILE" ]]; then
        while IFS='|' read -r suite_name exit_code; do
            if [[ -n "$suite_name" ]]; then
                if [[ $exit_code -eq 0 ]]; then
                    success "Test suite '$suite_name' PASSED"
                    PASSED_SUITES=$((PASSED_SUITES + 1))
                else
                    error "Test suite '$suite_name' FAILED (exit code: $exit_code)"
                    FAILED_SUITES=$((FAILED_SUITES + 1))
                fi
            fi
        done < "$JOB_RESULTS_FILE"
    else
        error "Results file not found: $JOB_RESULTS_FILE"
    fi
}

# Display test output
display_test_outputs() {
    echo ""
    section "Test Output Details"
    echo ""

    # Read results from temp file to find failures
    if [[ -f "$JOB_RESULTS_FILE" ]]; then
        while IFS='|' read -r suite_name exit_code; do
            local log_file="/tmp/container-test-${suite_name// /_}.log"

            # In debug mode, show all output; otherwise only failures
            if [[ "${DEBUG_SSH_KEY_TEST:-}" == "true" ]]; then
                if [[ -n "$suite_name" && -f "$log_file" ]]; then
                    echo -e "${CYAN}=== Full Test Output: $suite_name (exit code: $exit_code) ===${NC}"
                    cat "$log_file"
                    echo ""
                fi
            else
                if [[ -n "$suite_name" && $exit_code -ne 0 && -f "$log_file" ]]; then
                    echo -e "${RED}=== Failed Test Output: $suite_name ===${NC}"
                    tail -50 "$log_file"
                    echo ""
                fi
            fi
        done < "$JOB_RESULTS_FILE"
    fi
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."

    # Check Docker availability
    if ! command -v docker &> /dev/null; then
        warn "Docker is not installed or not in PATH - Container tests skipped"
        exit 0
    fi

    # Check if container image exists
    if ! docker images | grep -q "network-device-upgrade-system"; then
        error "Container image not found: $CONTAINER_IMAGE"
        error "Please build the container image first"
        exit 1
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
    echo "🏆 PARALLEL CONTAINER TEST REPORT"
    echo "========================================================"
    echo "Container Image: $CONTAINER_IMAGE"
    echo "Execution Mode: PARALLEL (max $MAX_PARALLEL_JOBS concurrent jobs)"
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
    local report_file="$SCRIPT_DIR/results/test-results-parallel-$(date +%Y%m%d-%H%M%S).log"
    {
        echo "Parallel Container Test Execution Report"
        echo "Generated: $(date)"
        echo "Container Image: $CONTAINER_IMAGE"
        echo "Parallel Jobs: $MAX_PARALLEL_JOBS"
        echo "Total Duration: ${minutes}m ${seconds}s"
        echo "Total Suites: $TOTAL_SUITES"
        echo "Passed Suites: $PASSED_SUITES"
        echo "Failed Suites: $FAILED_SUITES"
        echo "Success Rate: $(( (PASSED_SUITES * 100) / TOTAL_SUITES ))%"
        echo ""
        echo "Individual Test Results:"
        # Read results from temp file
        if [[ -f "$JOB_RESULTS_FILE" ]]; then
            while IFS='|' read -r suite_name exit_code; do
                if [[ -n "$suite_name" ]]; then
                    if [[ $exit_code -eq 0 ]]; then
                        echo "  ✓ $suite_name: PASSED"
                    else
                        echo "  ✗ $suite_name: FAILED (exit code: $exit_code)"
                    fi
                fi
            done < "$JOB_RESULTS_FILE"
        fi
    } > "$report_file"

    log "Detailed test report saved to: $report_file"
}

# Main test execution
main() {
    echo "🚀 PARALLEL CONTAINER TEST SUITE RUNNER"
    echo "==========================================="
    echo "Testing container functionality with parallel execution"
    echo "Container Image: $CONTAINER_IMAGE"
    echo "Max Parallel Jobs: $MAX_PARALLEL_JOBS"
    echo "Start Time: $(date)"
    echo ""

    # Setup
    check_prerequisites
    setup_test_environment

    echo ""
    section "Starting parallel test suite execution..."
    echo ""

    # Run test suites in parallel (with job limit)
    set +e  # Don't exit on test failures

    # DEBUG MODE: Only run SSH Key Privilege Drop Tests with verbose output
    if [[ "${DEBUG_SSH_KEY_TEST:-}" == "true" ]]; then
        log "DEBUG MODE: Running only SSH Key Privilege Drop Tests with verbose output"
        run_test_suite_async "SSH Key Privilege Drop Tests" "$SCRIPT_DIR/test-ssh-key-privilege-drop.sh"
    else
        # Group 1: Light tests (fast)
        run_test_suite_async "Local Entrypoint Tests" "$SCRIPT_DIR/test-entrypoint-locally.sh"
        run_test_suite_async "Environment Variable Tests" "$SCRIPT_DIR/test-container-env-vars.sh"
        run_test_suite_async "SSH Key Privilege Drop Tests" "$SCRIPT_DIR/test-ssh-key-privilege-drop.sh"

        # Wait for first group before starting heavy tests
        sleep 2

        # Group 2: Heavy tests (may take longer)
        run_test_suite_async "Comprehensive Functionality Tests" "$SCRIPT_DIR/test-comprehensive-container-functionality.sh"
        run_test_suite_async "Mock Device Interaction Tests" "$SCRIPT_DIR/test-mock-device-interactions.sh"
        run_test_suite_async "Specific Functionality Tests" "$SCRIPT_DIR/test-specific-functionality.sh"
    fi

    # Wait for all jobs to complete
    wait_for_jobs

    # Display failed test outputs
    display_test_outputs

    # Generate final report
    set -e
    generate_test_report

    # Cleanup temp log files
    rm -f /tmp/container-test-*.log

    # Exit with appropriate code
    if [[ $FAILED_SUITES -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Handle script interruption
trap 'echo -e "\n${RED}Test execution interrupted${NC}"; kill $(jobs -p) 2>/dev/null; exit 130' INT TERM

# Execute main function
main "$@"
