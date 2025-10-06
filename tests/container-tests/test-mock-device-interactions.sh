#!/bin/bash
# Mock Device Interaction Testing
# Tests container interactions with mock devices simulating real network scenarios

set -euo pipefail

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

# Mock device interaction test
run_mock_device_test() {
    local test_name="$1"
    local platform="$2"
    local device_host="$3"
    local expected_result="$4"
    shift 4
    local extra_args=("$@")

    TESTS_RUN=$((TESTS_RUN + 1))
    log "Running mock device test: $test_name (platform: $platform, device: $device_host)"

    # Create temporary files for capturing output
    local stdout_file="/tmp/mock-device-test-stdout-$$"
    local stderr_file="/tmp/mock-device-test-stderr-$$"
    local exit_code=0

    # Build docker command with platform-specific configuration
    local docker_cmd=(
        docker run --rm
        -v "$MOCKUP_DIR/inventory:/opt/inventory:ro"
        -v "$MOCKUP_DIR/keys:/opt/keys:ro"
        -v "$MOCKUP_DIR/firmware:/opt/firmware:ro"
        -e ANSIBLE_INVENTORY="/opt/inventory/production.yml"
        -e TARGET_HOSTS="$device_host"
    )

    # Add platform-specific authentication
    case "$platform" in
        "cisco_nxos")
            docker_cmd+=(-e CISCO_NXOS_SSH_KEY="/opt/keys/cisco-nxos-key")
            ;;
        "cisco_iosxe")
            docker_cmd+=(-e CISCO_IOSXE_SSH_KEY="/opt/keys/cisco-iosxe-key")
            ;;
        "fortios")
            docker_cmd+=(-e FORTIOS_API_TOKEN="$(cat "$MOCKUP_DIR/tokens/fortios-token")")
            ;;
        "opengear")
            docker_cmd+=(-e OPENGEAR_SSH_KEY="/opt/keys/opengear-key")
            docker_cmd+=(-e OPENGEAR_API_TOKEN="$(cat "$MOCKUP_DIR/tokens/opengear-token")")
            ;;
        "metamako")
            docker_cmd+=(-e METAMAKO_SSH_KEY="/opt/keys/metamako-key")
            ;;
    esac

    # Add extra arguments
    docker_cmd+=("${extra_args[@]}")
    docker_cmd+=("$CONTAINER_IMAGE" "dry-run")

    # Run the test
    if "${docker_cmd[@]}" > "$stdout_file" 2> "$stderr_file"; then
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
        echo "Platform: $platform, Device: $device_host"
        echo "Command: ${docker_cmd[*]}"
        echo "STDOUT:"
        cat "$stdout_file" | head -10
        echo "STDERR:"
        cat "$stderr_file" | head -10
    fi

    # Cleanup
    rm -f "$stdout_file" "$stderr_file"
}

# Test Cisco NX-OS mock device interactions
test_cisco_nxos_devices() {
    log "=== Testing Cisco NX-OS Mock Device Interactions ==="

    # Test basic device connection
    run_mock_device_test "Basic NX-OS connection" "cisco_nxos" "cisco-switch-01" "success"

    # Test firmware upgrade simulation
    run_mock_device_test "NX-OS firmware upgrade" "cisco_nxos" "cisco-switch-01" "success" \
        -e TARGET_FIRMWARE="nxos64-cs.10.4.5.M.bin" \
        -e UPGRADE_PHASE="loading"

    # Test EPLD upgrade simulation
    run_mock_device_test "NX-OS EPLD upgrade" "cisco_nxos" "cisco-switch-01" "success" \
        -e ENABLE_EPLD_UPGRADE="true" \
        -e TARGET_EPLD_IMAGE="n9000-epld.9.3.16.M.img" \
        -e UPGRADE_PHASE="validation"

    # Test multiple NX-OS devices
    run_mock_device_test "Multiple NX-OS devices" "cisco_nxos" "cisco-switch-01,cisco-switch-02" "success" \
        -e TARGET_FIRMWARE="nxos64-cs.10.4.5.M.bin"

    # Test maintenance window scenario
    run_mock_device_test "NX-OS maintenance window" "cisco_nxos" "cisco-switch-01" "success" \
        -e MAINTENANCE_WINDOW="true" \
        -e UPGRADE_PHASE="installation"
}

# Test Cisco IOS-XE mock device interactions
test_cisco_iosxe_devices() {
    log "=== Testing Cisco IOS-XE Mock Device Interactions ==="

    # Test basic device connection
    run_mock_device_test "Basic IOS-XE connection" "cisco_iosxe" "cisco-router-01" "success"

    # Test firmware upgrade simulation
    run_mock_device_test "IOS-XE firmware upgrade" "cisco_iosxe" "cisco-router-01" "success" \
        -e TARGET_FIRMWARE="cat9k_iosxe.17.09.04a.SPA.bin" \
        -e UPGRADE_PHASE="loading"

    # Test dual authentication (SSH key + username/password fallback)
    run_mock_device_test "IOS-XE dual auth" "cisco_iosxe" "cisco-router-01" "success" \
        -e CISCO_IOSXE_SSH_KEY="/opt/keys/cisco-iosxe-key" \
        -e CISCO_IOSXE_USERNAME="admin" \
        -e CISCO_IOSXE_PASSWORD="cisco123"

    # Test rollback scenario
    run_mock_device_test "IOS-XE rollback" "cisco_iosxe" "cisco-router-01" "success" \
        -e UPGRADE_PHASE="rollback" \
        -e MAINTENANCE_WINDOW="true"
}

# Test FortiOS mock device interactions
test_fortios_devices() {
    log "=== Testing FortiOS Mock Device Interactions ==="

    # Test basic API connection
    run_mock_device_test "Basic FortiOS API connection" "fortios" "fortinet-firewall-01" "success"

    # Test single-step upgrade
    run_mock_device_test "FortiOS single-step upgrade" "fortios" "fortinet-firewall-01" "success" \
        -e TARGET_FIRMWARE="FGT_VM64_KVM-v7.2.5-build1517-FORTINET.out" \
        -e UPGRADE_PHASE="loading"

    # Test multi-step upgrade scenario
    run_mock_device_test "FortiOS multi-step upgrade" "fortios" "fortinet-firewall-01" "success" \
        -e MULTI_STEP_UPGRADE_REQUIRED="true" \
        -e UPGRADE_PATH="6.4.8,7.0.12,7.2.5" \
        -e TARGET_FIRMWARE="7.2.5"

    # Test HA cluster scenario
    run_mock_device_test "FortiOS HA cluster" "fortios" "fortinet-firewall-01,fortinet-firewall-02" "success" \
        -e MAINTENANCE_WINDOW="true" \
        -e TARGET_FIRMWARE="FGT_VM64_KVM-v7.2.5-build1517-FORTINET.out"

    # Test API token validation
    run_mock_device_test "FortiOS API validation" "fortios" "fortinet-firewall-01" "success" \
        -e UPGRADE_PHASE="validation"
}

# Test Opengear mock device interactions
test_opengear_devices() {
    log "=== Testing Opengear Mock Device Interactions ==="

    # Test legacy device (CM7100) with SSH
    run_mock_device_test "Opengear legacy SSH" "opengear" "opengear-console-01" "success" \
        -e TARGET_FIRMWARE="cm71xx-5.2.4.flash"

    # Test modern device with API
    run_mock_device_test "Opengear modern API" "opengear" "opengear-console-02" "success" \
        -e TARGET_FIRMWARE="console_manager-25.07.0-production-signed.raucb"

    # Test dual authentication (SSH + API)
    run_mock_device_test "Opengear dual auth" "opengear" "opengear-console-01" "success" \
        -e OPENGEAR_SSH_KEY="/opt/keys/opengear-key" \
        -e OPENGEAR_API_TOKEN="$(cat "$MOCKUP_DIR/tokens/opengear-token")"

    # Test console server specific functionality
    run_mock_device_test "Opengear console management" "opengear" "opengear-console-01,opengear-console-02" "success" \
        -e UPGRADE_PHASE="validation"
}

# Test Metamako mock device interactions
test_metamako_devices() {
    log "=== Testing Metamako MOS Mock Device Interactions ==="

    # Test basic MOS connection
    run_mock_device_test "Basic Metamako connection" "metamako" "metamako-switch-01" "success"

    # Test MOS firmware upgrade
    run_mock_device_test "Metamako MOS upgrade" "metamako" "metamako-switch-01" "success" \
        -e TARGET_FIRMWARE="mos-0.39.9.iso" \
        -e UPGRADE_PHASE="loading"

    # Test application installation
    run_mock_device_test "Metamako application install" "metamako" "metamako-switch-01" "success" \
        -e ENABLE_APPLICATION_INSTALLATION="true" \
        -e METAWATCH_PACKAGE="metawatch-3.2.0-1967.x86_64.rpm" \
        -e METAMUX_PACKAGE="metamux-2.2.3-1849.x86_64.rpm"

    # Test low-latency validation
    run_mock_device_test "Metamako latency validation" "metamako" "metamako-switch-01,metamako-switch-02" "success" \
        -e UPGRADE_PHASE="validation"

    # Test complete system upgrade
    run_mock_device_test "Metamako complete upgrade" "metamako" "metamako-switch-01" "success" \
        -e TARGET_FIRMWARE="mos-0.39.9.iso" \
        -e UPGRADE_PHASE="full" \
        -e MAINTENANCE_WINDOW="true"
}

# Test cross-platform scenarios
test_cross_platform_scenarios() {
    log "=== Testing Cross-Platform Mock Device Scenarios ==="

    # Test mixed platform upgrade
    run_mock_device_test "Mixed platform upgrade" "cisco_nxos" "cisco-switch-01,fortinet-firewall-01,opengear-console-01" "success" \
        -e CISCO_NXOS_SSH_KEY="/opt/keys/cisco-nxos-key" \
        -e FORTIOS_API_TOKEN="$(cat "$MOCKUP_DIR/tokens/fortios-token")" \
        -e OPENGEAR_SSH_KEY="/opt/keys/opengear-key" \
        -e UPGRADE_PHASE="validation"

    # Test datacenter-wide scenario
    run_mock_device_test "Datacenter-wide scenario" "cisco_nxos" "all" "success" \
        -e CISCO_NXOS_SSH_KEY="/opt/keys/cisco-nxos-key" \
        -e CISCO_IOSXE_SSH_KEY="/opt/keys/cisco-iosxe-key" \
        -e FORTIOS_API_TOKEN="$(cat "$MOCKUP_DIR/tokens/fortios-token")" \
        -e OPENGEAR_SSH_KEY="/opt/keys/opengear-key" \
        -e METAMAKO_SSH_KEY="/opt/keys/metamako-key" \
        -e UPGRADE_PHASE="validation"

    # Test network segmentation scenario
    run_mock_device_test "Network segmentation" "cisco_nxos" "cisco-switch-01,cisco-router-01" "success" \
        -e CISCO_NXOS_SSH_KEY="/opt/keys/cisco-nxos-key" \
        -e CISCO_IOSXE_SSH_KEY="/opt/keys/cisco-iosxe-key" \
        -e UPGRADE_PHASE="loading"

    # Test high-frequency trading scenario (Metamako + Cisco)
    run_mock_device_test "HFT scenario" "metamako" "metamako-switch-01,cisco-switch-01" "success" \
        -e METAMAKO_SSH_KEY="/opt/keys/metamako-key" \
        -e CISCO_NXOS_SSH_KEY="/opt/keys/cisco-nxos-key" \
        -e UPGRADE_PHASE="validation" \
        -e MAINTENANCE_WINDOW="true"
}

# Setup mock tokens and keys
setup_mock_tokens() {
    log "Setting up mock tokens and SSH keys..."

    mkdir -p "$MOCKUP_DIR/tokens"

    # Create mock API tokens only if they don't exist (shared test-common.sh may have created them)
    if [[ ! -f "$MOCKUP_DIR/tokens/fortios-token" ]]; then
        echo "mock-fortios-api-token-12345678" > "$MOCKUP_DIR/tokens/fortios-token"
        chmod 600 "$MOCKUP_DIR/tokens/fortios-token"
    fi
    if [[ ! -f "$MOCKUP_DIR/tokens/opengear-token" ]]; then
        echo "mock-opengear-api-token-87654321" > "$MOCKUP_DIR/tokens/opengear-token"
        chmod 600 "$MOCKUP_DIR/tokens/opengear-token"
    fi

    # Set permissions on SSH keys
    chmod 600 "$MOCKUP_DIR/keys"/* 2>/dev/null || true

    success "Mock tokens and keys setup completed"
}

# Main execution
main() {
    echo "🔌 Mock Device Interaction Testing Suite"
    echo "========================================"
    echo "Container Image: $CONTAINER_IMAGE"
    echo "Testing container interactions with mock network devices"
    echo ""

    # Setup
    setup_mock_tokens

    # Platform-specific tests
    test_cisco_nxos_devices
    test_cisco_iosxe_devices
    test_fortios_devices
    test_opengear_devices
    test_metamako_devices

    # Cross-platform scenarios
    test_cross_platform_scenarios

    # Results
    echo ""
    echo "========================================"
    echo "🎯 Mock Device Interaction Test Results"
    echo "========================================"
    echo "Tests Run: $TESTS_RUN"
    echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}🎉 All mock device interaction tests passed!${NC}"
        echo -e "${GREEN}Container successfully interacts with all platform mock devices.${NC}"
        exit 0
    else
        echo -e "${RED}❌ Some mock device interaction tests failed.${NC}"
        exit 1
    fi
}

# Execute main function
main "$@"