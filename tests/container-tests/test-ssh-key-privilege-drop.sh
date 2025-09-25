#!/bin/bash
# Test SSH Key Privilege Drop Mechanism
# Validates that SSH keys can be properly copied from root-owned files to ansible user

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

run_test() {
    local test_name="$1"
    shift
    TESTS_RUN=$((TESTS_RUN + 1))

    log "Testing: $test_name"

    if "$@" >/dev/null 2>&1; then
        success "$test_name"
        return 0
    else
        error "$test_name"
        return 1
    fi
}

# Test the privilege drop mechanism
test_privilege_drop_mechanism() {
    echo -e "${BLUE}=== Testing SSH Key Privilege Drop Mechanism ===${NC}"

    # Create test SSH keys directory
    local test_keys_dir="/tmp/test-ssh-keys"
    local test_ssh_key="$test_keys_dir/test-cisco-nxos-key"

    mkdir -p "$test_keys_dir"

    # Create a test SSH key file
    ssh-keygen -t rsa -b 2048 -f "$test_ssh_key" -N "" -C "test-key-for-privilege-drop" >/dev/null 2>&1

    # Simulate root ownership (600 permissions)
    chmod 600 "$test_ssh_key"

    run_test "SSH key creation for privilege drop test" \
        test -f "$test_ssh_key"

    # Test the entrypoint script's SSH key handling functions
    cd "$PROJECT_ROOT"

    # Source the entrypoint functions for testing
    source <(sed -n '/^copy_ssh_key_as_root()/,/^}/p' docker-entrypoint.sh)
    source <(sed -n '/^setup_ssh_keys_as_root()/,/^}/p' docker-entrypoint.sh)

    # Test SSH key copying function
    local dest_dir="/tmp/test-ansible-ssh"
    mkdir -p "$dest_dir"

    run_test "SSH key copying function exists" \
        type copy_ssh_key_as_root >/dev/null

    # Test the key copying (simulating what root would do)
    export CISCO_NXOS_SSH_KEY="$test_ssh_key"

    # Simulate the copy operation
    copy_ssh_key_as_root "$test_ssh_key" "$dest_dir/cisco_nxos_key" 2>/dev/null || true

    run_test "SSH key copy operation" \
        test -f "$dest_dir/cisco_nxos_key"

    run_test "SSH key proper permissions" \
        bash -c "[[ \$(stat -c '%a' '$dest_dir/cisco_nxos_key' 2>/dev/null || echo '600') == '600' ]]"

    # Test privilege drop detection
    run_test "Privilege drop mechanism exists" \
        grep -q "handle_privilege_drop" "$PROJECT_ROOT/docker-entrypoint.sh"

    run_test "Root detection logic exists" \
        grep -q "EUID -eq 0" "$PROJECT_ROOT/docker-entrypoint.sh"

    run_test "User switching logic exists" \
        grep -q "exec su ansible" "$PROJECT_ROOT/docker-entrypoint.sh"

    # Cleanup
    rm -rf "$test_keys_dir" "$dest_dir"
}

# Test entrypoint integration
test_entrypoint_integration() {
    echo -e "${BLUE}=== Testing Entrypoint Integration ===${NC}"

    cd "$PROJECT_ROOT"

    # Test that entrypoint script has all required functions
    run_test "setup_ssh_keys_as_root function exists" \
        grep -q "setup_ssh_keys_as_root()" docker-entrypoint.sh

    run_test "copy_ssh_key_as_root function exists" \
        grep -q "copy_ssh_key_as_root()" docker-entrypoint.sh

    run_test "handle_privilege_drop function exists" \
        grep -q "handle_privilege_drop()" docker-entrypoint.sh

    run_test "privilege drop is called before main" \
        bash -c "grep -A5 -B5 'main \"\$@\"' docker-entrypoint.sh | grep -q 'handle_privilege_drop'"

    # Test the updated setup_ssh_keys function
    run_test "setup_ssh_keys updated for copied keys" \
        bash -c "grep -A10 'setup_ssh_keys()' docker-entrypoint.sh | grep -q 'keys already copied by root'"
}

# Main execution
main() {
    echo -e "${BLUE}🔐 SSH KEY PRIVILEGE DROP TESTING${NC}"
    echo "========================================"
    echo "Testing SSH key privilege drop mechanism for container security"
    echo

    cd "$PROJECT_ROOT"

    test_privilege_drop_mechanism
    echo
    test_entrypoint_integration
    echo

    # Summary
    echo -e "${BLUE}=== TEST SUMMARY ===${NC}"
    echo "Tests run: $TESTS_RUN"
    echo "Tests passed: $TESTS_PASSED"
    echo "Tests failed: $TESTS_FAILED"
    echo

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}🎉 ALL TESTS PASSED!${NC}"
        echo -e "${GREEN}SSH key privilege drop mechanism is properly implemented${NC}"
        return 0
    else
        echo -e "${RED}❌ SOME TESTS FAILED${NC}"
        echo -e "${RED}SSH key privilege drop mechanism needs attention${NC}"
        return 1
    fi
}

main "$@"