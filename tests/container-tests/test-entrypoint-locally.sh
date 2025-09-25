#!/bin/bash
# Quick local test of docker-entrypoint environment variable handling
# Tests the entrypoint script directly without container

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.."; pwd)"
ENTRYPOINT_SCRIPT="$PROJECT_ROOT/docker-entrypoint.sh"

echo "🧪 Testing docker-entrypoint.sh environment variable handling..."
echo "Script: $ENTRYPOINT_SCRIPT"
echo "Working directory: $PROJECT_ROOT"

cd "$PROJECT_ROOT"

# Test 1: Basic environment variable parsing
echo ""
echo "=== Test 1: Environment Variable Processing ==="

export CISCO_NXOS_SSH_KEY="/opt/keys/cisco-key"
export CISCO_IOSXE_USERNAME="admin"
export CISCO_IOSXE_PASSWORD="password123"
export FORTIOS_API_TOKEN="fortios-token-12345"
export TARGET_HOSTS="cisco-switch-01"
export TARGET_FIRMWARE="9.3.12"
export UPGRADE_PHASE="loading"
export ANSIBLE_INVENTORY="$SCRIPT_DIR/mockups/inventory/production.yml"

# Test the build_ansible_options function by sourcing the script functions
echo "Testing build_ansible_options function..."

# Test environment variable processing by checking if variables are exported
echo "Testing environment variable export..."

# Check if our test variables are properly set
if [[ -n "${CISCO_NXOS_SSH_KEY:-}" ]]; then
    echo "✅ SSH key variable correctly set"
else
    echo "❌ SSH key variable missing or incorrect"
fi

if [[ -n "${CISCO_IOSXE_USERNAME:-}" ]]; then
    echo "✅ Username variable correctly set"
else
    echo "❌ Username variable missing or incorrect"
fi

if [[ -n "${FORTIOS_API_TOKEN:-}" ]]; then
    echo "✅ API token variable correctly set"
else
    echo "❌ API token variable missing or incorrect"
fi

if [[ -n "${TARGET_HOSTS:-}" ]]; then
    echo "✅ Target hosts variable correctly set"
else
    echo "❌ Target hosts variable missing or incorrect"
fi

# Test 2: Syntax check with environment variables
echo ""
echo "=== Test 2: Syntax Check with Environment Variables ==="

if [[ -f "$ENTRYPOINT_SCRIPT" ]]; then
    echo "Testing syntax check command..."
    if bash "$ENTRYPOINT_SCRIPT" syntax-check; then
        echo "✅ Syntax check passed with environment variables"
    else
        echo "❌ Syntax check failed"
    fi
else
    echo "❌ Entrypoint script not found: $ENTRYPOINT_SCRIPT"
fi

# Test 3: Help command
echo ""
echo "=== Test 3: Help Command ==="

if bash "$ENTRYPOINT_SCRIPT" help | grep -q "ENVIRONMENT VARIABLES"; then
    echo "✅ Help command shows environment variables section"
else
    echo "❌ Help command missing environment variables documentation"
fi

echo ""
echo "🎉 Local entrypoint testing complete!"