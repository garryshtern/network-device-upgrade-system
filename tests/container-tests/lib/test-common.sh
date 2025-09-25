#!/bin/bash
# Shared Test Library for Container Tests
# Common functions and utilities used across all container test scripts

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test counters (global variables)
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

section() {
    echo -e "${CYAN}[SECTION]${NC} $1"
}

# Test execution function
run_test() {
    local test_name="$1"
    shift
    local expected_result="success"

    # Check if first argument is expected result
    if [[ "$1" == "success" || "$1" == "fail" ]]; then
        expected_result="$1"
        shift
    fi

    TESTS_RUN=$((TESTS_RUN + 1))
    log "Running test: $test_name"

    # Execute the test command
    local exit_code=0
    if "$@" >/dev/null 2>&1; then
        exit_code=0
    else
        exit_code=$?
    fi

    # Check results
    if [[ "$expected_result" == "success" && $exit_code -eq 0 ]]; then
        success "$test_name: PASSED"
        return 0
    elif [[ "$expected_result" == "fail" && $exit_code -ne 0 ]]; then
        success "$test_name: PASSED (expected failure)"
        return 0
    else
        error "$test_name: FAILED (exit code: $exit_code)"
        return 1
    fi
}

# Container test execution function
run_container_test() {
    local test_name="$1"
    local expected_result="$2"
    local command="syntax-check"  # Default command
    local docker_args=()

    # Parse arguments - if 3rd argument doesn't start with '-', it's the command
    if [[ $# -gt 2 && ! "$3" =~ ^- ]]; then
        command="$3"
        shift 3
        docker_args=("$@")
    else
        shift 2
        docker_args=("$@")
    fi

    TESTS_RUN=$((TESTS_RUN + 1))
    log "Running container test: $test_name"

    # Create temporary files for capturing output
    local stdout_file="/tmp/container-test-stdout-$$"
    local stderr_file="/tmp/container-test-stderr-$$"

    local exit_code=0

    # Run the container test
    if docker run --rm \
        -v "$MOCKUP_DIR/inventory:/opt/inventory:ro" \
        -v "$MOCKUP_DIR/keys:/opt/keys:ro" \
        -e ANSIBLE_INVENTORY="/opt/inventory/production.yml" \
        "${docker_args[@]}" \
        "$CONTAINER_IMAGE" "$command" \
        > "$stdout_file" 2> "$stderr_file"; then
        exit_code=0
    else
        exit_code=$?
    fi

    # Check results
    if [[ "$expected_result" == "success" && $exit_code -eq 0 ]]; then
        success "$test_name: PASSED"
    elif [[ "$expected_result" == "fail" && $exit_code -ne 0 ]]; then
        success "$test_name: PASSED (expected failure)"
    else
        error "$test_name: FAILED (exit code: $exit_code)"
        echo "STDOUT:"
        cat "$stdout_file" | head -10
        echo "STDERR:"
        cat "$stderr_file" | head -10
    fi

    # Cleanup
    rm -f "$stdout_file" "$stderr_file"
}

# Test results summary
print_test_summary() {
    local script_name="${1:-Test Suite}"

    echo ""
    echo "=============================================="
    echo "🎯 $script_name Results Summary"
    echo "=============================================="
    echo "Tests Run: $TESTS_RUN"
    echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}🎉 All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}❌ Some tests failed.${NC}"
        return 1
    fi
}

# Docker availability check
check_docker_availability() {
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        error "Docker not available - container tests cannot run"
        error "Container functionality requires Docker or Podman"
        return 1
    fi

    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        error "Docker daemon not running - container tests cannot run"
        error "Please ensure Docker service is started"
        return 1
    fi

    # Check for local image first
    if docker images | grep -q "network-device-upgrade-system"; then
        success "Container image found locally"
        return 0
    fi

    # Try to pull image only if not found locally
    log "Attempting to pull container image: $CONTAINER_IMAGE"
    if docker pull "$CONTAINER_IMAGE" 2>/dev/null; then
        success "Container image pulled successfully"
        return 0
    else
        error "Failed to pull container image: $CONTAINER_IMAGE"
        error "Container functionality tests require a working container image"
        return 1
    fi
}

# Setup mock environment
setup_mock_environment() {
    local script_dir="$1"

    log "Setting up mock test environment..."

    # Ensure mockup directories exist
    mkdir -p "$script_dir/mockups/keys"
    mkdir -p "$script_dir/mockups/tokens"
    mkdir -p "$script_dir/mockups/firmware"
    mkdir -p "$script_dir/mockups/inventory"

    # Create mock API tokens
    echo "mock-fortios-api-token-12345678" > "$script_dir/mockups/tokens/fortios-token"
    echo "mock-opengear-api-token-87654321" > "$script_dir/mockups/tokens/opengear-token"

    # Set correct permissions for container access (user ansible = UID 1000)
    if command -v sudo &> /dev/null; then
        sudo chown -R 1000:1000 "$script_dir/mockups/keys" "$script_dir/mockups/tokens" 2>/dev/null || {
            warn "Could not set ownership to UID 1000. Tests may fail if SSH keys not accessible."
            warn "Run: sudo chown -R 1000:1000 $script_dir/mockups/keys $script_dir/mockups/tokens"
        }
    else
        warn "sudo not available. SSH key permissions may need manual adjustment."
    fi

    chmod 600 "$script_dir/mockups/tokens"/* 2>/dev/null || true
    chmod 600 "$script_dir/mockups/keys"/* 2>/dev/null || true

    success "Mock environment setup completed"
}