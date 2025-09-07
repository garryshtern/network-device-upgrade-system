#!/bin/bash
# Performance testing script for Ansible playbooks
# Measures execution times, memory usage, and scalability

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Performance Testing Suite${NC}"
echo -e "${BLUE}========================================${NC}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

# Create results directory
RESULTS_DIR="tests/results/performance_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"

# Test 1: Playbook execution time
echo -e "\n${YELLOW}1. Playbook Execution Time Tests${NC}"

playbooks=(
    "ansible-content/playbooks/main-upgrade-workflow.yml"
    "tests/unit-tests/variable-validation.yml"
    "tests/unit-tests/template-rendering.yml"
    "tests/unit-tests/workflow-logic.yml"
)

echo "Playbook,Execution Time (seconds),Memory Usage (MB),Status" > "$RESULTS_DIR/playbook_performance.csv"

for playbook in "${playbooks[@]}"; do
    if [ -f "$playbook" ]; then
        playbook_name=$(basename "$playbook" .yml)
        echo -e "\n  Testing: $playbook_name"
        
        # Measure execution time and memory
        start_time=$(date +%s.%3N)
        memory_before=$(ps -o rss= -p $$ 2>/dev/null || echo "0")
        
        if timeout 300 ansible-playbook --syntax-check "$playbook" > /dev/null 2>&1; then
            status="PASS"
            echo -e "    ${GREEN}✓ $playbook_name - Syntax check passed${NC}"
        else
            status="FAIL"
            echo -e "    ${RED}✗ $playbook_name - Syntax check failed${NC}"
        fi
        
        end_time=$(date +%s.%3N)
        memory_after=$(ps -o rss= -p $$ 2>/dev/null || echo "0")
        
        execution_time=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")
        memory_used=$(echo "$memory_after - $memory_before" | bc 2>/dev/null || echo "0")
        memory_used_mb=$(echo "scale=2; $memory_used / 1024" | bc 2>/dev/null || echo "0")
        
        echo "$playbook_name,$execution_time,$memory_used_mb,$status" >> "$RESULTS_DIR/playbook_performance.csv"
        
        echo "    Execution time: ${execution_time}s"
        echo "    Memory delta: ${memory_used_mb}MB"
    fi
done

# Test 2: Inventory scaling tests
echo -e "\n${YELLOW}2. Inventory Scaling Tests${NC}"

inventory_sizes=(1 5 10 25 50)
echo "Inventory Size,Parse Time (seconds),Memory Usage (MB)" > "$RESULTS_DIR/inventory_scaling.csv"

for size in "${inventory_sizes[@]}"; do
    echo -e "\n  Testing inventory size: $size devices"
    
    # Generate test inventory
    test_inventory="$RESULTS_DIR/test_inventory_$size.yml"
    cat > "$test_inventory" << EOF
---
all:
  children:
    test_devices:
      hosts:
EOF
    
    for ((i=1; i<=size; i++)); do
        cat >> "$test_inventory" << EOF
        test-device-$(printf "%03d" $i):
          ansible_host: 127.0.0.$((i % 254 + 1))
          platform_type: cisco_nxos
          firmware_version: "9.3.10"
          target_version: "10.1.2"
EOF
    done
    
    # Measure inventory parsing time
    start_time=$(date +%s.%3N)
    memory_before=$(ps -o rss= -p $$ 2>/dev/null || echo "0")
    
    ansible-inventory -i "$test_inventory" --list > /dev/null 2>&1
    
    end_time=$(date +%s.%3N)
    memory_after=$(ps -o rss= -p $$ 2>/dev/null || echo "0")
    
    parse_time=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")
    memory_used=$(echo "$memory_after - $memory_before" | bc 2>/dev/null || echo "0")
    memory_used_mb=$(echo "scale=2; $memory_used / 1024" | bc 2>/dev/null || echo "0")
    
    echo "$size,$parse_time,$memory_used_mb" >> "$RESULTS_DIR/inventory_scaling.csv"
    
    echo "    Parse time: ${parse_time}s"
    echo "    Memory usage: ${memory_used_mb}MB"
done

# Test 3: Template rendering performance
echo -e "\n${YELLOW}3. Template Rendering Performance${NC}"

template_sizes=(10 50 100 500)
echo "Template Count,Render Time (seconds),Memory Usage (MB)" > "$RESULTS_DIR/template_performance.csv"

for count in "${template_sizes[@]}"; do
    echo -e "\n  Testing template rendering: $count templates"
    
    # Create performance test playbook
    perf_test_playbook="$RESULTS_DIR/template_perf_$count.yml"
    cat > "$perf_test_playbook" << EOF
---
- name: Template Performance Test ($count templates)
  hosts: localhost
  connection: local
  gather_facts: false
  tasks:
EOF
    
    for ((i=1; i<=count; i++)); do
        cat >> "$perf_test_playbook" << EOF
    - name: "Template test $i"
      set_fact:
        test_var_$i: "{{ 'test_value_' + '$i' | string }}"
        
EOF
    done
    
    # Measure template rendering time
    start_time=$(date +%s.%3N)
    memory_before=$(ps -o rss= -p $$ 2>/dev/null || echo "0")
    
    ansible-playbook "$perf_test_playbook" > /dev/null 2>&1
    
    end_time=$(date +%s.%3N)
    memory_after=$(ps -o rss= -p $$ 2>/dev/null || echo "0")
    
    render_time=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")
    memory_used=$(echo "$memory_after - $memory_before" | bc 2>/dev/null || echo "0")
    memory_used_mb=$(echo "scale=2; $memory_used / 1024" | bc 2>/dev/null || echo "0")
    
    echo "$count,$render_time,$memory_used_mb" >> "$RESULTS_DIR/template_performance.csv"
    
    echo "    Render time: ${render_time}s"
    echo "    Memory usage: ${memory_used_mb}MB"
done

# Test 4: Check mode performance
echo -e "\n${YELLOW}4. Check Mode Performance${NC}"

if [ -f "tests/integration-tests/check-mode-tests.yml" ]; then
    echo -e "\n  Testing check mode performance"
    
    start_time=$(date +%s.%3N)
    
    ansible-playbook -i tests/mock-inventories/all-platforms.yml \
        --check --diff tests/integration-tests/check-mode-tests.yml \
        > "$RESULTS_DIR/check_mode_output.log" 2>&1
        
    end_time=$(date +%s.%3N)
    execution_time=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")
    
    echo "    Check mode execution time: ${execution_time}s"
    echo "Check Mode Performance,$execution_time" > "$RESULTS_DIR/check_mode_performance.csv"
fi

# Generate performance summary report
echo -e "\n${YELLOW}5. Generating Performance Report${NC}"

cat > "$RESULTS_DIR/performance_summary.md" << EOF
# Performance Test Report

Generated: $(date)

## Test Environment
- OS: $(uname -s)
- Ansible Version: $(ansible --version | head -n1)
- Python Version: $(python3 --version)

## Results Summary

### Playbook Performance
$(cat "$RESULTS_DIR/playbook_performance.csv" | column -t -s,)

### Inventory Scaling
$(cat "$RESULTS_DIR/inventory_scaling.csv" | column -t -s,)

### Template Performance
$(cat "$RESULTS_DIR/template_performance.csv" | column -t -s,)

### Check Mode Performance
$(cat "$RESULTS_DIR/check_mode_performance.csv" | column -t -s,)

## Performance Recommendations

1. **Playbook Optimization**: Focus on playbooks with execution time > 5s
2. **Inventory Scaling**: Monitor memory usage with inventories > 100 devices  
3. **Template Efficiency**: Consider caching for complex template operations
4. **Check Mode**: Use for validation in CI/CD pipelines

EOF

echo -e "${GREEN}✓ Performance testing completed${NC}"
echo -e "${BLUE}Results saved to: $RESULTS_DIR/${NC}"
echo -e "${BLUE}Summary report: $RESULTS_DIR/performance_summary.md${NC}"

# Display quick summary
echo -e "\n${BLUE}Quick Performance Summary:${NC}"
if [ -f "$RESULTS_DIR/playbook_performance.csv" ]; then
    echo "Fastest playbook: $(tail -n +2 "$RESULTS_DIR/playbook_performance.csv" | sort -t, -k2 -n | head -n1 | cut -d, -f1)"
    echo "Slowest playbook: $(tail -n +2 "$RESULTS_DIR/playbook_performance.csv" | sort -t, -k2 -nr | head -n1 | cut -d, -f1)"
fi