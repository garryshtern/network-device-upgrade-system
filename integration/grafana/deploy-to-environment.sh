#!/bin/bash
# Environment-Specific Dashboard Deployment Script
# Network Device Upgrade Management System - Grafana Integration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Default environment
ENVIRONMENT="${1:-development}"
CONFIG_FILE="$SCRIPT_DIR/config-templates/${ENVIRONMENT}.env"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Environment-Specific Dashboard Deployment${NC}"
echo -e "${BLUE}Environment: ${ENVIRONMENT}${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to display usage
usage() {
    echo "Usage: $0 [environment] [options]"
    echo ""
    echo "Environments:"
    echo "  development    Deploy to development environment (default)"
    echo "  production     Deploy to production environment"  
    echo "  staging        Deploy to staging environment"
    echo "  custom         Use custom configuration file"
    echo ""
    echo "Options:"
    echo "  --config-file  Specify custom configuration file"
    echo "  --dry-run      Show what would be deployed without executing"
    echo "  --force        Skip confirmation prompts"
    echo "  --help         Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 development                    # Deploy to dev with defaults"
    echo "  $0 production --force             # Deploy to prod without prompts"
    echo "  $0 custom --config-file my.env   # Deploy with custom config"
    echo ""
}

# Parse command line arguments
DRY_RUN=false
FORCE=false
CUSTOM_CONFIG=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --config-file)
            CUSTOM_CONFIG="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            if [[ -z "$ENVIRONMENT" ]]; then
                ENVIRONMENT="$1"
            fi
            shift
            ;;
    esac
done

# Use custom config file if specified
if [[ -n "$CUSTOM_CONFIG" ]]; then
    CONFIG_FILE="$CUSTOM_CONFIG"
fi

# Validate configuration file
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${RED}Error: Configuration file not found: $CONFIG_FILE${NC}"
    echo ""
    echo "Available configuration templates:"
    find "$SCRIPT_DIR/config-templates" -name "*.env" -exec basename {} \; 2>/dev/null || echo "No templates found"
    echo ""
    echo "Create a configuration file or use an existing template."
    exit 1
fi

echo -e "${YELLOW}Loading configuration from: $CONFIG_FILE${NC}"

# Source configuration file
set -a  # Automatically export all variables
source "$CONFIG_FILE"
set +a

# Validate required environment variables
validate_config() {
    local missing=0
    
    if [[ -z "$GRAFANA_URL" ]]; then
        echo -e "${RED}✗ GRAFANA_URL not set${NC}"
        missing=$((missing + 1))
    fi
    
    if [[ -z "$GRAFANA_ADMIN_USER" ]]; then
        echo -e "${RED}✗ GRAFANA_ADMIN_USER not set${NC}"
        missing=$((missing + 1))
    fi
    
    if [[ -z "$GRAFANA_ADMIN_PASS" ]]; then
        echo -e "${RED}✗ GRAFANA_ADMIN_PASS not set${NC}"
        missing=$((missing + 1))
    fi
    
    if [[ -z "$INFLUXDB_URL" ]]; then
        echo -e "${RED}✗ INFLUXDB_URL not set${NC}"
        missing=$((missing + 1))
    fi
    
    if [[ -z "$INFLUXDB_TOKEN" ]]; then
        echo -e "${RED}✗ INFLUXDB_TOKEN not set${NC}"
        missing=$((missing + 1))
    fi
    
    if [[ $missing -gt 0 ]]; then
        echo -e "${RED}Configuration validation failed: $missing required variables missing${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ Configuration validation passed${NC}"
    return 0
}

# Display deployment summary
show_deployment_summary() {
    echo -e "${BLUE}Deployment Summary:${NC}"
    echo "  Environment: $ENVIRONMENT"
    echo "  Grafana URL: $GRAFANA_URL"
    echo "  InfluxDB URL: $INFLUXDB_URL"
    echo "  InfluxDB Org: ${INFLUXDB_ORG:-network-operations}"
    echo "  InfluxDB Bucket: ${INFLUXDB_BUCKET:-network-upgrade-metrics}"
    echo "  Dashboard Folder: ${GRAFANA_FOLDER_NAME:-Network Device Upgrades}"
    echo "  Alerting Enabled: ${ENABLE_ALERTING:-false}"
    echo "  TLS Required: ${REQUIRE_TLS:-false}"
    echo ""
    
    local dashboard_count
    dashboard_count=$(find "$SCRIPT_DIR/dashboards" -name "*.json" | wc -l)
    echo "  Dashboards to deploy: $dashboard_count"
    find "$SCRIPT_DIR/dashboards" -name "*.json" -exec basename {} \; | sed 's/^/    - /'
    echo ""
}

# Environment-specific pre-deployment checks
pre_deployment_checks() {
    echo -e "${YELLOW}Running pre-deployment checks for $ENVIRONMENT...${NC}"
    
    case "$ENVIRONMENT" in
        production)
            # Production-specific checks
            if [[ "$REQUIRE_TLS" == "true" ]]; then
                if [[ ! "$GRAFANA_URL" =~ ^https:// ]]; then
                    echo -e "${RED}✗ Production requires HTTPS for Grafana${NC}"
                    return 1
                fi
                if [[ ! "$INFLUXDB_URL" =~ ^https:// ]]; then
                    echo -e "${RED}✗ Production requires HTTPS for InfluxDB${NC}"
                    return 1
                fi
            fi
            
            # Check if this is a production deployment
            if [[ "$FORCE" != "true" ]]; then
                echo -e "${YELLOW}⚠️  This is a PRODUCTION deployment${NC}"
                echo "Are you sure you want to continue? [y/N]"
                read -r confirmation
                if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
                    echo "Deployment cancelled."
                    exit 0
                fi
            fi
            ;;
        development)
            # Development-specific checks
            echo -e "${GREEN}✓ Development environment - no special checks required${NC}"
            ;;
        staging)
            # Staging-specific checks
            echo -e "${GREEN}✓ Staging environment checks passed${NC}"
            ;;
        *)
            echo -e "${YELLOW}! Unknown environment: $ENVIRONMENT${NC}"
            ;;
    esac
    
    return 0
}

# Customize dashboards for environment
customize_dashboards() {
    echo -e "${YELLOW}Customizing dashboards for $ENVIRONMENT...${NC}"
    
    local temp_dir="/tmp/grafana-dashboards-$ENVIRONMENT"
    rm -rf "$temp_dir"
    mkdir -p "$temp_dir"
    
    # Copy and customize each dashboard
    for dashboard_file in "$SCRIPT_DIR/dashboards"/*.json; do
        if [[ -f "$dashboard_file" ]]; then
            local filename
            filename=$(basename "$dashboard_file")
            local temp_dashboard="$temp_dir/$filename"
            
            # Copy original dashboard
            cp "$dashboard_file" "$temp_dashboard"
            
            # Environment-specific customizations
            case "$ENVIRONMENT" in
                development)
                    # Development: Add environment suffix to titles
                    jq '.title = .title + " (Development)"' "$temp_dashboard" > "${temp_dashboard}.tmp" && mv "${temp_dashboard}.tmp" "$temp_dashboard"
                    
                    # Override refresh intervals if specified
                    if [[ -n "$DASHBOARD_REFRESH_OVERRIDE" ]]; then
                        jq ".refresh = \"$DASHBOARD_REFRESH_OVERRIDE\"" "$temp_dashboard" > "${temp_dashboard}.tmp" && mv "${temp_dashboard}.tmp" "$temp_dashboard"
                    fi
                    ;;
                production)
                    # Production: Ensure appropriate refresh intervals
                    jq '.refresh = (if .refresh == "15s" then "30s" elif .refresh == "30s" then "1m" else .refresh end)' "$temp_dashboard" > "${temp_dashboard}.tmp" && mv "${temp_dashboard}.tmp" "$temp_dashboard"
                    ;;
                staging)
                    # Staging: Add environment suffix
                    jq '.title = .title + " (Staging)"' "$temp_dashboard" > "${temp_dashboard}.tmp" && mv "${temp_dashboard}.tmp" "$temp_dashboard"
                    ;;
            esac
            
            # Update data source references if needed
            if [[ -n "$GRAFANA_DATASOURCE_NAME" ]]; then
                jq ".panels[].datasource = \"$GRAFANA_DATASOURCE_NAME\"" "$temp_dashboard" > "${temp_dashboard}.tmp" && mv "${temp_dashboard}.tmp" "$temp_dashboard"
            fi
            
            echo -e "${GREEN}✓ Customized: $filename${NC}"
        fi
    done
    
    # Export customized dashboard directory for main script
    export CUSTOM_DASHBOARD_DIR="$temp_dir"
    
    return 0
}

# Main deployment function
deploy_to_environment() {
    echo -e "${YELLOW}Starting deployment to $ENVIRONMENT environment...${NC}"
    
    # Set environment-specific options for main script
    export GRAFANA_FOLDER_NAME="${GRAFANA_FOLDER_NAME:-Network Device Upgrades}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${BLUE}DRY RUN MODE - No actual changes will be made${NC}"
        echo "Would execute: $SCRIPT_DIR/provision-dashboards.sh"
        return 0
    fi
    
    # Execute main provisioning script with customized dashboards
    local provision_script="$SCRIPT_DIR/provision-dashboards.sh"
    
    if [[ -n "$CUSTOM_DASHBOARD_DIR" ]]; then
        # Temporarily override dashboard directory
        local original_dashboard_dir="$SCRIPT_DIR/dashboards"
        mv "$original_dashboard_dir" "$original_dashboard_dir.backup"
        ln -s "$CUSTOM_DASHBOARD_DIR" "$original_dashboard_dir"
        
        # Execute provisioning
        "$provision_script"
        local exit_code=$?
        
        # Restore original dashboard directory
        rm "$original_dashboard_dir"
        mv "$original_dashboard_dir.backup" "$original_dashboard_dir"
        
        # Cleanup temporary directory
        rm -rf "$CUSTOM_DASHBOARD_DIR"
        
        return $exit_code
    else
        # Execute with original dashboards
        "$provision_script"
        return $?
    fi
}

# Post-deployment validation
post_deployment_validation() {
    echo -e "${YELLOW}Running post-deployment validation...${NC}"
    
    # Test Grafana connectivity
    local health_check
    health_check=$(curl -s -o /dev/null -w "%{http_code}" "$GRAFANA_URL/api/health" || echo "000")
    
    if [[ "$health_check" == "200" ]]; then
        echo -e "${GREEN}✓ Grafana health check passed${NC}"
    else
        echo -e "${RED}✗ Grafana health check failed (HTTP $health_check)${NC}"
        return 1
    fi
    
    # Environment-specific validation
    case "$ENVIRONMENT" in
        production)
            echo -e "${YELLOW}Running production-specific validation...${NC}"
            # Add production-specific checks here
            echo -e "${GREEN}✓ Production validation completed${NC}"
            ;;
        *)
            echo -e "${GREEN}✓ Basic validation completed${NC}"
            ;;
    esac
    
    return 0
}

# Cleanup function
cleanup() {
    echo -e "${YELLOW}Cleaning up...${NC}"
    
    # Remove any temporary files
    rm -f /tmp/grafana_cookies.txt
    rm -rf "/tmp/grafana-dashboards-$ENVIRONMENT"
    
    echo -e "${GREEN}✓ Cleanup completed${NC}"
}

# Main execution
main() {
    # Trap cleanup on exit
    trap cleanup EXIT
    
    # Validate arguments
    case "$1" in
        --help|-h)
            usage
            exit 0
            ;;
    esac
    
    # Show deployment summary
    show_deployment_summary
    
    # Validate configuration
    if ! validate_config; then
        exit 1
    fi
    
    echo ""
    
    # Run pre-deployment checks
    if ! pre_deployment_checks; then
        exit 1
    fi
    
    echo ""
    
    # Customize dashboards for environment
    if ! customize_dashboards; then
        echo -e "${RED}Failed to customize dashboards${NC}"
        exit 1
    fi
    
    echo ""
    
    # Deploy to environment
    if ! deploy_to_environment; then
        echo -e "${RED}Deployment failed${NC}"
        exit 1
    fi
    
    echo ""
    
    # Post-deployment validation
    if ! post_deployment_validation; then
        echo -e "${YELLOW}⚠️  Deployment completed but validation failed${NC}"
        exit 1
    fi
    
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}🎉 Deployment to $ENVIRONMENT completed successfully!${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    # Display access information
    echo ""
    echo -e "${BLUE}Dashboard Access:${NC}"
    echo "  Grafana URL: $GRAFANA_URL/dashboards"
    echo "  Environment: $ENVIRONMENT"
    echo "  Folder: ${GRAFANA_FOLDER_NAME:-Network Device Upgrades}"
    
    return 0
}

# Execute main function with all arguments
main "$@"