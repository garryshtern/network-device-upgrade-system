#!/bin/bash
# Compliance Audit Playbook Test Runner
# Tests compliance verification and reporting functionality

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

echo "🔍 Running Compliance Audit Playbook Tests..."
echo "Project Root: $PROJECT_ROOT"
echo "Test Directory: $SCRIPT_DIR"

# Change to project root for consistent paths
cd "$PROJECT_ROOT"

# Create test inventory
cat > "$SCRIPT_DIR/test-inventory" << EOF
[compliance_test_devices]
localhost ansible_connection=local

[compliance_test_devices:vars]
ansible_network_os=cisco.nxos.nxos
device_platform=cisco_nxos
EOF

echo "📋 Test Configuration:"
echo "- Inventory: $SCRIPT_DIR/test-inventory"
echo "- Test playbook: $SCRIPT_DIR/test-compliance-audit.yml"
echo ""

# Run compliance audit tests
echo "🚀 Executing compliance audit playbook tests..."
if ansible-playbook \
    -i "$SCRIPT_DIR/test-inventory" \
    "$SCRIPT_DIR/test-compliance-audit.yml" \
    --extra-vars "test_mode=true" \
    -v; then
    echo ""
    echo "✅ Compliance Audit Playbook Tests: PASSED"
    echo ""
    echo "📊 Test Summary:"
    echo "- Compliance audit initialization: ✅"
    echo "- Compliance checks simulation: ✅"
    echo "- Report generation: ✅"
    echo "- Report content validation: ✅"
    echo "- Standards validation: ✅"
    echo ""
    echo "Status: Ready for production compliance auditing"
else
    echo ""
    echo "❌ Compliance Audit Playbook Tests: FAILED"
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
echo "✅ Compliance audit testing: COMPLETE"