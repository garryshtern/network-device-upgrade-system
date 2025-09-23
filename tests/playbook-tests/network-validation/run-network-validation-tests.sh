#!/bin/bash
# Network Validation Playbook Test Runner
# Tests network connectivity and configuration validation functionality

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

echo "🌐 Running Network Validation Playbook Tests..."
echo "Project Root: $PROJECT_ROOT"
echo "Test Directory: $SCRIPT_DIR"

# Change to project root for consistent paths
cd "$PROJECT_ROOT"

# Create test inventory
cat > "$SCRIPT_DIR/test-inventory" << EOF
[network_validation_devices]
localhost ansible_connection=local

[network_validation_devices:vars]
ansible_network_os=cisco.nxos.nxos
device_platform=cisco_nxos
EOF

echo "📋 Test Configuration:"
echo "- Inventory: $SCRIPT_DIR/test-inventory"
echo "- Test playbook: $SCRIPT_DIR/test-network-validation.yml"
echo ""

# Run network validation tests
echo "🚀 Executing network validation playbook tests..."
if ansible-playbook \
    -i "$SCRIPT_DIR/test-inventory" \
    "$SCRIPT_DIR/test-network-validation.yml" \
    --extra-vars "test_mode=true" \
    -v; then
    echo ""
    echo "✅ Network Validation Playbook Tests: PASSED"
    echo ""
    echo "📊 Test Summary:"
    echo "- Network validation initialization: ✅"
    echo "- Connectivity tests simulation: ✅"
    echo "- Configuration validation: ✅"
    echo "- Report generation: ✅"
    echo "- Validation completeness: ✅"
    echo ""
    echo "Status: Ready for production network validation"
else
    echo ""
    echo "❌ Network Validation Playbook Tests: FAILED"
    echo ""
    echo "📋 Common Issues:"
    echo "- Check ansible and required collections are installed"
    echo "- Verify project directory structure"
    echo "- Ensure test inventory is accessible"
    echo ""
    exit 1
fi

# Cleanup
rm -f "$SCRIPT_DIR/test-inventory"

echo "🧹 Test cleanup completed"
echo "✅ Network validation testing: COMPLETE"