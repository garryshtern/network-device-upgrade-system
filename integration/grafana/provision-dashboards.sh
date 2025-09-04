#!/bin/bash
# Grafana Dashboard Provisioning Script
# Automates deployment of Network Device Upgrade Management System dashboards

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_ADMIN_USER="${GRAFANA_ADMIN_USER:-admin}"
GRAFANA_ADMIN_PASS="${GRAFANA_ADMIN_PASS:-admin}"
INFLUXDB_URL="${INFLUXDB_URL:-http://localhost:8086}"
INFLUXDB_TOKEN="${INFLUXDB_TOKEN:-}"
INFLUXDB_ORG="${INFLUXDB_ORG:-network-operations}"
INFLUXDB_BUCKET="${INFLUXDB_BUCKET:-network-upgrade-metrics}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Grafana Dashboard Provisioning${NC}"
echo -e "${BLUE}Network Device Upgrade Management${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to check dependencies
check_dependencies() {
    echo -e "${YELLOW}Checking dependencies...${NC}"
    
    local missing=0
    
    # Check for curl
    if command -v curl >/dev/null 2>&1; then
        echo -e "${GREEN}✓ curl found${NC}"
    else
        echo -e "${RED}✗ curl not found${NC}"
        missing=$((missing + 1))
    fi
    
    # Check for jq
    if command -v jq >/dev/null 2>&1; then
        echo -e "${GREEN}✓ jq found${NC}"
    else
        echo -e "${RED}✗ jq not found - required for JSON processing${NC}"
        missing=$((missing + 1))
    fi
    
    if [ $missing -gt 0 ]; then
        echo -e "${RED}Missing $missing required dependencies${NC}"
        echo -e "${YELLOW}Install missing dependencies:${NC}"
        echo "  Ubuntu/Debian: apt-get install curl jq"
        echo "  RHEL/CentOS: yum install curl jq"
        echo "  macOS: brew install curl jq"
        return 1
    fi
    
    return 0
}

# Function to test Grafana connectivity
test_grafana_connection() {
    echo -e "${YELLOW}Testing Grafana connectivity...${NC}"
    
    local response
    response=$(curl -s -o /dev/null -w "%{http_code}" "$GRAFANA_URL/api/health" || echo "000")
    
    if [ "$response" = "200" ]; then
        echo -e "${GREEN}✓ Grafana accessible at $GRAFANA_URL${NC}"
        return 0
    else
        echo -e "${RED}✗ Grafana not accessible at $GRAFANA_URL${NC}"
        echo -e "${YELLOW}Please ensure Grafana is running and accessible${NC}"
        return 1
    fi
}

# Function to authenticate with Grafana
authenticate_grafana() {
    echo -e "${YELLOW}Authenticating with Grafana...${NC}"
    
    local auth_response
    auth_response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{\"user\":\"$GRAFANA_ADMIN_USER\",\"password\":\"$GRAFANA_ADMIN_PASS\"}" \
        "$GRAFANA_URL/login" \
        -c /tmp/grafana_cookies.txt \
        -w "%{http_code}")
    
    if echo "$auth_response" | grep -q "200"; then
        echo -e "${GREEN}✓ Authentication successful${NC}"
        return 0
    else
        echo -e "${RED}✗ Authentication failed${NC}"
        echo -e "${YELLOW}Please check Grafana credentials${NC}"
        return 1
    fi
}

# Function to create or update InfluxDB data source
setup_influxdb_datasource() {
    echo -e "${YELLOW}Setting up InfluxDB v2 data source...${NC}"
    
    local datasource_config=$(cat <<EOF
{
  "name": "InfluxDB-NetworkUpgrade",
  "type": "influxdb",
  "url": "$INFLUXDB_URL",
  "access": "proxy",
  "isDefault": true,
  "jsonData": {
    "version": "Flux",
    "organization": "$INFLUXDB_ORG",
    "defaultBucket": "$INFLUXDB_BUCKET",
    "httpMode": "POST"
  },
  "secureJsonData": {
    "token": "$INFLUXDB_TOKEN"
  }
}
EOF
)
    
    # Check if data source already exists
    local existing_ds
    existing_ds=$(curl -s -H "Content-Type: application/json" \
        -b /tmp/grafana_cookies.txt \
        "$GRAFANA_URL/api/datasources/name/InfluxDB-NetworkUpgrade" \
        -w "%{http_code}" | tail -c 3)
    
    if [ "$existing_ds" = "200" ]; then
        echo -e "${YELLOW}Updating existing InfluxDB data source...${NC}"
        local update_response
        update_response=$(curl -s -X PUT \
            -H "Content-Type: application/json" \
            -b /tmp/grafana_cookies.txt \
            -d "$datasource_config" \
            "$GRAFANA_URL/api/datasources/name/InfluxDB-NetworkUpgrade" \
            -w "%{http_code}")
        
        if echo "$update_response" | tail -c 3 | grep -q "200"; then
            echo -e "${GREEN}✓ InfluxDB data source updated${NC}"
        else
            echo -e "${RED}✗ Failed to update InfluxDB data source${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}Creating new InfluxDB data source...${NC}"
        local create_response
        create_response=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -b /tmp/grafana_cookies.txt \
            -d "$datasource_config" \
            "$GRAFANA_URL/api/datasources" \
            -w "%{http_code}")
        
        if echo "$create_response" | tail -c 3 | grep -q "200"; then
            echo -e "${GREEN}✓ InfluxDB data source created${NC}"
        else
            echo -e "${RED}✗ Failed to create InfluxDB data source${NC}"
            echo -e "${YELLOW}Response: $create_response${NC}"
            return 1
        fi
    fi
    
    return 0
}

# Function to create folder for dashboards
create_dashboard_folder() {
    echo -e "${YELLOW}Creating dashboard folder...${NC}"
    
    local folder_config=$(cat <<EOF
{
  "title": "Network Device Upgrades",
  "uid": "network-upgrade-folder"
}
EOF
)
    
    local folder_response
    folder_response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -b /tmp/grafana_cookies.txt \
        -d "$folder_config" \
        "$GRAFANA_URL/api/folders" \
        -w "%{http_code}")
    
    if echo "$folder_response" | tail -c 3 | grep -q -E "(200|412)"; then
        echo -e "${GREEN}✓ Dashboard folder ready${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to create dashboard folder${NC}"
        return 1
    fi
}

# Function to deploy a dashboard
deploy_dashboard() {
    local dashboard_file="$1"
    local dashboard_name="$2"
    
    echo -e "${YELLOW}Deploying $dashboard_name dashboard...${NC}"
    
    if [ ! -f "$dashboard_file" ]; then
        echo -e "${RED}✗ Dashboard file not found: $dashboard_file${NC}"
        return 1
    fi
    
    # Read dashboard JSON and wrap it for Grafana API
    local dashboard_json
    dashboard_json=$(cat "$dashboard_file")
    
    local dashboard_payload=$(cat <<EOF
{
  "dashboard": $dashboard_json,
  "folderId": 0,
  "overwrite": true,
  "message": "Automated deployment via provision-dashboards.sh"
}
EOF
)
    
    local deploy_response
    deploy_response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -b /tmp/grafana_cookies.txt \
        -d "$dashboard_payload" \
        "$GRAFANA_URL/api/dashboards/db" \
        -w "%{http_code}")
    
    if echo "$deploy_response" | tail -c 3 | grep -q "200"; then
        echo -e "${GREEN}✓ $dashboard_name dashboard deployed${NC}"
        
        # Extract dashboard URL from response
        local dashboard_url
        dashboard_url=$(echo "$deploy_response" | head -n -1 | jq -r '.url // empty')
        if [ -n "$dashboard_url" ]; then
            echo -e "${BLUE}  → Dashboard URL: $GRAFANA_URL$dashboard_url${NC}"
        fi
        return 0
    else
        echo -e "${RED}✗ Failed to deploy $dashboard_name dashboard${NC}"
        echo -e "${YELLOW}Response: $deploy_response${NC}"
        return 1
    fi
}

# Function to setup alerting rules
setup_alerting() {
    echo -e "${YELLOW}Setting up alerting rules...${NC}"
    
    # Create notification channel for network upgrade alerts
    local notification_config=$(cat <<EOF
{
  "name": "network-upgrade-alerts",
  "type": "slack",
  "settings": {
    "webhook": "\${SLACK_WEBHOOK_URL}",
    "channel": "#network-operations",
    "title": "Network Device Upgrade Alert",
    "text": "{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}"
  }
}
EOF
)
    
    local notification_response
    notification_response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -b /tmp/grafana_cookies.txt \
        -d "$notification_config" \
        "$GRAFANA_URL/api/alert-notifications" \
        -w "%{http_code}")
    
    if echo "$notification_response" | tail -c 3 | grep -q -E "(200|409)"; then
        echo -e "${GREEN}✓ Alert notification channel configured${NC}"
    else
        echo -e "${YELLOW}! Alert notification setup skipped (optional)${NC}"
    fi
}

# Function to validate deployment
validate_deployment() {
    echo -e "${YELLOW}Validating dashboard deployment...${NC}"
    
    local validation_passed=0
    
    # Check data source
    local ds_test
    ds_test=$(curl -s -H "Content-Type: application/json" \
        -b /tmp/grafana_cookies.txt \
        "$GRAFANA_URL/api/datasources/name/InfluxDB-NetworkUpgrade" \
        -w "%{http_code}" | tail -c 3)
    
    if [ "$ds_test" = "200" ]; then
        echo -e "${GREEN}✓ InfluxDB data source accessible${NC}"
    else
        echo -e "${RED}✗ InfluxDB data source validation failed${NC}"
        validation_passed=1
    fi
    
    # List deployed dashboards
    local dashboards_response
    dashboards_response=$(curl -s -H "Content-Type: application/json" \
        -b /tmp/grafana_cookies.txt \
        "$GRAFANA_URL/api/search?type=dash-db")
    
    local dashboard_count
    dashboard_count=$(echo "$dashboards_response" | jq length 2>/dev/null || echo "0")
    
    if [ "$dashboard_count" -gt 0 ]; then
        echo -e "${GREEN}✓ $dashboard_count dashboard(s) deployed${NC}"
        
        # List dashboard titles
        echo -e "${BLUE}Deployed dashboards:${NC}"
        echo "$dashboards_response" | jq -r '.[].title' 2>/dev/null | sed 's/^/  - /'
    else
        echo -e "${YELLOW}! No dashboards found${NC}"
    fi
    
    return $validation_passed
}

# Function to cleanup
cleanup() {
    echo -e "${YELLOW}Cleaning up...${NC}"
    rm -f /tmp/grafana_cookies.txt
}

# Main function
main() {
    local failed_steps=0
    
    # Trap cleanup on exit
    trap cleanup EXIT
    
    # Check dependencies
    if ! check_dependencies; then
        exit 1
    fi
    
    echo ""
    
    # Test Grafana connection
    if ! test_grafana_connection; then
        exit 1
    fi
    
    echo ""
    
    # Authenticate with Grafana
    if ! authenticate_grafana; then
        exit 1
    fi
    
    echo ""
    
    # Setup InfluxDB data source
    if ! setup_influxdb_datasource; then
        failed_steps=$((failed_steps + 1))
    fi
    
    echo ""
    
    # Create dashboard folder
    if ! create_dashboard_folder; then
        failed_steps=$((failed_steps + 1))
    fi
    
    echo ""
    
    # Deploy dashboards
    local dashboard_dir="$SCRIPT_DIR/dashboards"
    if [ -d "$dashboard_dir" ]; then
        for dashboard_file in "$dashboard_dir"/*.json; do
            if [ -f "$dashboard_file" ]; then
                local dashboard_name
                dashboard_name=$(basename "$dashboard_file" .json)
                deploy_dashboard "$dashboard_file" "$dashboard_name"
            fi
        done
    else
        echo -e "${YELLOW}No dashboards directory found at $dashboard_dir${NC}"
        echo -e "${YELLOW}Creating dashboard templates...${NC}"
        mkdir -p "$dashboard_dir"
        echo -e "${BLUE}Dashboard templates will be created in: $dashboard_dir${NC}"
    fi
    
    echo ""
    
    # Setup alerting (optional)
    setup_alerting
    
    echo ""
    
    # Validate deployment
    validate_deployment
    
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Dashboard Provisioning Complete${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    if [ $failed_steps -eq 0 ]; then
        echo -e "${GREEN}🎉 All steps completed successfully!${NC}"
        echo ""
        echo -e "${BLUE}Access your dashboards at:${NC}"
        echo -e "${BLUE}$GRAFANA_URL/dashboards${NC}"
        echo ""
        echo -e "${BLUE}Data Source: InfluxDB-NetworkUpgrade${NC}"
        echo -e "${BLUE}Organization: $INFLUXDB_ORG${NC}"
        echo -e "${BLUE}Bucket: $INFLUXDB_BUCKET${NC}"
    else
        echo -e "${YELLOW}⚠️  Completed with $failed_steps warning(s)${NC}"
        echo -e "${YELLOW}Some optional components may need manual configuration${NC}"
    fi
    
    return 0
}

# Display usage information
usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Environment variables:"
    echo "  GRAFANA_URL          Grafana URL (default: http://localhost:3000)"
    echo "  GRAFANA_ADMIN_USER   Grafana admin username (default: admin)"
    echo "  GRAFANA_ADMIN_PASS   Grafana admin password (default: admin)"
    echo "  INFLUXDB_URL         InfluxDB URL (default: http://localhost:8086)"
    echo "  INFLUXDB_TOKEN       InfluxDB access token (required)"
    echo "  INFLUXDB_ORG         InfluxDB organization (default: network-operations)"
    echo "  INFLUXDB_BUCKET      InfluxDB bucket (default: network-upgrade-metrics)"
    echo ""
    echo "Example:"
    echo "  INFLUXDB_TOKEN=your_token_here $0"
    echo ""
}

# Handle command line arguments
case "${1:-}" in
    -h|--help)
        usage
        exit 0
        ;;
    *)
        if [ -z "$INFLUXDB_TOKEN" ]; then
            echo -e "${RED}Error: INFLUXDB_TOKEN environment variable is required${NC}"
            echo ""
            usage
            exit 1
        fi
        main "$@"
        ;;
esac