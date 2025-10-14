#!/bin/bash
# Specific Functionality Testing
# Tests SSH keys, API tokens, firmware versions, and detailed configurations

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.."; pwd)"

# Test results tracking
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

error() {
    echo -e "${RED}[FAIL]${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

section() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

run_test() {
    local test_name="$1"
    shift
    TESTS_RUN=$((TESTS_RUN + 1))

    log "Testing: $test_name"

    cd "$PROJECT_ROOT"

    if "$@" >/dev/null 2>&1; then
        success "$test_name"
        return 0
    else
        error "$test_name"
        return 1
    fi
}

# Test SSH key variable processing
test_ssh_keys() {
    section "Testing SSH Key Processing"

    # Test Cisco NX-OS SSH key processing by checking successful execution
    export CISCO_NXOS_SSH_KEY="/opt/keys/cisco-nxos-key"
    export TARGET_HOSTS="cisco-switch-01"
    export INVENTORY_FILE="$SCRIPT_DIR/mockups/inventory/production.yml"
    run_test "Cisco NX-OS SSH key variable processing" \
        bash docker-entrypoint.sh syntax-check

    # Test Cisco IOS-XE SSH key processing
    export CISCO_IOSXE_SSH_KEY="/opt/keys/cisco-iosxe-key"
    export TARGET_HOSTS="cisco-router-01"
    export INVENTORY_FILE="$SCRIPT_DIR/mockups/inventory/production.yml"
    run_test "Cisco IOS-XE SSH key variable processing" \
        bash docker-entrypoint.sh syntax-check

    # Test Opengear SSH key processing
    export OPENGEAR_SSH_KEY="/opt/keys/opengear-key"
    export TARGET_HOSTS="opengear-console-01"
    export INVENTORY_FILE="$SCRIPT_DIR/mockups/inventory/production.yml"
    run_test "Opengear SSH key variable processing" \
        bash docker-entrypoint.sh syntax-check

    # Test Metamako SSH key processing
    export METAMAKO_SSH_KEY="/opt/keys/metamako-key"
    export TARGET_HOSTS="metamako-switch-01"
    export INVENTORY_FILE="$SCRIPT_DIR/mockups/inventory/production.yml"
    run_test "Metamako SSH key variable processing" \
        bash docker-entrypoint.sh syntax-check

    # Test multiple SSH keys processing
    export CISCO_NXOS_SSH_KEY="/opt/keys/cisco-nxos-key"
    export CISCO_IOSXE_SSH_KEY="/opt/keys/cisco-iosxe-key"
    export OPENGEAR_SSH_KEY="/opt/keys/opengear-key"
    export TARGET_HOSTS="cisco-switch-01,cisco-router-01,opengear-console-01"
    export INVENTORY_FILE="$SCRIPT_DIR/mockups/inventory/production.yml"
    run_test "Multiple SSH keys processing" \
        bash docker-entrypoint.sh syntax-check
}

# Test API token processing
test_api_tokens() {
    echo -e "${BLUE}=== Testing API Token Processing ===${NC}"

    # Test FortiOS API token processing
    export FORTIOS_API_TOKEN="fortios-test-token-12345"
    export TARGET_HOSTS="fortinet-firewall-01"
    export INVENTORY_FILE="$SCRIPT_DIR/mockups/inventory/production.yml"
    run_test "FortiOS API token variable processing" \
        bash docker-entrypoint.sh syntax-check

    # Test Opengear API token processing
    export OPENGEAR_API_TOKEN="opengear-test-token-67890"
    export TARGET_HOSTS="opengear-console-01"
    export INVENTORY_FILE="$SCRIPT_DIR/mockups/inventory/production.yml"
    run_test "Opengear API token variable processing" \
        bash docker-entrypoint.sh syntax-check

    # Test multiple API tokens processing
    export FORTIOS_API_TOKEN="fortios-token"
    export OPENGEAR_API_TOKEN="opengear-token"
    export TARGET_HOSTS="fortinet-firewall-01,opengear-console-01"
    export INVENTORY_FILE="$SCRIPT_DIR/mockups/inventory/production.yml"
    run_test "Multiple API tokens processing" \
        bash docker-entrypoint.sh syntax-check

    # Test API token from file (simulate)
    mkdir -p /tmp/test-tokens
    echo "file-based-token-12345" > /tmp/test-tokens/fortios-token
    export FORTIOS_API_TOKEN="$(cat /tmp/test-tokens/fortios-token)"
    export TARGET_HOSTS="fortinet-firewall-01"
    export INVENTORY_FILE="$SCRIPT_DIR/mockups/inventory/production.yml"
    run_test "API token file reading simulation" \
        bash docker-entrypoint.sh syntax-check
    rm -rf /tmp/test-tokens
}

# Test username/password authentication
test_username_password() {
    echo -e "${BLUE}=== Testing Username/Password Authentication ===${NC}"

    # Test Cisco NX-OS credentials processing
    export CISCO_NXOS_USERNAME="nxos-admin"
    export CISCO_NXOS_PASSWORD="nxos-secret123"
    export TARGET_HOSTS="cisco-switch-01"
    export INVENTORY_FILE="$SCRIPT_DIR/mockups/inventory/production.yml"
    run_test "Cisco NX-OS username/password processing" \
        bash docker-entrypoint.sh syntax-check

    # Test FortiOS credentials processing
    export FORTIOS_USERNAME="fortios-admin"
    export FORTIOS_PASSWORD="fortios-secret456"
    export TARGET_HOSTS="fortinet-firewall-01"
    export INVENTORY_FILE="$SCRIPT_DIR/mockups/inventory/production.yml"
    run_test "FortiOS username/password processing" \
        bash docker-entrypoint.sh syntax-check

    # Test mixed authentication (SSH key + password fallback)
    export CISCO_NXOS_SSH_KEY="/opt/keys/cisco-nxos-key"
    export CISCO_NXOS_USERNAME="admin"
    export CISCO_NXOS_PASSWORD="backup-password"
    export TARGET_HOSTS="cisco-switch-01"
    export INVENTORY_FILE="$SCRIPT_DIR/mockups/inventory/production.yml"
    run_test "Mixed authentication methods processing" \
        bash docker-entrypoint.sh syntax-check
}

# Test firmware version specifications
test_firmware_versions() {
    echo -e "${BLUE}=== Testing Firmware Version Specifications ===${NC}"

    # Test Cisco NX-OS firmware processing
    export TARGET_FIRMWARE="nxos64-cs.10.4.5.M.bin"
    export TARGET_HOSTS="cisco-switch-01"
    export INVENTORY_FILE="$SCRIPT_DIR/mockups/inventory/production.yml"
    run_test "Cisco NX-OS firmware version processing" \
        bash docker-entrypoint.sh syntax-check

    # Test Cisco IOS-XE firmware processing
    export TARGET_FIRMWARE="cat9k_iosxe.17.09.04a.SPA.bin"
    export TARGET_HOSTS="cisco-router-01"
    export INVENTORY_FILE="$SCRIPT_DIR/mockups/inventory/production.yml"
    run_test "Cisco IOS-XE firmware version processing" \
        bash docker-entrypoint.sh syntax-check

    # Test FortiOS firmware processing
    export TARGET_FIRMWARE="FGT_VM64_KVM-v7.2.5-build1517-FORTINET.out"
    export TARGET_HOSTS="fortinet-firewall-01"
    export INVENTORY_FILE="$SCRIPT_DIR/mockups/inventory/production.yml"
    run_test "FortiOS firmware version processing" \
        bash docker-entrypoint.sh syntax-check

    # Test Opengear firmware processing
    export TARGET_FIRMWARE="cm71xx-5.2.4.flash"
    export TARGET_HOSTS="opengear-console-01"
    export INVENTORY_FILE="$SCRIPT_DIR/mockups/inventory/production.yml"
    run_test "Opengear firmware version processing" \
        bash docker-entrypoint.sh syntax-check

    # Test Metamako MOS firmware processing
    export TARGET_FIRMWARE="mos-0.39.9.iso"
    export TARGET_HOSTS="metamako-switch-01"
    export INVENTORY_FILE="$SCRIPT_DIR/mockups/inventory/production.yml"
    run_test "Metamako MOS firmware version processing" \
        bash docker-entrypoint.sh syntax-check
}

# Test upgrade phases and configurations
test_upgrade_phases() {
    echo -e "${BLUE}=== Testing Upgrade Phases and Configurations ===${NC}"

    # Test loading phase
    run_test "Upgrade phase: loading" \
        bash -c 'export UPGRADE_PHASE="loading" && \
                 export TARGET_HOSTS="cisco-switch-01" && \
                 export INVENTORY_FILE="tests/container-tests/mockups/inventory/production.yml" && \
                 bash docker-entrypoint.sh syntax-check 2>&1 | grep -q "upgrade_phase=loading"'

    # Test installation phase
    run_test "Upgrade phase: installation" \
        bash -c 'export UPGRADE_PHASE="installation" && \
                 export TARGET_HOSTS="cisco-switch-01" && \
                 export INVENTORY_FILE="tests/container-tests/mockups/inventory/production.yml" && \
                 bash docker-entrypoint.sh syntax-check 2>&1 | grep -q "upgrade_phase=installation"'

    # Test validation phase
    run_test "Upgrade phase: validation" \
        bash -c 'export UPGRADE_PHASE="validation" && \
                 export TARGET_HOSTS="cisco-switch-01" && \
                 export INVENTORY_FILE="tests/container-tests/mockups/inventory/production.yml" && \
                 bash docker-entrypoint.sh syntax-check 2>&1 | grep -q "upgrade_phase=validation"'

    # Test rollback phase
    run_test "Upgrade phase: rollback" \
        bash -c 'export UPGRADE_PHASE="rollback" && \
                 export TARGET_HOSTS="cisco-switch-01" && \
                 export INVENTORY_FILE="tests/container-tests/mockups/inventory/production.yml" && \
                 bash docker-entrypoint.sh syntax-check 2>&1 | grep -q "upgrade_phase=rollback"'

    # Test maintenance window
    run_test "Maintenance window configuration" \
        bash -c 'export MAINTENANCE_WINDOW="true" && \
                 export TARGET_HOSTS="cisco-switch-01" && \
                 export INVENTORY_FILE="tests/container-tests/mockups/inventory/production.yml" && \
                 bash docker-entrypoint.sh syntax-check 2>&1 | grep -q "maintenance_window=true"'
}

# Test EPLD upgrade configurations
test_epld_configurations() {
    echo -e "${BLUE}=== Testing EPLD Upgrade Configurations ===${NC}"

    # Test EPLD upgrade enabled
    run_test "EPLD upgrade enabled" \
        bash -c 'export ENABLE_EPLD_UPGRADE="true" && \
                 export TARGET_HOSTS="cisco-switch-01" && \
                 export INVENTORY_FILE="tests/container-tests/mockups/inventory/production.yml" && \
                 bash docker-entrypoint.sh syntax-check 2>&1 | grep -q "enable_epld_upgrade=true"'

    # Test EPLD image specification
    run_test "EPLD image specification" \
        bash -c 'export TARGET_EPLD_IMAGE="n9000-epld.9.3.16.M.img" && \
                 export TARGET_HOSTS="cisco-switch-01" && \
                 export INVENTORY_FILE="tests/container-tests/mockups/inventory/production.yml" && \
                 bash docker-entrypoint.sh syntax-check 2>&1 | grep -q "target_epld_image=n9000-epld.9.3.16.M.img"'

    # Test disruptive EPLD upgrade
    run_test "Disruptive EPLD upgrade" \
        bash -c 'export ALLOW_DISRUPTIVE_EPLD="true" && \
                 export TARGET_HOSTS="cisco-switch-01" && \
                 export INVENTORY_FILE="tests/container-tests/mockups/inventory/production.yml" && \
                 bash docker-entrypoint.sh syntax-check 2>&1 | grep -q "allow_disruptive_epld=true"'

    # Test EPLD upgrade timeout
    run_test "EPLD upgrade timeout" \
        bash -c 'export EPLD_UPGRADE_TIMEOUT="7200" && \
                 export TARGET_HOSTS="cisco-switch-01" && \
                 export INVENTORY_FILE="tests/container-tests/mockups/inventory/production.yml" && \
                 bash docker-entrypoint.sh syntax-check 2>&1 | grep -q "epld_upgrade_timeout=7200"'
}

# Test FortiOS multi-step upgrade
test_fortios_multistep() {
    echo -e "${BLUE}=== Testing FortiOS Multi-Step Upgrade ===${NC}"

    # Test multi-step upgrade enabled
    run_test "Multi-step upgrade required" \
        bash -c 'export MULTI_STEP_UPGRADE_REQUIRED="true" && \
                 export TARGET_HOSTS="fortinet-firewall-01" && \
                 export INVENTORY_FILE="tests/container-tests/mockups/inventory/production.yml" && \
                 bash docker-entrypoint.sh syntax-check 2>&1 | grep -q "multi_step_upgrade_required=true"'

    # Test upgrade path specification
    run_test "Multi-step upgrade path" \
        bash -c 'export UPGRADE_PATH="6.4.8,7.0.12,7.2.5" && \
                 export TARGET_HOSTS="fortinet-firewall-01" && \
                 export INVENTORY_FILE="tests/container-tests/mockups/inventory/production.yml" && \
                 bash docker-entrypoint.sh syntax-check 2>&1 | grep -q "upgrade_path=6.4.8,7.0.12,7.2.5"'
}

# Test additional configurations
test_additional_configurations() {
    echo -e "${BLUE}=== Testing Additional Configurations ===${NC}"

    # Test image server credentials
    run_test "Image server credentials" \
        bash -c 'export IMAGE_SERVER_USERNAME="ftp-user" && \
                 export IMAGE_SERVER_PASSWORD="ftp-pass123" && \
                 export TARGET_HOSTS="cisco-switch-01" && \
                 export INVENTORY_FILE="tests/container-tests/mockups/inventory/production.yml" && \
                 bash docker-entrypoint.sh syntax-check 2>&1 | grep -q "vault_image_server_username=ftp-user.*vault_image_server_password=ftp-pass123"'

    # Test SNMP community
    run_test "SNMP community configuration" \
        bash -c 'export SNMP_COMMUNITY="private-community" && \
                 export TARGET_HOSTS="cisco-switch-01" && \
                 export INVENTORY_FILE="tests/container-tests/mockups/inventory/production.yml" && \
                 bash docker-entrypoint.sh syntax-check 2>&1 | grep -q "vault_snmp_community=private-community"'

    # Test firmware base path
    run_test "Firmware base path" \
        bash -c 'export FIRMWARE_BASE_PATH="/custom/firmware/path" && \
                 export TARGET_HOSTS="cisco-switch-01" && \
                 export INVENTORY_FILE="tests/container-tests/mockups/inventory/production.yml" && \
                 bash docker-entrypoint.sh syntax-check 2>&1 | grep -q "firmware_base_path=/custom/firmware/path"'

    # Test backup base path
    run_test "Backup base path" \
        bash -c 'export BACKUP_BASE_PATH="/custom/backup/path" && \
                 export TARGET_HOSTS="cisco-switch-01" && \
                 export INVENTORY_FILE="tests/container-tests/mockups/inventory/production.yml" && \
                 bash docker-entrypoint.sh syntax-check 2>&1 | grep -q "backup_base_path=/custom/backup/path"'
}

# Test complex scenarios
test_complex_scenarios() {
    echo -e "${BLUE}=== Testing Complex Real-World Scenarios ===${NC}"

    # Test comprehensive multi-platform scenario
    run_test "Multi-platform comprehensive scenario" \
        bash -c 'export CISCO_NXOS_SSH_KEY="/opt/keys/cisco-nxos-key" && \
                 export CISCO_IOSXE_USERNAME="admin" && \
                 export CISCO_IOSXE_PASSWORD="cisco123" && \
                 export FORTIOS_API_TOKEN="fortios-token-12345" && \
                 export OPENGEAR_SSH_KEY="/opt/keys/opengear-key" && \
                 export METAMAKO_SSH_KEY="/opt/keys/metamako-key" && \
                 export TARGET_HOSTS="all" && \
                 export TARGET_FIRMWARE="auto-detect" && \
                 export UPGRADE_PHASE="validation" && \
                 export IMAGE_SERVER_USERNAME="ftp-user" && \
                 export IMAGE_SERVER_PASSWORD="ftp-pass" && \
                 export SNMP_COMMUNITY="monitoring" && \
                 export INVENTORY_FILE="tests/container-tests/mockups/inventory/production.yml" && \
                 bash docker-entrypoint.sh syntax-check >/dev/null 2>&1'

    # Test HFT scenario (Metamako + Cisco)
    run_test "HFT scenario (Metamako + Cisco)" \
        bash -c 'export METAMAKO_SSH_KEY="/opt/keys/metamako-key" && \
                 export CISCO_NXOS_SSH_KEY="/opt/keys/cisco-nxos-key" && \
                 export TARGET_HOSTS="metamako-switch-01,cisco-switch-01" && \
                 export MAINTENANCE_WINDOW="true" && \
                 export UPGRADE_PHASE="validation" && \
                 export INVENTORY_FILE="tests/container-tests/mockups/inventory/production.yml" && \
                 bash docker-entrypoint.sh syntax-check >/dev/null 2>&1'
}

# Main execution
main() {
    echo -e "${BLUE}🔧 SPECIFIC FUNCTIONALITY TESTING${NC}"
    echo "=================================="
    echo "Testing SSH keys, API tokens, firmware versions, and detailed configurations"
    echo ""

    test_ssh_keys
    test_api_tokens
    test_username_password
    test_firmware_versions
    test_upgrade_phases
    test_epld_configurations
    test_fortios_multistep
    test_additional_configurations
    test_complex_scenarios

    echo ""
    echo "=================================="
    echo "🎯 SPECIFIC FUNCTIONALITY TEST RESULTS"
    echo "=================================="
    echo "Tests Run: $TESTS_RUN"
    echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}🎉 All specific functionality tests passed!${NC}"
        echo -e "${GREEN}SSH keys, API tokens, firmware versions, and configurations are working correctly.${NC}"
        exit 0
    else
        echo -e "${RED}❌ Some specific functionality tests failed.${NC}"
        exit 1
    fi
}

main "$@"