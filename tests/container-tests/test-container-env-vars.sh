#!/bin/bash
# Comprehensive Container Environment Variable Testing
# Tests all docker-entrypoint.sh environment variables with mockups

set -uo pipefail
# Note: Removed -e flag to prevent immediate exit on Docker failures
# Container tests should continue even if some operations fail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.."; pwd)"
MOCKUP_DIR="$SCRIPT_DIR/mockups"
CONTAINER_IMAGE="${CONTAINER_IMAGE:-ghcr.io/garryshtern/network-device-upgrade-system:latest}"

# Source the shared test library
source "$SCRIPT_DIR/lib/test-common.sh"


# Test basic functionality
test_basic_functionality() {
    log "=== Testing Basic Functionality ==="

    # Test 1: Help command
    run_container_test "Help command" "success" "help"

    # Test 2: Basic syntax check
    run_container_test "Basic syntax check" "success" "syntax-check"

    # Test 3: Shell access
    run_container_test "Shell command execution" "success" shell -c "echo 'Container shell works'"
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
        -e TARGET_EPLD_FIRMWARE="n9000-epld.9.3.12.M.img"

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
        -e INVENTORY_FILE="/nonexistent/inventory.yml"

    # Test TARGET_HOSTS without inventory (critical new test)
    run_container_test "TARGET_HOSTS without inventory" "fail" \
        -e INVENTORY_FILE="/nonexistent/inventory.yml" \
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

    # Setup using shared library
    setup_mock_environment "$SCRIPT_DIR"

    # Test container availability - exit if critical failure
    if ! check_docker_availability; then
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

    # Print test summary using shared library function
    print_test_summary "Container Environment Variable Tests"
}

# Execute main function
main "$@"