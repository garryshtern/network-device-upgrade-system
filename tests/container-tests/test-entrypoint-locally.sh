#!/bin/bash
# Quick local test of docker-entrypoint environment variable handling
# Tests the entrypoint script directly without container

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.."; pwd)"
ENTRYPOINT_SCRIPT="$PROJECT_ROOT/docker-entrypoint.sh"

# Source the shared test library
source "$SCRIPT_DIR/lib/test-common.sh"

echo "🧪 Testing docker-entrypoint.sh environment variable handling..."
echo "Script: $ENTRYPOINT_SCRIPT"
echo "Working directory: $PROJECT_ROOT"

cd "$PROJECT_ROOT"

# Set up test environment variables
export CISCO_NXOS_SSH_KEY="/opt/keys/cisco-key"
export CISCO_IOSXE_USERNAME="admin"
export CISCO_IOSXE_PASSWORD="password123"
export FORTIOS_API_TOKEN="fortios-token-12345"
export TARGET_HOSTS="cisco-switch-01"
export TARGET_FIRMWARE="9.3.12"
export UPGRADE_PHASE="loading"
export INVENTORY_FILE="$SCRIPT_DIR/mockups/inventory/production.yml"

section "Environment Variable Processing"

# Test environment variable setup
run_test "SSH key variable set" test -n "${CISCO_NXOS_SSH_KEY:-}"
run_test "Username variable set" test -n "${CISCO_IOSXE_USERNAME:-}"
run_test "API token variable set" test -n "${FORTIOS_API_TOKEN:-}"
run_test "Target hosts variable set" test -n "${TARGET_HOSTS:-}"

section "Syntax Check with Environment Variables"

run_test "Entrypoint script exists" test -f "$ENTRYPOINT_SCRIPT"
run_test "Syntax check with env vars" bash "$ENTRYPOINT_SCRIPT" syntax-check

section "Help Command"

run_test "Help shows env vars section" bash -c "bash '$ENTRYPOINT_SCRIPT' help | grep -q 'ENVIRONMENT VARIABLES'"

# Print summary
print_test_summary "Local Entrypoint Tests"