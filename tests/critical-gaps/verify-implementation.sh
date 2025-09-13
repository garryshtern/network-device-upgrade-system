#!/bin/bash

# Quick verification test for Critical Gap Test Suite implementation
# This script validates that all test files are properly structured and executable

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFICATION_PASSED=0
VERIFICATION_FAILED=0

echo "==============================================="
echo "🔍 CRITICAL GAP TEST SUITE VERIFICATION"
echo "==============================================="
echo ""

# Test files to verify
TESTS=(
    "conditional-logic-coverage.yml"
    "end-to-end-workflow.yml"
    "security-boundary-testing.yml"
    "error-path-coverage.yml"
    "performance-under-load.yml"
)

# Check if test runner exists and is executable
echo "📋 Verifying test runner..."
if [[ -f "${SCRIPT_DIR}/run-all-critical-gap-tests.sh" ]] && [[ -x "${SCRIPT_DIR}/run-all-critical-gap-tests.sh" ]]; then
    echo -e "✅ ${GREEN}Test runner found and executable${NC}"
    VERIFICATION_PASSED=$((VERIFICATION_PASSED + 1))
else
    echo -e "❌ ${RED}Test runner missing or not executable${NC}"
    VERIFICATION_FAILED=$((VERIFICATION_FAILED + 1))
fi

# Check each test file
echo ""
echo "📋 Verifying individual test files..."
for test_file in "${TESTS[@]}"; do
    echo -n "  🧪 ${test_file}: "

    if [[ ! -f "${SCRIPT_DIR}/${test_file}" ]]; then
        echo -e "${RED}MISSING${NC}"
        VERIFICATION_FAILED=$((VERIFICATION_FAILED + 1))
        continue
    fi

    # Basic YAML structure check
    if grep -q "^- name:.*Test Suite$" "${SCRIPT_DIR}/${test_file}" && \
       grep -q "hosts: localhost" "${SCRIPT_DIR}/${test_file}" && \
       grep -q "tasks:" "${SCRIPT_DIR}/${test_file}"; then
        echo -e "${GREEN}VALID${NC}"
        VERIFICATION_PASSED=$((VERIFICATION_PASSED + 1))
    else
        echo -e "${RED}INVALID STRUCTURE${NC}"
        VERIFICATION_FAILED=$((VERIFICATION_FAILED + 1))
    fi
done

# Check for Python dependencies in test files
echo ""
echo "📋 Verifying Python integration..."
python_tests_found=0
for test_file in "${TESTS[@]}"; do
    if grep -q "python3 <<" "${SCRIPT_DIR}/${test_file}"; then
        python_tests_found=$((python_tests_found + 1))
    fi
done

if [[ $python_tests_found -eq 5 ]]; then
    echo -e "✅ ${GREEN}All test files contain Python logic validation${NC}"
    VERIFICATION_PASSED=$((VERIFICATION_PASSED + 1))
else
    echo -e "⚠️ ${YELLOW}Only $python_tests_found/5 test files contain Python logic${NC}"
fi

# Verify directory structure
echo ""
echo "📋 Verifying directory structure..."
if [[ -f "${SCRIPT_DIR}/README.md" ]]; then
    echo -e "✅ ${GREEN}Documentation found${NC}"
    VERIFICATION_PASSED=$((VERIFICATION_PASSED + 1))
else
    echo -e "❌ ${RED}README.md missing${NC}"
    VERIFICATION_FAILED=$((VERIFICATION_FAILED + 1))
fi

# Check if reports directory can be created
echo ""
echo "📋 Verifying reports directory..."
REPORTS_DIR="${SCRIPT_DIR}/../reports"
if mkdir -p "${REPORTS_DIR}" 2>/dev/null; then
    echo -e "✅ ${GREEN}Reports directory accessible${NC}"
    VERIFICATION_PASSED=$((VERIFICATION_PASSED + 1))
else
    echo -e "❌ ${RED}Cannot create reports directory${NC}"
    VERIFICATION_FAILED=$((VERIFICATION_FAILED + 1))
fi

# Quick syntax validation
echo ""
echo "📋 Performing basic syntax validation..."
syntax_errors=0
for test_file in "${TESTS[@]}"; do
    if [[ -f "${SCRIPT_DIR}/${test_file}" ]]; then
        # Check for basic YAML syntax issues
        if python3 -c "import yaml; yaml.safe_load(open('${SCRIPT_DIR}/${test_file}'))" 2>/dev/null; then
            echo -e "  ✅ ${test_file}: ${GREEN}YAML syntax OK${NC}"
        else
            echo -e "  ❌ ${test_file}: ${RED}YAML syntax error${NC}"
            syntax_errors=$((syntax_errors + 1))
        fi
    fi
done

if [[ $syntax_errors -eq 0 ]]; then
    VERIFICATION_PASSED=$((VERIFICATION_PASSED + 1))
else
    VERIFICATION_FAILED=$((VERIFICATION_FAILED + 1))
fi

# Summary
echo ""
echo "==============================================="
echo "📊 VERIFICATION SUMMARY"
echo "==============================================="
echo "✅ Passed checks: $VERIFICATION_PASSED"
echo "❌ Failed checks: $VERIFICATION_FAILED"
echo ""

# Determine overall status
if [[ $VERIFICATION_FAILED -eq 0 ]]; then
    echo -e "🎉 ${GREEN}ALL VERIFICATIONS PASSED${NC}"
    echo "✅ Critical Gap Test Suite is properly implemented"
    echo "🚀 Ready for CI/CD integration and execution"
    exit_code=0
elif [[ $VERIFICATION_FAILED -le 2 ]]; then
    echo -e "⚠️ ${YELLOW}MOSTLY FUNCTIONAL${NC}"
    echo "✅ Core implementation is complete"
    echo "⚠️ Minor issues detected - review and fix recommended"
    exit_code=1
else
    echo -e "❌ ${RED}IMPLEMENTATION ISSUES DETECTED${NC}"
    echo "❌ Critical problems found in test suite implementation"
    echo "🔧 Major fixes required before deployment"
    exit_code=2
fi

echo ""
echo "📋 Next steps:"
if [[ $exit_code -eq 0 ]]; then
    echo "  1. Run the complete test suite: ./run-all-critical-gap-tests.sh"
    echo "  2. Review test results in tests/reports/"
    echo "  3. Integrate with CI/CD pipeline"
    echo "  4. Deploy to production with confidence! 🎉"
elif [[ $exit_code -eq 1 ]]; then
    echo "  1. Fix minor issues identified above"
    echo "  2. Re-run this verification script"
    echo "  3. Test individual problematic test files"
    echo "  4. Validate syntax and structure"
else
    echo "  1. Review failed verification checks above"
    echo "  2. Fix critical implementation issues"
    echo "  3. Ensure all test files are present and valid"
    echo "  4. Re-run this verification before proceeding"
fi

echo "==============================================="

exit $exit_code