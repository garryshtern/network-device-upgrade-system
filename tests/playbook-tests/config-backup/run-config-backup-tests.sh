#!/bin/bash
# Configuration Backup Playbook Test Runner
# Tests configuration backup and archive functionality

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.."; pwd)"

echo "💾 Running Configuration Backup Playbook Tests..."
echo "Project Root: $PROJECT_ROOT"
echo "Test Directory: $SCRIPT_DIR"

# Change to project root for consistent paths
cd "$PROJECT_ROOT"

# Create test inventory
cat > "$SCRIPT_DIR/test-inventory" << EOF
[config_backup_devices]
localhost ansible_connection=local

[config_backup_devices:vars]
ansible_network_os=cisco.nxos.nxos
device_platform=cisco_nxos
EOF

echo "📋 Test Configuration:"
echo "- Inventory: $SCRIPT_DIR/test-inventory"
echo "- Test playbook: $SCRIPT_DIR/test-config-backup.yml"
echo ""

# Run config backup tests
echo "🚀 Executing configuration backup playbook tests..."
if ansible-playbook \
    -i "$SCRIPT_DIR/test-inventory" \
    "$SCRIPT_DIR/test-config-backup.yml" \
    --extra-vars "test_mode=true" \
    -v; then
    echo ""
    echo "✅ Configuration Backup Playbook Tests: PASSED"
    echo ""
    echo "📊 Test Summary:"
    echo "- Configuration backup initialization: ✅"
    echo "- Backup operations simulation: ✅"
    echo "- Backup file generation: ✅"
    echo "- Report generation: ✅"
    echo "- Operation completeness: ✅"
    echo ""
    echo "Status: Ready for production configuration backup"
else
    echo ""
    echo "❌ Configuration Backup Playbook Tests: FAILED"
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
echo "✅ Configuration backup testing: COMPLETE"