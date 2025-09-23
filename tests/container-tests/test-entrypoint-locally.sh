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

# Extract just the function from the script and test it
bash -c "
source <(sed -n '/^build_ansible_options()/,/^}/p' '$ENTRYPOINT_SCRIPT')
result=\$(build_ansible_options)
ansible_opts=\"\${result%|*}\"
extra_vars=\"\${result#*|}\"

echo \"Ansible options: \$ansible_opts\"
echo \"Extra variables: \$extra_vars\"

# Check if our variables are properly included
if [[ \"\$extra_vars\" == *\"vault_cisco_nxos_ssh_key=/opt/keys/cisco-key\"* ]]; then
    echo \"✅ SSH key variable correctly processed\"
else
    echo \"❌ SSH key variable missing or incorrect\"
fi

if [[ \"\$extra_vars\" == *\"vault_cisco_iosxe_username=admin\"* ]]; then
    echo \"✅ Username variable correctly processed\"
else
    echo \"❌ Username variable missing or incorrect\"
fi

if [[ \"\$extra_vars\" == *\"vault_fortios_api_token=fortios-token-12345\"* ]]; then
    echo \"✅ API token variable correctly processed\"
else
    echo \"❌ API token variable missing or incorrect\"
fi

if [[ \"\$extra_vars\" == *\"target_hosts=cisco-switch-01\"* ]]; then
    echo \"✅ Target hosts variable correctly processed\"
else
    echo \"❌ Target hosts variable missing or incorrect\"
fi
"

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