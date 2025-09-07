#!/bin/bash
# YAML/JSON validation test runner
# Runs comprehensive YAML and JSON validation across the project

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}YAML/JSON Validation Tests${NC}"
echo -e "${BLUE}========================================${NC}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

# Test 1: Basic YAML syntax validation
echo -e "\n${YELLOW}1. Basic YAML Syntax Validation${NC}"
if python3 tests/validation-scripts/yaml-validator.py --ansible-only; then
    echo -e "${GREEN}✓ YAML syntax validation passed${NC}"
else
    echo -e "${RED}✗ YAML syntax validation failed${NC}"
    exit 1
fi

# Test 2: yamllint validation (if available)
echo -e "\n${YELLOW}2. yamllint Validation${NC}"
if command -v yamllint > /dev/null; then
    if yamllint ansible-content/; then
        echo -e "${GREEN}✓ yamllint validation passed${NC}"
    else
        echo -e "${YELLOW}⚠ yamllint found style issues${NC}"
    fi
else
    echo -e "${YELLOW}⚠ yamllint not installed, skipping${NC}"
fi

# Test 3: ansible-lint validation (if available)
echo -e "\n${YELLOW}3. ansible-lint Validation${NC}"
if command -v ansible-lint > /dev/null; then
    if ansible-lint ansible-content/playbooks/ ansible-content/roles/ 2>/dev/null; then
        echo -e "${GREEN}✓ ansible-lint validation passed${NC}"
    else
        echo -e "${YELLOW}⚠ ansible-lint found issues${NC}"
    fi
else
    echo -e "${YELLOW}⚠ ansible-lint not installed, skipping${NC}"
fi

# Test 4: JSON validation
echo -e "\n${YELLOW}4. JSON File Validation${NC}"
json_files_found=0
json_errors=0

for json_file in $(find . -name "*.json" -not -path "./.*" 2>/dev/null); do
    json_files_found=$((json_files_found + 1))
    if python3 -m json.tool "$json_file" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ $json_file${NC}"
    else
        echo -e "${RED}✗ $json_file${NC}"
        json_errors=$((json_errors + 1))
    fi
done

if [ $json_files_found -eq 0 ]; then
    echo -e "${YELLOW}⚠ No JSON files found${NC}"
elif [ $json_errors -eq 0 ]; then
    echo -e "${GREEN}✓ All $json_files_found JSON files valid${NC}"
else
    echo -e "${RED}✗ $json_errors of $json_files_found JSON files invalid${NC}"
fi

# Test 5: Inventory validation
echo -e "\n${YELLOW}5. Inventory File Validation${NC}"
for inv_file in tests/mock-inventories/*.yml; do
    if [ -f "$inv_file" ]; then
        if ansible-inventory -i "$inv_file" --list > /dev/null 2>&1; then
            echo -e "${GREEN}✓ $(basename "$inv_file")${NC}"
        else
            echo -e "${RED}✗ $(basename "$inv_file")${NC}"
        fi
    fi
done

# Test 6: Variable file validation
echo -e "\n${YELLOW}6. Variable File Validation${NC}"
if [ -f "tests/test-vars.yml" ]; then
    if python3 -c "import yaml; yaml.safe_load(open('tests/test-vars.yml'))" 2>/dev/null; then
        echo -e "${GREEN}✓ test-vars.yml${NC}"
    else
        echo -e "${RED}✗ test-vars.yml${NC}"
    fi
fi

echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}Validation Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}YAML/JSON validation tests completed${NC}"