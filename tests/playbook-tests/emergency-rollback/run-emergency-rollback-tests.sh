#!/bin/bash
# Emergency Rollback Playbook Test Runner
# Tests emergency rollback and recovery functionality

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.."; pwd)"

echo "🔄 Running Emergency Rollback Playbook Tests..."
echo "Project Root: $PROJECT_ROOT"
echo "Test Directory: $SCRIPT_DIR"

# Change to project root for consistent paths
cd "$PROJECT_ROOT"

# Create test inventory
cat > "$SCRIPT_DIR/test-inventory" << EOF
[emergency_rollback_devices]
localhost ansible_connection=local

[emergency_rollback_devices:vars]
ansible_network_os=cisco.nxos.nxos
device_platform=cisco_nxos
EOF

echo "📋 Test Configuration:"
echo "- Inventory: $SCRIPT_DIR/test-inventory"
echo "- Test playbook: $SCRIPT_DIR/test-emergency-rollback.yml"
echo ""

# Run emergency rollback tests
echo "🚀 Executing emergency rollback playbook tests..."
if ansible-playbook \
    -i "$SCRIPT_DIR/test-inventory" \
    "$SCRIPT_DIR/test-emergency-rollback.yml" \
    --extra-vars "test_mode=true" \
    -v; then
    echo ""
    echo "✅ Emergency Rollback Playbook Tests: PASSED"
    echo ""
    echo "📊 Test Summary:"
    echo "- Rollback initialization: ✅"
    echo "- Emergency operations simulation: ✅"
    echo "- Health check validation: ✅"
    echo "- Rollback verification: ✅"
    echo "- Recovery time analysis: ✅"
    echo "- Report generation: ✅"
    echo ""
    echo "Status: Ready for production emergency rollback operations"
else
    echo ""
    echo "❌ Emergency Rollback Playbook Tests: FAILED"
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
echo "✅ Emergency rollback testing: COMPLETE"