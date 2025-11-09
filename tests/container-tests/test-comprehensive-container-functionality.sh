#!/bin/bash
# Comprehensive Container Functionality Testing
# Tests all container functionality against mock devices with complete scenarios

set -euo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.."; pwd)"
MOCKUP_DIR="$SCRIPT_DIR/mockups"
CONTAINER_IMAGE="${CONTAINER_IMAGE:-ghcr.io/garryshtern/network-device-upgrade-system:latest}"

# Source the shared test library
source "$SCRIPT_DIR/lib/test-common.sh"

# Enhanced test execution function with command support
run_comprehensive_container_test() {
    local test_name="$1"
    local expected_result="$2"
    local command="$3"
    shift 3

    # Parse remaining arguments into docker args and container command args
    local docker_args=()
    local container_args=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -e|--env)
                # Docker environment variable
                docker_args+=("$1")
                if [[ $# -gt 1 ]]; then
                    docker_args+=("$2")
                    shift 2
                else
                    shift
                fi
                ;;
            --)
                # Everything after -- goes to container command
                shift
                container_args+=("$@")
                break
                ;;
            *)
                # For shell command, -c and following args go to container
                if [[ "$command" == "shell" ]] || [[ ${#container_args[@]} -gt 0 ]]; then
                    container_args+=("$1")
                else
                    docker_args+=("$1")
                fi
                shift
                ;;
        esac
    done

    TESTS_RUN=$((TESTS_RUN + 1))
    log "Running test: $test_name (command: $command)"

    # Create temporary files for capturing output
    local stdout_file="/tmp/container-test-stdout-$$"
    local stderr_file="/tmp/container-test-stderr-$$"
    local exit_code=0

    # Build docker command with proper volume mounts
    local docker_cmd=(
        docker run --rm
        -v "$MOCKUP_DIR/inventory:/opt/inventory:ro"
        -v "$MOCKUP_DIR/keys:/opt/keys:ro"
        -v "$MOCKUP_DIR/firmware:/opt/firmware:ro"
        -v "$PROJECT_ROOT/ansible-content:/opt/network-upgrade/ansible-content:ro"
        -e INVENTORY_FILE="/opt/inventory/production.yml"
        -e ANSIBLE_CONFIG="/opt/network-upgrade/ansible-content/ansible.cfg"
    )

    # Add docker environment arguments
    docker_cmd+=("${docker_args[@]}")

    # Add container image and command
    docker_cmd+=("$CONTAINER_IMAGE" "$command")

    # Add container command arguments if any
    if [[ ${#container_args[@]} -gt 0 ]]; then
        docker_cmd+=("${container_args[@]}")
    fi

    # Run the container test
    if "${docker_cmd[@]}" > "$stdout_file" 2> "$stderr_file"; then
        exit_code=0
    else
        exit_code=$?
    fi

    # Check results and provide detailed output for failures
    if [[ "$expected_result" == "success" && $exit_code -eq 0 ]]; then
        success "$test_name: PASSED"
        # Clean up successful test files
        rm -f "$stdout_file" "$stderr_file"
    elif [[ "$expected_result" == "fail" && $exit_code -ne 0 ]]; then
        success "$test_name: PASSED (expected failure, exit code: $exit_code)"
        # Show output even for expected failures to verify they fail for the right reason
        echo "=== EXPECTED FAILURE OUTPUT ==="
        echo "Command: ${docker_cmd[*]}"
        echo "STDOUT:"
        cat "$stdout_file"
        echo "STDERR:"
        cat "$stderr_file"
        echo "=== END EXPECTED FAILURE OUTPUT ==="
        # Clean up expected failure files
        rm -f "$stdout_file" "$stderr_file"
    else
        error "$test_name: FAILED (exit code: $exit_code)"
        echo "=== DOCKER COMMAND THAT FAILED ==="
        echo "${docker_cmd[*]}"
        echo "=== FULL STDOUT OUTPUT ==="
        cat "$stdout_file"
        echo "=== FULL STDERR OUTPUT ==="
        cat "$stderr_file"
        echo "=== END ERROR OUTPUT ==="

        # Keep failed test output files for debugging (don't delete them immediately)
        echo "Debug files preserved: $stdout_file $stderr_file"
    fi
}

# Setup additional mock firmware files for comprehensive testing
setup_firmware_files() {
    log "Setting up mock firmware files..."

    # Create firmware directories
    mkdir -p "$MOCKUP_DIR/firmware/cisco.nxos"
    mkdir -p "$MOCKUP_DIR/firmware/cisco.ios"
    mkdir -p "$MOCKUP_DIR/firmware/fortios"
    mkdir -p "$MOCKUP_DIR/firmware/opengear"
    mkdir -p "$MOCKUP_DIR/backups"

    # Create mock firmware files (small empty files for testing)
    echo "mock-cisco-nxos-firmware" > "$MOCKUP_DIR/firmware/cisco.nxos/nxos64-cs.10.4.5.M.bin"
    echo "mock-cisco-iosxe-firmware" > "$MOCKUP_DIR/firmware/cisco.ios/cat9k_iosxe.17.09.04a.SPA.bin"
    echo "mock-fortios-firmware" > "$MOCKUP_DIR/firmware/fortios/FGT_VM64_KVM-v7.2.5-build1517-FORTINET.out"
    echo "mock-opengear-firmware" > "$MOCKUP_DIR/firmware/opengear/cm71xx-5.2.4.flash"
    echo "mock-opengear-firmware-22.1.3-im" > "$MOCKUP_DIR/firmware/opengear/im72xx-22.1.3.flash"
    echo "mock-opengear-firmware-22.1.3-ops" > "$MOCKUP_DIR/firmware/opengear/operations_manager-22.1.3-production-signed.raucb"

    # Set permissions for container access
    chmod -R 644 "$MOCKUP_DIR/firmware" 2>/dev/null || true

    success "Mock firmware files setup completed"
}


# Test all container commands
test_container_commands() {
    log "=== Testing All Container Commands ==="

    # Test help command
    run_comprehensive_container_test "Help command" "success" "help"

    # Test syntax-check command (default)
    run_comprehensive_container_test "Syntax check command" "success" "syntax-check"

    # Test dry-run command
    run_comprehensive_container_test "Dry run command" "success" "dry-run" \
        -e TARGET_HOSTS="cisco-switch-01"

    # Test test command
    run_comprehensive_container_test "Test command" "success" "test"

    # Test shell command with simple execution
    run_comprehensive_container_test "Shell command execution" "success" "shell" \
        -c "echo 'Container shell works'"
}

# Test TARGET_HOSTS validation (NEW - critical functionality)
test_target_hosts_validation() {
    log "=== Testing TARGET_HOSTS Validation ==="

    # Test valid single host
    run_comprehensive_container_test "Valid single host" "success" "syntax-check" \
        -e TARGET_HOSTS="cisco-switch-01"

    # Test valid multiple hosts
    run_comprehensive_container_test "Valid multiple hosts" "success" "syntax-check" \
        -e TARGET_HOSTS="cisco-switch-01,fortinet-firewall-01"

    # Test 'all' hosts
    run_comprehensive_container_test "All hosts" "success" "syntax-check" \
        -e TARGET_HOSTS="all"

    # Test invalid host (should fail)
    run_comprehensive_container_test "Invalid host" "fail" "syntax-check" \
        -e TARGET_HOSTS="nonexistent-device"

    # Test TARGET_HOSTS without inventory (should fail)
    run_comprehensive_container_test "TARGET_HOSTS without inventory" "fail" "syntax-check" \
        -e INVENTORY_FILE="/nonexistent/inventory.yml" \
        -e TARGET_HOSTS="cisco-switch-01"

    # Test mixed valid/invalid hosts (should fail)
    run_comprehensive_container_test "Mixed valid/invalid hosts" "fail" "syntax-check" \
        -e TARGET_HOSTS="cisco-switch-01,invalid-device,fortinet-firewall-01"
}

# Test platform-specific authentication
test_platform_authentication() {
    log "=== Testing Platform-Specific Authentication ==="

    # Test Cisco NX-OS with SSH key
    run_comprehensive_container_test "Cisco NX-OS SSH auth" "success" "syntax-check" \
        -e CISCO_NXOS_SSH_KEY="/opt/keys/cisco-nxos-key" \
        -e TARGET_HOSTS="cisco-switch-01"

    # Test Cisco IOS-XE with username/password
    run_comprehensive_container_test "Cisco IOS-XE password auth" "success" "syntax-check" \
        -e CISCO_IOSXE_USERNAME="admin" \
        -e CISCO_IOSXE_PASSWORD="cisco123" \
        -e TARGET_HOSTS="cisco-router-01"

    # Test FortiOS with API token
    run_comprehensive_container_test "FortiOS API auth" "success" "syntax-check" \
        -e FORTIOS_API_TOKEN="$(cat "$MOCKUP_DIR/tokens/fortios-token")" \
        -e TARGET_HOSTS="fortinet-firewall-01"

    # Test Opengear dual authentication (SSH + API)
    run_comprehensive_container_test "Opengear dual auth" "success" "syntax-check" \
        -e OPENGEAR_SSH_KEY="/opt/keys/opengear-key" \
        -e OPENGEAR_API_TOKEN="$(cat "$MOCKUP_DIR/tokens/opengear-token")" \
        -e TARGET_HOSTS="opengear-console-01"
}

# Test upgrade phases and workflows
test_upgrade_workflows() {
    log "=== Testing Upgrade Workflows ==="

    # Test loading phase
    run_comprehensive_container_test "Loading phase workflow" "success" "dry-run" \
        -e TARGET_HOSTS="cisco-switch-01" \
        -e TARGET_FIRMWARE="nxos64-cs.10.4.5.M.bin" \
        -e UPGRADE_PHASE="loading" \
        -e CISCO_NXOS_SSH_KEY="/opt/keys/cisco-nxos-key"

    # Test validation phase
    run_comprehensive_container_test "Validation phase workflow" "success" "dry-run" \
        -e TARGET_HOSTS="fortinet-firewall-01" \
        -e TARGET_FIRMWARE="FGT_VM64_KVM-v7.2.5-build1517-FORTINET.out" \
        -e UPGRADE_PHASE="validation" \
        -e FORTIOS_API_TOKEN="$(cat "$MOCKUP_DIR/tokens/fortios-token")"

    # Test full workflow
    run_comprehensive_container_test "Full workflow" "success" "dry-run" \
        -e TARGET_HOSTS="opengear-console-01" \
        -e TARGET_FIRMWARE="cm71xx-5.2.4.flash" \
        -e UPGRADE_PHASE="full" \
        -e OPENGEAR_SSH_KEY="/opt/keys/opengear-key"
}

# Test EPLD upgrade functionality
test_epld_functionality() {
    log "=== Testing EPLD Upgrade Functionality ==="

    # Test EPLD upgrade enabled
    run_comprehensive_container_test "EPLD upgrade enabled" "success" "syntax-check" \
        -e TARGET_HOSTS="cisco-switch-01" \
        -e ENABLE_EPLD_UPGRADE="true" \
        -e TARGET_EPLD_FIRMWARE="n9000-epld.9.3.16.M.img" \
        -e CISCO_NXOS_SSH_KEY="/opt/keys/cisco-nxos-key"

    # Test disruptive EPLD upgrade
    run_comprehensive_container_test "Disruptive EPLD upgrade" "success" "syntax-check" \
        -e TARGET_HOSTS="cisco-switch-01" \
        -e ENABLE_EPLD_UPGRADE="true" \
        -e ALLOW_DISRUPTIVE_EPLD="true" \
        -e MAINTENANCE_WINDOW="true" \
        -e EPLD_UPGRADE_TIMEOUT="7200"
}

# Test FortiOS multi-step upgrades
test_fortios_multistep() {
    log "=== Testing FortiOS Multi-Step Upgrades ==="

    # Test multi-step upgrade configuration
    run_comprehensive_container_test "FortiOS multi-step upgrade" "success" "syntax-check" \
        -e TARGET_HOSTS="fortinet-firewall-01" \
        -e MULTI_STEP_UPGRADE_REQUIRED="true" \
        -e UPGRADE_PATH="6.4.8,7.0.12,7.2.5" \
        -e TARGET_FIRMWARE="7.2.5" \
        -e FORTIOS_API_TOKEN="$(cat "$MOCKUP_DIR/tokens/fortios-token")"
}

# Test error conditions and edge cases
test_error_conditions() {
    log "=== Testing Error Conditions and Edge Cases ==="

    # Test missing inventory
    run_comprehensive_container_test "Missing inventory" "fail" "syntax-check" \
        -e INVENTORY_FILE="/nonexistent/inventory.yml"

    # Test invalid command
    run_comprehensive_container_test "Invalid command" "fail" "invalid-command"

    # Test conflicting authentication (should still work)
    run_comprehensive_container_test "Conflicting authentication" "success" "syntax-check" \
        -e CISCO_NXOS_SSH_KEY="/opt/keys/cisco-nxos-key" \
        -e CISCO_NXOS_USERNAME="admin" \
        -e CISCO_NXOS_PASSWORD="cisco123" \
        -e TARGET_HOSTS="cisco-switch-01"

    # Test empty TARGET_HOSTS (should use default 'all')
    run_comprehensive_container_test "Empty TARGET_HOSTS" "success" "syntax-check" \
        -e TARGET_HOSTS=""

    # Test malformed TARGET_HOSTS
    run_comprehensive_container_test "Malformed TARGET_HOSTS" "fail" "syntax-check" \
        -e TARGET_HOSTS="cisco-switch-01,,,invalid-host,,"
}

# Test Ansible verbosity and configuration
test_ansible_configuration() {
    log "=== Testing Ansible Configuration ==="

    # Test Ansible verbosity
    run_comprehensive_container_test "Ansible verbosity" "success" "syntax-check" \
        -e ANSIBLE_VERBOSITY="2" \
        -e TARGET_HOSTS="cisco-switch-01"

    # Test custom playbook
    run_comprehensive_container_test "Custom playbook" "success" "syntax-check" \
        -e ANSIBLE_PLAYBOOK="ansible-content/playbooks/health-check.yml" \
        -e TARGET_HOSTS="cisco-switch-01"

    # Test image server configuration
    run_comprehensive_container_test "Image server config" "success" "syntax-check" \
        -e IMAGE_SERVER_USERNAME="ftp-user" \
        -e IMAGE_SERVER_PASSWORD="ftp-pass123" \
        -e TARGET_HOSTS="cisco-switch-01"

    # Test SNMP configuration
    run_comprehensive_container_test "SNMP configuration" "success" "syntax-check" \
        -e SNMP_COMMUNITY="private" \
        -e TARGET_HOSTS="cisco-switch-01"
}

# Test comprehensive real-world scenarios
test_comprehensive_scenarios() {
    log "=== Testing Comprehensive Real-World Scenarios ==="

    # Scenario 1: Multi-platform environment with all authentication methods
    run_comprehensive_container_test "Multi-platform comprehensive" "success" "dry-run" \
        -e CISCO_NXOS_SSH_KEY="/opt/keys/cisco-nxos-key" \
        -e CISCO_IOSXE_USERNAME="admin" \
        -e CISCO_IOSXE_PASSWORD="cisco123" \
        -e FORTIOS_API_TOKEN="$(cat "$MOCKUP_DIR/tokens/fortios-token")" \
        -e OPENGEAR_SSH_KEY="/opt/keys/opengear-key" \
        -e OPENGEAR_API_TOKEN="$(cat "$MOCKUP_DIR/tokens/opengear-token")" \
        -e TARGET_HOSTS="all" \
        -e UPGRADE_PHASE="validation"

    # Scenario 2: Production-like configuration with all options
    run_comprehensive_container_test "Production-like configuration" "success" "syntax-check" \
        -e TARGET_HOSTS="cisco-switch-01,fortinet-firewall-01" \
        -e TARGET_FIRMWARE="auto-detect" \
        -e UPGRADE_PHASE="full" \
        -e MAINTENANCE_WINDOW="true" \
        -e ENABLE_EPLD_UPGRADE="true" \
        -e FIRMWARE_BASE_PATH="/opt/firmware" \
        -e BACKUP_BASE_PATH="/opt/backups" \
        -e IMAGE_SERVER_USERNAME="ftp-user" \
        -e IMAGE_SERVER_PASSWORD="ftp-pass123" \
        -e SNMP_COMMUNITY="private" \
        -e ANSIBLE_VERBOSITY="1" \
        -e CISCO_NXOS_SSH_KEY="/opt/keys/cisco-nxos-key" \
        -e FORTIOS_API_TOKEN="$(cat "$MOCKUP_DIR/tokens/fortios-token")"

    # Scenario 3: Emergency rollback scenario
    run_comprehensive_container_test "Emergency rollback scenario" "success" "syntax-check" \
        -e TARGET_HOSTS="cisco-switch-01" \
        -e UPGRADE_PHASE="rollback" \
        -e MAINTENANCE_WINDOW="true" \
        -e CISCO_NXOS_SSH_KEY="/opt/keys/cisco-nxos-key"
}

# Main execution
main() {
    echo "🚀 Comprehensive Container Functionality Testing Suite"
    echo "===================================================="
    echo "Container Image: $CONTAINER_IMAGE"
    echo "Mockup Directory: $MOCKUP_DIR"
    echo ""

    # Setup using shared library and additional firmware files
    setup_mock_environment "$SCRIPT_DIR"
    setup_firmware_files

    # Test container availability - exit if critical failure
    if ! check_docker_availability; then
        error "Container availability test failed - cannot continue"
        echo "Container functionality is required and must work properly"
        exit 1
    fi

    # Core functionality tests
    test_container_commands
    test_target_hosts_validation
    test_platform_authentication

    # Upgrade workflow tests
    test_upgrade_workflows
    test_epld_functionality
    test_fortios_multistep

    # Configuration and edge case tests
    test_ansible_configuration
    test_error_conditions

    # Comprehensive scenarios
    test_comprehensive_scenarios

    # Print comprehensive test summary using shared library function
    print_test_summary "Comprehensive Container Functionality Tests"
}

# Execute main function
main "$@"