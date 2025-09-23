#!/bin/bash
# Image Loading Playbook Test Runner
# Tests firmware image loading and validation functionality

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.."; pwd)"

echo "💾 Running Image Loading Playbook Tests..."
echo "Project Root: $PROJECT_ROOT"
echo "Test Directory: $SCRIPT_DIR"

# Change to project root for consistent paths
cd "$PROJECT_ROOT"

# Create test inventory
cat > "$SCRIPT_DIR/test-inventory" << EOF
[image_loading_devices]
localhost ansible_connection=local

[image_loading_devices:vars]
ansible_network_os=cisco.nxos.nxos
device_platform=cisco_nxos
EOF

echo "📋 Test Configuration:"
echo "- Inventory: $SCRIPT_DIR/test-inventory"
echo "- Test playbook: $SCRIPT_DIR/test-image-loading.yml"
echo ""

# Run image loading tests
echo "🚀 Executing image loading playbook tests..."
if ansible-playbook \
    -i "$SCRIPT_DIR/test-inventory" \
    "$SCRIPT_DIR/test-image-loading.yml" \
    --extra-vars "test_mode=true" \
    -v; then
    echo ""
    echo "✅ Image Loading Playbook Tests: PASSED"
    echo ""
    echo "📊 Test Summary:"
    echo "- Image loading initialization: ✅"
    echo "- Image operations simulation: ✅"
    echo "- Transfer statistics validation: ✅"
    echo "- Image validation checks: ✅"
    echo "- Mock image file creation: ✅"
    echo "- Report generation: ✅"
    echo ""
    echo "Status: Ready for production image loading operations"
else
    echo ""
    echo "❌ Image Loading Playbook Tests: FAILED"
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
echo "✅ Image loading testing: COMPLETE"