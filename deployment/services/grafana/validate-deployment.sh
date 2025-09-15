#!/bin/bash
# Grafana Dashboard Deployment Validation Script
# Network Device Upgrade Management System

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_ADMIN_USER="${GRAFANA_ADMIN_USER:-admin}"
GRAFANA_ADMIN_PASS="${GRAFANA_ADMIN_PASS:-admin}"
INFLUXDB_URL="${INFLUXDB_URL:-http://localhost:8086}"
INFLUXDB_TOKEN="${INFLUXDB_TOKEN:-}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Grafana Dashboard Deployment Validation${NC}"
echo -e "${BLUE}Network Device Upgrade Management System${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to display usage
usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --grafana-url URL     Grafana URL (default: http://localhost:3000)"
    echo "  --verbose             Enable verbose output"
    echo "  --quick               Run quick validation only"
    echo "  --deep                Run comprehensive validation"
    echo "  --help                Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  GRAFANA_URL           Grafana URL"
    echo "  GRAFANA_ADMIN_USER    Grafana admin username"
    echo "  GRAFANA_ADMIN_PASS    Grafana admin password"
    echo "  INFLUXDB_URL          InfluxDB URL"
    echo "  INFLUXDB_TOKEN        InfluxDB access token"
    echo ""
}

# Parse command line arguments
VERBOSE=false
VALIDATION_LEVEL="standard"

while [[ $# -gt 0 ]]; do
    case $1 in
        --grafana-url)
            GRAFANA_URL="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --quick)
            VALIDATION_LEVEL="quick"
            shift
            ;;
        --deep)
            VALIDATION_LEVEL="deep"
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            exit 1
            ;;
    esac
done

# Verbose logging function
log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[VERBOSE] $1${NC}"
    fi
}

# Function to test basic connectivity
test_connectivity() {
    echo -e "${YELLOW}Testing basic connectivity...${NC}"
    
    local failures=0
    
    # Test Grafana connectivity
    log_verbose "Testing Grafana at $GRAFANA_URL"
    local grafana_health
    grafana_health=$(curl -s -o /dev/null -w "%{http_code}" "$GRAFANA_URL/api/health" || echo "000")
    
    if [[ "$grafana_health" == "200" ]]; then
        echo -e "${GREEN}✓ Grafana accessible (HTTP $grafana_health)${NC}"
    else
        echo -e "${RED}✗ Grafana not accessible (HTTP $grafana_health)${NC}"
        failures=$((failures + 1))
    fi
    
    # Test InfluxDB connectivity (if token provided)
    if [[ -n "$INFLUXDB_TOKEN" ]]; then
        log_verbose "Testing InfluxDB at $INFLUXDB_URL"
        local influxdb_health
        influxdb_health=$(curl -s -H "Authorization: Token $INFLUXDB_TOKEN" \
            -o /dev/null -w "%{http_code}" "$INFLUXDB_URL/health" || echo "000")
        
        if [[ "$influxdb_health" == "200" ]]; then
            echo -e "${GREEN}✓ InfluxDB accessible (HTTP $influxdb_health)${NC}"
        else
            echo -e "${RED}✗ InfluxDB not accessible (HTTP $influxdb_health)${NC}"
            failures=$((failures + 1))
        fi
    else
        echo -e "${YELLOW}! InfluxDB validation skipped (no token provided)${NC}"
    fi
    
    return $failures
}

# Function to authenticate with Grafana
authenticate_grafana() {
    echo -e "${YELLOW}Authenticating with Grafana...${NC}"
    
    log_verbose "Attempting authentication as $GRAFANA_ADMIN_USER"
    
    local auth_response
    auth_response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{\"user\":\"$GRAFANA_ADMIN_USER\",\"password\":\"$GRAFANA_ADMIN_PASS\"}" \
        "$GRAFANA_URL/login" \
        -c /tmp/grafana_validation_cookies.txt \
        -w "%{http_code}")
    
    if echo "$auth_response" | grep -q "200"; then
        echo -e "${GREEN}✓ Authentication successful${NC}"
        return 0
    else
        echo -e "${RED}✗ Authentication failed${NC}"
        log_verbose "Auth response: $auth_response"
        return 1
    fi
}

# Function to validate data sources
validate_data_sources() {
    echo -e "${YELLOW}Validating data sources...${NC}"
    
    local failures=0
    
    # Get all data sources
    local datasources_response
    datasources_response=$(curl -s -H "Content-Type: application/json" \
        -b /tmp/grafana_validation_cookies.txt \
        "$GRAFANA_URL/api/datasources")
    
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}✗ Failed to retrieve data sources${NC}"
        return 1
    fi
    
    log_verbose "Data sources response: $datasources_response"
    
    # Check for InfluxDB data source
    local influx_datasource
    influx_datasource=$(echo "$datasources_response" | jq -r '.[] | select(.name=="InfluxDB-NetworkUpgrade") | .name' 2>/dev/null || echo "")
    
    if [[ -n "$influx_datasource" ]]; then
        echo -e "${GREEN}✓ InfluxDB-NetworkUpgrade data source found${NC}"
        
        # Test data source connectivity
        local ds_test_response
        ds_test_response=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -b /tmp/grafana_validation_cookies.txt \
            "$GRAFANA_URL/api/datasources/proxy/$(echo "$datasources_response" | jq -r '.[] | select(.name=="InfluxDB-NetworkUpgrade") | .id')/health" \
            -w "%{http_code}")
        
        if echo "$ds_test_response" | tail -c 3 | grep -q "200"; then
            echo -e "${GREEN}✓ InfluxDB data source connectivity test passed${NC}"
        else
            echo -e "${YELLOW}! InfluxDB data source connectivity test failed${NC}"
            log_verbose "Data source test response: $ds_test_response"
            failures=$((failures + 1))
        fi
    else
        echo -e "${RED}✗ InfluxDB-NetworkUpgrade data source not found${NC}"
        failures=$((failures + 1))
    fi
    
    # List all data sources
    local ds_count
    ds_count=$(echo "$datasources_response" | jq length 2>/dev/null || echo "0")
    echo -e "${BLUE}Total data sources configured: $ds_count${NC}"
    
    if [[ "$VERBOSE" == "true" ]]; then
        echo "$datasources_response" | jq -r '.[].name' 2>/dev/null | sed 's/^/  - /' || echo "  Unable to parse data source names"
    fi
    
    return $failures
}

# Function to validate dashboards
validate_dashboards() {
    echo -e "${YELLOW}Validating dashboards...${NC}"
    
    local failures=0
    
    # Get all dashboards
    local dashboards_response
    dashboards_response=$(curl -s -H "Content-Type: application/json" \
        -b /tmp/grafana_validation_cookies.txt \
        "$GRAFANA_URL/api/search?type=dash-db")
    
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}✗ Failed to retrieve dashboards${NC}"
        return 1
    fi
    
    local dashboard_count
    dashboard_count=$(echo "$dashboards_response" | jq length 2>/dev/null || echo "0")
    
    if [[ "$dashboard_count" -gt 0 ]]; then
        echo -e "${GREEN}✓ Found $dashboard_count dashboard(s)${NC}"
        
        # List dashboard titles
        echo -e "${BLUE}Deployed dashboards:${NC}"
        echo "$dashboards_response" | jq -r '.[].title' 2>/dev/null | sed 's/^/  - /' || echo "  Unable to parse dashboard titles"
        
        # Expected dashboards
        local expected_dashboards=(
            "Network Upgrade Overview"
            "Platform Specific Metrics" 
            "Real-time Operations"
        )
        
        # Check for expected dashboards
        for expected in "${expected_dashboards[@]}"; do
            local found
            found=$(echo "$dashboards_response" | jq -r --arg title "$expected" '.[] | select(.title | contains($title)) | .title' 2>/dev/null || echo "")
            
            if [[ -n "$found" ]]; then
                echo -e "${GREEN}✓ Expected dashboard found: $expected${NC}"
            else
                echo -e "${YELLOW}! Expected dashboard missing: $expected${NC}"
                failures=$((failures + 1))
            fi
        done
        
    else
        echo -e "${RED}✗ No dashboards found${NC}"
        failures=$((failures + 1))
    fi
    
    return $failures
}

# Function to validate dashboard content (deep validation)
validate_dashboard_content() {
    echo -e "${YELLOW}Performing deep dashboard content validation...${NC}"
    
    local failures=0
    
    # Get dashboard details
    local dashboards_response
    dashboards_response=$(curl -s -H "Content-Type: application/json" \
        -b /tmp/grafana_validation_cookies.txt \
        "$GRAFANA_URL/api/search?type=dash-db")
    
    # Validate each dashboard
    while IFS= read -r dashboard_uid; do
        if [[ -n "$dashboard_uid" && "$dashboard_uid" != "null" ]]; then
            log_verbose "Validating dashboard UID: $dashboard_uid"
            
            local dashboard_detail
            dashboard_detail=$(curl -s -H "Content-Type: application/json" \
                -b /tmp/grafana_validation_cookies.txt \
                "$GRAFANA_URL/api/dashboards/uid/$dashboard_uid")
            
            if [[ $? -eq 0 ]]; then
                local panel_count
                panel_count=$(echo "$dashboard_detail" | jq '.dashboard.panels | length' 2>/dev/null || echo "0")
                
                local dashboard_title
                dashboard_title=$(echo "$dashboard_detail" | jq -r '.dashboard.title' 2>/dev/null || echo "Unknown")
                
                if [[ "$panel_count" -gt 0 ]]; then
                    echo -e "${GREEN}✓ Dashboard '$dashboard_title' has $panel_count panels${NC}"
                    
                    # Check for data source references
                    local datasource_refs
                    datasource_refs=$(echo "$dashboard_detail" | jq -r '.dashboard.panels[]?.datasource // empty' 2>/dev/null | sort -u)
                    
                    if [[ -n "$datasource_refs" ]]; then
                        log_verbose "Data sources referenced in '$dashboard_title': $datasource_refs"
                    else
                        echo -e "${YELLOW}! Dashboard '$dashboard_title' has no data source references${NC}"
                        failures=$((failures + 1))
                    fi
                else
                    echo -e "${RED}✗ Dashboard '$dashboard_title' has no panels${NC}"
                    failures=$((failures + 1))
                fi
            else
                echo -e "${RED}✗ Failed to retrieve dashboard details for UID: $dashboard_uid${NC}"
                failures=$((failures + 1))
            fi
        fi
    done < <(echo "$dashboards_response" | jq -r '.[].uid' 2>/dev/null)
    
    return $failures
}

# Function to validate alerting configuration
validate_alerting() {
    echo -e "${YELLOW}Validating alerting configuration...${NC}"
    
    local failures=0
    
    # Get notification channels
    local notifications_response
    notifications_response=$(curl -s -H "Content-Type: application/json" \
        -b /tmp/grafana_validation_cookies.txt \
        "$GRAFANA_URL/api/alert-notifications")
    
    if [[ $? -eq 0 ]]; then
        local notification_count
        notification_count=$(echo "$notifications_response" | jq length 2>/dev/null || echo "0")
        
        if [[ "$notification_count" -gt 0 ]]; then
            echo -e "${GREEN}✓ Found $notification_count notification channel(s)${NC}"
            
            if [[ "$VERBOSE" == "true" ]]; then
                echo "$notifications_response" | jq -r '.[].name' 2>/dev/null | sed 's/^/  - /' || echo "  Unable to parse notification names"
            fi
        else
            echo -e "${YELLOW}! No notification channels configured${NC}"
        fi
        
        # Check for network upgrade specific alerts
        local network_alerts
        network_alerts=$(echo "$notifications_response" | jq -r '.[] | select(.name | contains("network")) | .name' 2>/dev/null || echo "")
        
        if [[ -n "$network_alerts" ]]; then
            echo -e "${GREEN}✓ Network-specific alert channels found${NC}"
        else
            echo -e "${YELLOW}! No network-specific alert channels found${NC}"
        fi
    else
        echo -e "${YELLOW}! Unable to retrieve notification channels${NC}"
    fi
    
    return $failures
}

# Function to validate system performance
validate_performance() {
    echo -e "${YELLOW}Validating system performance...${NC}"
    
    local failures=0
    
    # Test API response times
    local start_time end_time duration
    
    start_time=$(date +%s%3N)
    curl -s -o /dev/null "$GRAFANA_URL/api/health"
    end_time=$(date +%s%3N)
    duration=$((end_time - start_time))
    
    if [[ "$duration" -lt 1000 ]]; then
        echo -e "${GREEN}✓ API response time: ${duration}ms (good)${NC}"
    elif [[ "$duration" -lt 3000 ]]; then
        echo -e "${YELLOW}! API response time: ${duration}ms (acceptable)${NC}"
    else
        echo -e "${RED}✗ API response time: ${duration}ms (slow)${NC}"
        failures=$((failures + 1))
    fi
    
    return $failures
}

# Function to generate validation report
generate_report() {
    local total_failures=$1
    
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Validation Report${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    echo "Grafana URL: $GRAFANA_URL"
    echo "Validation Level: $VALIDATION_LEVEL"
    echo "Timestamp: $(date)"
    echo ""
    
    if [[ "$total_failures" -eq 0 ]]; then
        echo -e "${GREEN}🎉 All validations passed successfully!${NC}"
        echo -e "${GREEN}Dashboard deployment is healthy and operational.${NC}"
    elif [[ "$total_failures" -le 3 ]]; then
        echo -e "${YELLOW}⚠️  Validation completed with $total_failures minor issue(s).${NC}"
        echo -e "${YELLOW}System is functional but may need attention.${NC}"
    else
        echo -e "${RED}❌ Validation failed with $total_failures critical issue(s).${NC}"
        echo -e "${RED}Dashboard deployment requires immediate attention.${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    if [[ "$total_failures" -eq 0 ]]; then
        echo "• Dashboard system is ready for use"
        echo "• Access dashboards at: $GRAFANA_URL/dashboards"
        echo "• Monitor system health regularly"
    else
        echo "• Review failed validation items above"
        echo "• Check Grafana and InfluxDB logs for errors"
        echo "• Verify configuration and network connectivity"
        echo "• Re-run validation after fixes: $0"
    fi
    
    return $total_failures
}

# Cleanup function
cleanup() {
    rm -f /tmp/grafana_validation_cookies.txt
}

# Main validation function
main() {
    local total_failures=0
    
    # Trap cleanup on exit
    trap cleanup EXIT
    
    # Basic connectivity test
    test_connectivity
    total_failures=$((total_failures + $?))
    
    echo ""
    
    # Authenticate with Grafana
    if ! authenticate_grafana; then
        echo -e "${RED}Cannot proceed without Grafana authentication${NC}"
        exit 1
    fi
    
    echo ""
    
    # Data source validation
    validate_data_sources
    total_failures=$((total_failures + $?))
    
    echo ""
    
    # Dashboard validation
    validate_dashboards
    total_failures=$((total_failures + $?))
    
    # Additional validations based on level
    case "$VALIDATION_LEVEL" in
        "deep")
            echo ""
            validate_dashboard_content
            total_failures=$((total_failures + $?))
            
            echo ""
            validate_alerting
            total_failures=$((total_failures + $?))
            
            echo ""
            validate_performance
            total_failures=$((total_failures + $?))
            ;;
        "standard")
            echo ""
            validate_alerting
            total_failures=$((total_failures + $?))
            ;;
        "quick")
            # Only basic validation already performed
            ;;
    esac
    
    # Generate final report
    generate_report $total_failures
    
    return $total_failures
}

# Execute main function
main "$@"