#!/bin/bash
# YAML Validation Test Suite
# Comprehensive YAML and JSON validation for all project files

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.."; pwd)"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

echo -e "${BLUE}🔍 YAML VALIDATION TEST SUITE${NC}"
echo "==============================="
echo "Comprehensive YAML and JSON validation"
echo ""

cd "$PROJECT_ROOT"

# Test 1: Python YAML validator
echo -e "${YELLOW}[1/7]${NC} Testing Python YAML validator..."
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if python3 tests/validation-scripts/yaml-validator.py --ansible-only >/dev/null 2>&1; then
    echo -e "${GREEN}✓ PASSED${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ FAILED${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Test 2: yamllint validation
echo -e "${YELLOW}[2/7]${NC} Testing yamllint on ansible-content..."
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if yamllint ansible-content/ >/dev/null 2>&1; then
    echo -e "${GREEN}✓ PASSED${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ FAILED${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Test 3: Ansible collection requirements validation
echo -e "${YELLOW}[3/7]${NC} Testing Ansible collections requirements..."
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if python3 -c "import yaml; yaml.safe_load(open('ansible-content/collections/requirements.yml'))" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ PASSED${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ FAILED${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Test 4: Inventory files validation
echo -e "${YELLOW}[4/7]${NC} Testing inventory files..."
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if python3 -c "import yaml; yaml.safe_load(open('ansible-content/inventory/hosts.yml'))" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ PASSED${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ FAILED${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Test 5: Group vars validation
echo -e "${YELLOW}[5/7]${NC} Testing group variables..."
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if find ansible-content/inventory/group_vars -name "*.yml" -exec python3 -c "import yaml; yaml.safe_load(open('{}'))" \; >/dev/null 2>&1; then
    echo -e "${GREEN}✓ PASSED${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ FAILED${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Test 6: Role metadata validation
echo -e "${YELLOW}[6/7]${NC} Testing role metadata..."
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if find ansible-content/roles -name "meta/main.yml" -exec python3 -c "import yaml; yaml.safe_load(open('{}'))" \; >/dev/null 2>&1; then
    echo -e "${GREEN}✓ PASSED${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ FAILED${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Test 7: Molecule configuration validation
echo -e "${YELLOW}[7/7]${NC} Testing molecule configurations..."
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if find ansible-content/roles -name "molecule.yml" -exec python3 -c "import yaml; yaml.safe_load(open('{}'))" \; >/dev/null 2>&1; then
    echo -e "${GREEN}✓ PASSED${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ FAILED${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Summary
echo ""
echo -e "${BLUE}=== YAML VALIDATION SUMMARY ===${NC}"
echo "Total tests: $TOTAL_TESTS"
echo "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo "Failed: ${RED}$FAILED_TESTS${NC}"

if [[ $FAILED_TESTS -eq 0 ]]; then
    echo -e "${GREEN}🎉 All YAML validation tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some YAML validation tests failed${NC}"
    exit 1
fi