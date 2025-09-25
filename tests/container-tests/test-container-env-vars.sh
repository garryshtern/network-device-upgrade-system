#!/bin/bash
# Comprehensive Container Environment Variable Testing
# Tests all docker-entrypoint.sh environment variables with mockups

set -uo pipefail
# Note: Removed -e flag to prevent immediate exit on Docker failures
# Container tests should continue even if some operations fail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.."; pwd)"
MOCKUP_DIR="$SCRIPT_DIR/mockups"
CONTAINER_IMAGE="${CONTAINER_IMAGE:-ghcr.io/garryshtern/network-device-upgrade-system:latest}"

# Test results tracking
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

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

# Test execution function
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
    log "Running test: $test_name"

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

# Create mock API token files and fix permissions
setup_mock_tokens() {
    log "Setting up mock API tokens and fixing SSH key permissions..."
    mkdir -p "$MOCKUP_DIR/tokens"

    echo "mock-fortios-api-token-12345678" > "$MOCKUP_DIR/tokens/fortios-token"
    echo "mock-opengear-api-token-87654321" > "$MOCKUP_DIR/tokens/opengear-token"

    # Set correct permissions for container access (user ansible = UID 1000)
    if command -v sudo &> /dev/null; then
        sudo chown -R 1000:1000 "$MOCKUP_DIR/keys" "$MOCKUP_DIR/tokens" 2>/dev/null || {
            warn "Could not set ownership to UID 1000. Tests may fail if SSH keys not accessible."
            warn "Run: sudo chown -R 1000:1000 $MOCKUP_DIR/keys $MOCKUP_DIR/tokens"
        }
    else
        warn "sudo not available. SSH key permissions may need manual adjustment."
    fi

    chmod 600 "$MOCKUP_DIR/tokens"/* 2>/dev/null
    chmod 600 "$MOCKUP_DIR/keys"/* 2>/dev/null
}

# Test container availability
test_container_availability() {
    log "Testing container availability..."

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
        return 1  # Don't exit, let the test continue and fail properly
    fi
}

# Test basic functionality
test_basic_functionality() {
    log "=== Testing Basic Functionality ==="

    # Test 1: Help command
    run_container_test "Help command" "success" "help"

    # Test 2: Basic syntax check
    run_container_test "Basic syntax check" "success" "syntax-check"

    # Test 3: Shell access
    run_container_test "Shell command execution" "success" "shell" -c "echo 'Container shell works'"
}

# Test SSH key authentication
test_ssh_key_authentication() {
    log "=== Testing SSH Key Authentication ==="

    # Test Cisco NX-OS SSH key
    run_container_test "Cisco NX-OS SSH key" "success" \
        -e CISCO_NXOS_SSH_KEY="/opt/keys/cisco-nxos-key" \
        -e TARGET_HOSTS="cisco-switch-01"

    # Test Cisco IOS-XE SSH key
    run_container_test "Cisco IOS-XE SSH key" "success" \
        -e CISCO_IOSXE_SSH_KEY="/opt/keys/cisco-iosxe-key" \
        -e TARGET_HOSTS="cisco-router-01"

    # Test Opengear SSH key
    run_container_test "Opengear SSH key" "success" \
        -e OPENGEAR_SSH_KEY="/opt/keys/opengear-key" \
        -e TARGET_HOSTS="opengear-console-01"

    # Test Metamako SSH key
    run_container_test "Metamako SSH key" "success" \
        -e METAMAKO_SSH_KEY="/opt/keys/metamako-key" \
        -e TARGET_HOSTS="metamako-switch-01"

    # Test multiple SSH keys
    run_container_test "Multiple SSH keys" "success" \
        -e CISCO_NXOS_SSH_KEY="/opt/keys/cisco-nxos-key" \
        -e CISCO_IOSXE_SSH_KEY="/opt/keys/cisco-iosxe-key" \
        -e OPENGEAR_SSH_KEY="/opt/keys/opengear-key" \
        -e TARGET_HOSTS="all"
}

# Test API token authentication
test_api_token_authentication() {
    log "=== Testing API Token Authentication ==="

    # Test FortiOS API token
    run_container_test "FortiOS API token" "success" \
        -e FORTIOS_API_TOKEN="$(cat "$MOCKUP_DIR/tokens/fortios-token")" \
        -e TARGET_HOSTS="fortinet-firewall-01"

    # Test Opengear API token
    run_container_test "Opengear API token" "success" \
        -e OPENGEAR_API_TOKEN="$(cat "$MOCKUP_DIR/tokens/opengear-token")" \
        -e TARGET_HOSTS="opengear-console-01"

    # Test both API tokens
    run_container_test "Multiple API tokens" "success" \
        -e FORTIOS_API_TOKEN="$(cat "$MOCKUP_DIR/tokens/fortios-token")" \
        -e OPENGEAR_API_TOKEN="$(cat "$MOCKUP_DIR/tokens/opengear-token")" \
        -e TARGET_HOSTS="fortinet-firewall-01,opengear-console-01"
}

# Test username/password authentication
test_username_password_authentication() {
    log "=== Testing Username/Password Authentication ==="

    # Test Cisco NX-OS username/password
    run_container_test "Cisco NX-OS credentials" "success" \
        -e CISCO_NXOS_USERNAME="admin" \
        -e CISCO_NXOS_PASSWORD="cisco123" \
        -e TARGET_HOSTS="cisco-switch-01"

    # Test FortiOS username/password
    run_container_test "FortiOS credentials" "success" \
        -e FORTIOS_USERNAME="admin" \
        -e FORTIOS_PASSWORD="fortinet123" \
        -e TARGET_HOSTS="fortinet-firewall-01"

    # Test multiple platform credentials
    run_container_test "Multiple platform credentials" "success" \
        -e CISCO_NXOS_USERNAME="admin" \
        -e CISCO_NXOS_PASSWORD="cisco123" \
        -e CISCO_IOSXE_USERNAME="admin" \
        -e CISCO_IOSXE_PASSWORD="cisco456" \
        -e FORTIOS_USERNAME="admin" \
        -e FORTIOS_PASSWORD="fortinet123" \
        -e TARGET_HOSTS="all"
}

# Test upgrade configuration variables
test_upgrade_configuration() {
    log "=== Testing Upgrade Configuration Variables ==="

    # Test basic upgrade variables
    run_container_test "Basic upgrade variables" "success" \
        -e TARGET_HOSTS="cisco-switch-01" \
        -e TARGET_FIRMWARE="9.3.12" \
        -e UPGRADE_PHASE="loading" \
        -e MAINTENANCE_WINDOW="false"

    # Test EPLD upgrade variables
    run_container_test "EPLD upgrade variables" "success" \
        -e TARGET_HOSTS="cisco-switch-01" \
        -e ENABLE_EPLD_UPGRADE="true" \
        -e ALLOW_DISRUPTIVE_EPLD="false" \
        -e EPLD_UPGRADE_TIMEOUT="7200" \
        -e TARGET_EPLD_IMAGE="n9000-epld.9.3.12.img"

    # Test FortiOS multi-step upgrade
    run_container_test "FortiOS multi-step upgrade" "success" \
        -e TARGET_HOSTS="fortinet-firewall-01" \
        -e MULTI_STEP_UPGRADE_REQUIRED="true" \
        -e UPGRADE_PATH="6.4.8,7.0.12,7.2.5"

    # Test firmware and backup paths
    run_container_test "Firmware and backup paths" "success" \
        -e FIRMWARE_BASE_PATH="/opt/firmware" \
        -e BACKUP_BASE_PATH="/opt/backups" \
        -e TARGET_HOSTS="cisco-switch-01"
}

# Test additional configuration variables
test_additional_configuration() {
    log "=== Testing Additional Configuration Variables ==="

    # Test image server credentials
    run_container_test "Image server credentials" "success" \
        -e IMAGE_SERVER_USERNAME="ftp-user" \
        -e IMAGE_SERVER_PASSWORD="ftp-pass123" \
        -e TARGET_HOSTS="cisco-switch-01"

    # Test SNMP configuration
    run_container_test "SNMP configuration" "success" \
        -e SNMP_COMMUNITY="public" \
        -e TARGET_HOSTS="cisco-switch-01"

    # Test Ansible verbosity
    run_container_test "Ansible verbosity" "success" \
        -e ANSIBLE_VERBOSITY="2" \
        -e TARGET_HOSTS="cisco-switch-01"
}

# Test error conditions
test_error_conditions() {
    log "=== Testing Error Conditions ==="

    # Test missing inventory file
    run_container_test "Missing inventory file" "fail" \
        -e ANSIBLE_INVENTORY="/nonexistent/inventory.yml"

    # Test TARGET_HOSTS without inventory (critical new test)
    run_container_test "TARGET_HOSTS without inventory" "fail" \
        -e ANSIBLE_INVENTORY="/nonexistent/inventory.yml" \
        -e TARGET_HOSTS="cisco-switch-01"

    # Test invalid TARGET_HOSTS
    run_container_test "Invalid TARGET_HOSTS" "fail" \
        -e TARGET_HOSTS="nonexistent-device"

    # Test invalid command
    run_container_test "Invalid command" "fail" "invalid-command"
}

# Test comprehensive scenario
test_comprehensive_scenario() {
    log "=== Testing Comprehensive Scenario ==="

    # Test with all authentication methods and configuration
    run_container_test "Comprehensive configuration" "success" \
        -e CISCO_NXOS_SSH_KEY="/opt/keys/cisco-nxos-key" \
        -e CISCO_IOSXE_SSH_KEY="/opt/keys/cisco-iosxe-key" \
        -e FORTIOS_API_TOKEN="$(cat "$MOCKUP_DIR/tokens/fortios-token")" \
        -e OPENGEAR_SSH_KEY="/opt/keys/opengear-key" \
        -e OPENGEAR_API_TOKEN="$(cat "$MOCKUP_DIR/tokens/opengear-token")" \
        -e METAMAKO_SSH_KEY="/opt/keys/metamako-key" \
        -e TARGET_HOSTS="all" \
        -e TARGET_FIRMWARE="auto-detect" \
        -e UPGRADE_PHASE="validation" \
        -e ENABLE_EPLD_UPGRADE="true" \
        -e MULTI_STEP_UPGRADE_REQUIRED="false" \
        -e IMAGE_SERVER_USERNAME="ftp-user" \
        -e IMAGE_SERVER_PASSWORD="ftp-pass123" \
        -e SNMP_COMMUNITY="private" \
        -e FIRMWARE_BASE_PATH="/opt/firmware" \
        -e BACKUP_BASE_PATH="/opt/backups" \
        -e ANSIBLE_VERBOSITY="1"
}

# Main execution
main() {
    echo "🚀 Container Environment Variable Testing Suite"
    echo "=============================================="
    echo "Container Image: $CONTAINER_IMAGE"
    echo "Mockup Directory: $MOCKUP_DIR"
    echo ""

    # Setup
    setup_mock_tokens

    # Test container availability - exit if critical failure
    if ! test_container_availability; then
        error "Container availability test failed - cannot continue"
        echo "Container functionality is required and must work properly"
        exit 1
    fi

    # Run all tests
    test_basic_functionality
    test_ssh_key_authentication
    test_api_token_authentication
    test_username_password_authentication
    test_upgrade_configuration
    test_additional_configuration
    test_error_conditions
    test_comprehensive_scenario

    # Results
    echo ""
    echo "=============================================="
    echo "🎯 Test Results Summary"
    echo "=============================================="
    echo "Tests Run: $TESTS_RUN"
    echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}🎉 All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}❌ Some tests failed.${NC}"
        exit 1
    fi
}

# Execute main function
main "$@"