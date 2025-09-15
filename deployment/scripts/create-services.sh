#!/bin/bash

# System Services Creation and Startup Script
# Final step to bring all components online

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_FILE="/var/log/network-upgrade/services-startup.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${1}" | tee -a "${LOG_FILE}"
}

error_exit() {
    log "${RED}ERROR: ${1}${NC}"
    exit 1
}

# No need to run as root - using user systemd services

# Check if base system is installed
if [[ ! -f "/etc/network-upgrade/config.yml" ]]; then
    error_exit "Base system not installed. Run ./install/install-system.sh first"
fi

# Service dependency order
CORE_SERVICES=("redis" "nginx")
DATABASE_SERVICES=()
APPLICATION_SERVICES=("netbox" "netbox-rq" "awx-web" "awx-task" "awx-scheduler")
MONITORING_SERVICES=("telegraf")
TIMER_SERVICES=("netbox-housekeeping.timer" "ssl-cert-renewal.timer" "redis-monitor.timer")

# Check service prerequisites
check_prerequisites() {
    log "${BLUE}Checking service prerequisites...${NC}"
    
    # Check if AWX is installed
    if [[ ! -f "/opt/network-upgrade/awx/config/settings.py" ]]; then
        log "${YELLOW}⚠ AWX not installed. Run ./install/setup-awx.sh first${NC}"
        APPLICATION_SERVICES=("${APPLICATION_SERVICES[@]/awx-*/}")
    fi
    
    # Check if NetBox is installed
    if [[ ! -f "/opt/network-upgrade/netbox/config/configuration.py" ]]; then
        log "${YELLOW}⚠ NetBox not installed. Run ./install/setup-netbox.sh first${NC}"
        APPLICATION_SERVICES=("${APPLICATION_SERVICES[@]/netbox*/}")
        TIMER_SERVICES=("${TIMER_SERVICES[@]/netbox-*/}")
    fi
    
    # Check if Telegraf is configured
    if [[ ! -f "/etc/telegraf/telegraf.conf" ]]; then
        log "${YELLOW}⚠ Telegraf not configured. Run ./install/configure-telegraf.sh first${NC}"
        MONITORING_SERVICES=()
    fi
    
    # Check if SSL certificates exist
    if [[ ! -f "/etc/ssl/certs/network-upgrade.crt" ]]; then
        log "${YELLOW}⚠ SSL certificates not found. Run ./install/setup-ssl.sh first${NC}"
    fi
    
    log "${GREEN}✓ Prerequisites checked${NC}"
}

# Create master service management script
create_service_manager() {
    log "${BLUE}Creating service management script...${NC}"
    
    cat > /usr/local/bin/network-upgrade-services << 'EOF'
#!/bin/bash
# Network Upgrade System Service Manager

# Service arrays
CORE_SERVICES=("redis" "nginx")
APPLICATION_SERVICES=("netbox" "netbox-rq" "awx-web" "awx-task" "awx-scheduler")
MONITORING_SERVICES=("telegraf")
TIMER_SERVICES=("netbox-housekeeping.timer" "ssl-cert-renewal.timer" "redis-monitor.timer")

ALL_SERVICES=("${CORE_SERVICES[@]}" "${APPLICATION_SERVICES[@]}" "${MONITORING_SERVICES[@]}")

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    echo "Network Upgrade System Service Manager"
    echo ""
    echo "Usage: $0 {start|stop|restart|status|enable|disable|logs}"
    echo ""
    echo "Commands:"
    echo "  start      Start all services in correct order"
    echo "  stop       Stop all services in reverse order"
    echo "  restart    Restart all services"
    echo "  status     Show status of all services"
    echo "  enable     Enable all services for auto-start"
    echo "  disable    Disable all services from auto-start"
    echo "  logs       Show recent logs from all services"
    echo ""
    echo "Examples:"
    echo "  $0 start"
    echo "  $0 status"
    echo "  $0 logs"
}

start_services() {
    echo -e "${BLUE}Starting Network Upgrade System services...${NC}"
    
    # Start core services first
    for service in "${CORE_SERVICES[@]}"; do
        if systemctl --user --user is-enabled "$service" &>/dev/null; then
            echo -n "Starting $service... "
            if systemctl --user --user start "$service"; then
                echo -e "${GREEN}✓${NC}"
            else
                echo -e "${RED}✗${NC}"
            fi
            sleep 2
        fi
    done
    
    # Wait for core services to be ready
    sleep 5
    
    # Start application services
    for service in "${APPLICATION_SERVICES[@]}"; do
        if systemctl --user is-enabled "$service" &>/dev/null; then
            echo -n "Starting $service... "
            if systemctl --user start "$service"; then
                echo -e "${GREEN}✓${NC}"
            else
                echo -e "${RED}✗${NC}"
            fi
            sleep 3
        fi
    done
    
    # Start monitoring services
    for service in "${MONITORING_SERVICES[@]}"; do
        if systemctl --user is-enabled "$service" &>/dev/null; then
            echo -n "Starting $service... "
            if systemctl --user start "$service"; then
                echo -e "${GREEN}✓${NC}"
            else
                echo -e "${RED}✗${NC}"
            fi
        fi
    done
    
    # Start timers
    for timer in "${TIMER_SERVICES[@]}"; do
        if systemctl --user list-unit-files "$timer" &>/dev/null; then
            echo -n "Starting $timer... "
            if systemctl --user start "$timer"; then
                echo -e "${GREEN}✓${NC}"
            else
                echo -e "${RED}✗${NC}"
            fi
        fi
    done
    
    echo -e "${GREEN}Service startup complete!${NC}"
}

stop_services() {
    echo -e "${BLUE}Stopping Network Upgrade System services...${NC}"
    
    # Stop timers first
    for timer in "${TIMER_SERVICES[@]}"; do
        if systemctl --user is-active "$timer" &>/dev/null; then
            echo -n "Stopping $timer... "
            systemctl --user stop "$timer" && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"
        fi
    done
    
    # Stop monitoring services
    for service in "${MONITORING_SERVICES[@]}"; do
        if systemctl --user is-active "$service" &>/dev/null; then
            echo -n "Stopping $service... "
            systemctl --user stop "$service" && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"
        fi
    done
    
    # Stop application services in reverse order
    for ((i=${#APPLICATION_SERVICES[@]}-1; i>=0; i--)); do
        service="${APPLICATION_SERVICES[i]}"
        if systemctl --user is-active "$service" &>/dev/null; then
            echo -n "Stopping $service... "
            systemctl --user stop "$service" && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"
            sleep 2
        fi
    done
    
    # Stop core services last (except nginx for graceful shutdown pages)
    for ((i=${#CORE_SERVICES[@]}-1; i>=0; i--)); do
        service="${CORE_SERVICES[i]}"
        if [[ "$service" != "nginx" ]] && systemctl --user is-active "$service" &>/dev/null; then
            echo -n "Stopping $service... "
            systemctl --user stop "$service" && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"
        fi
    done
    
    echo -e "${GREEN}Service shutdown complete!${NC}"
}

restart_services() {
    echo -e "${BLUE}Restarting Network Upgrade System services...${NC}"
    stop_services
    sleep 5
    start_services
}

show_status() {
    echo -e "${BLUE}Network Upgrade System Service Status${NC}"
    echo "=================================="
    
    echo ""
    echo -e "${YELLOW}Core Services:${NC}"
    for service in "${CORE_SERVICES[@]}"; do
        if systemctl --user is-enabled "$service" &>/dev/null; then
            status=$(systemctl --user is-active "$service" 2>/dev/null || echo "inactive")
            if [[ "$status" == "active" ]]; then
                echo -e "  $service: ${GREEN}✓ $status${NC}"
            else
                echo -e "  $service: ${RED}✗ $status${NC}"
            fi
        fi
    done
    
    echo ""
    echo -e "${YELLOW}Application Services:${NC}"
    for service in "${APPLICATION_SERVICES[@]}"; do
        if systemctl --user is-enabled "$service" &>/dev/null; then
            status=$(systemctl --user is-active "$service" 2>/dev/null || echo "inactive")
            if [[ "$status" == "active" ]]; then
                echo -e "  $service: ${GREEN}✓ $status${NC}"
            else
                echo -e "  $service: ${RED}✗ $status${NC}"
            fi
        fi
    done
    
    echo ""
    echo -e "${YELLOW}Monitoring Services:${NC}"
    for service in "${MONITORING_SERVICES[@]}"; do
        if systemctl --user is-enabled "$service" &>/dev/null; then
            status=$(systemctl --user is-active "$service" 2>/dev/null || echo "inactive")
            if [[ "$status" == "active" ]]; then
                echo -e "  $service: ${GREEN}✓ $status${NC}"
            else
                echo -e "  $service: ${RED}✗ $status${NC}"
            fi
        fi
    done
    
    echo ""
    echo -e "${YELLOW}Timers:${NC}"
    for timer in "${TIMER_SERVICES[@]}"; do
        if systemctl --user list-unit-files "$timer" &>/dev/null; then
            status=$(systemctl --user is-active "$timer" 2>/dev/null || echo "inactive")
            if [[ "$status" == "active" ]]; then
                echo -e "  $timer: ${GREEN}✓ $status${NC}"
            else
                echo -e "  $timer: ${RED}✗ $status${NC}"
            fi
        fi
    done
    
    echo ""
    echo -e "${YELLOW}System Resources:${NC}"
    echo -n "  CPU Load: "
    uptime | awk -F'load average:' '{print $2}' | sed 's/^ *//'
    echo -n "  Memory Usage: "
    free | grep Mem | awk '{printf("%.1f%%\n", $3/$2 * 100.0)}'
    echo -n "  Disk Usage (/): "
    df / | awk 'NR==2{printf("%.1f%%\n", $3/$2*100)}'
}

enable_services() {
    echo -e "${BLUE}Enabling Network Upgrade System services for auto-start...${NC}"
    
    for service in "${ALL_SERVICES[@]}"; do
        echo -n "Enabling $service... "
        if systemctl --user enable "$service"; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC}"
        fi
    done
    
    for timer in "${TIMER_SERVICES[@]}"; do
        if systemctl --user list-unit-files "$timer" &>/dev/null; then
            echo -n "Enabling $timer... "
            if systemctl --user enable "$timer"; then
                echo -e "${GREEN}✓${NC}"
            else
                echo -e "${RED}✗${NC}"
            fi
        fi
    done
    
    echo -e "${GREEN}Services enabled for auto-start!${NC}"
}

disable_services() {
    echo -e "${BLUE}Disabling Network Upgrade System services from auto-start...${NC}"
    
    for timer in "${TIMER_SERVICES[@]}"; do
        if systemctl --user is-enabled "$timer" &>/dev/null; then
            echo -n "Disabling $timer... "
            systemctl --user disable "$timer" && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"
        fi
    done
    
    for service in "${ALL_SERVICES[@]}"; do
        if systemctl --user is-enabled "$service" &>/dev/null; then
            echo -n "Disabling $service... "
            systemctl --user disable "$service" && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"
        fi
    done
    
    echo -e "${GREEN}Services disabled from auto-start!${NC}"
}

show_logs() {
    echo -e "${BLUE}Recent logs from Network Upgrade System services${NC}"
    echo "================================================"
    
    for service in "${ALL_SERVICES[@]}"; do
        if systemctl --user is-active "$service" &>/dev/null; then
            echo ""
            echo -e "${YELLOW}=== $service ===${NC}"
            journalctl --user -u "$service" --no-pager -n 10
        fi
    done
}

case "${1:-}" in
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        restart_services
        ;;
    status)
        show_status
        ;;
    enable)
        enable_services
        ;;
    disable)
        disable_services
        ;;
    logs)
        show_logs
        ;;
    *)
        usage
        exit 1
        ;;
esac
EOF

    chmod +x /usr/local/bin/network-upgrade-services
    
    log "${GREEN}✓ Service management script created${NC}"
}

# Start core services first
start_core_services() {
    log "${BLUE}Starting core services...${NC}"
    
    for service in "${CORE_SERVICES[@]}"; do
        log "Starting $service..."
        systemctl --user enable "$service"
        systemctl --user start "$service"
        
        # Verify service is running
        sleep 3
        if systemctl --user is-active --quiet "$service"; then
            log "${GREEN}✓ $service started successfully${NC}"
        else
            log "${RED}✗ $service failed to start${NC}"
            systemctl --user status "$service" --no-pager
        fi
    done
    
    # Wait for core services to be fully ready
    log "Waiting for core services to initialize..."
    sleep 10
}

# Start application services
start_application_services() {
    log "${BLUE}Starting application services...${NC}"
    
    for service in "${APPLICATION_SERVICES[@]}"; do
        if systemctl --user list-unit-files "$service.service" &>/dev/null; then
            log "Starting $service..."
            systemctl --user enable "$service"
            systemctl --user start "$service"
            
            # Give each service time to start
            sleep 5
            
            if systemctl --user is-active --quiet "$service"; then
                log "${GREEN}✓ $service started successfully${NC}"
            else
                log "${YELLOW}⚠ $service may not have started correctly${NC}"
                systemctl --user status "$service" --no-pager | head -10
            fi
        else
            log "${YELLOW}⚠ $service not available (not installed?)${NC}"
        fi
    done
}

# Start monitoring and timer services
start_monitoring_services() {
    log "${BLUE}Starting monitoring services and timers...${NC}"
    
    # Start monitoring services
    for service in "${MONITORING_SERVICES[@]}"; do
        if systemctl --user list-unit-files "$service.service" &>/dev/null; then
            log "Starting $service..."
            systemctl --user enable "$service"
            systemctl --user start "$service"
            
            if systemctl --user is-active --quiet "$service"; then
                log "${GREEN}✓ $service started successfully${NC}"
            else
                log "${YELLOW}⚠ $service failed to start${NC}"
            fi
        fi
    done
    
    # Enable and start timers
    for timer in "${TIMER_SERVICES[@]}"; do
        if systemctl --user list-unit-files "$timer" &>/dev/null; then
            log "Enabling $timer..."
            systemctl --user enable "$timer"
            systemctl --user start "$timer"
            
            if systemctl --user is-active --quiet "$timer"; then
                log "${GREEN}✓ $timer enabled and started${NC}"
            else
                log "${YELLOW}⚠ $timer failed to start${NC}"
            fi
        fi
    done
}

# Create system health check
create_health_check() {
    log "${BLUE}Creating comprehensive system health check...${NC}"
    
    cat > /usr/local/bin/network-upgrade-health-full << 'EOF'
#!/bin/bash
# Comprehensive Network Upgrade System Health Check

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================"
echo "Network Device Upgrade System Health Check"
echo "========================================"
echo "Date: $(date)"
echo ""

# System information
echo -e "${BLUE}=== System Information ===${NC}"
echo "Hostname: $(hostname)"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"')"
echo "Kernel: $(uname -r)"
echo "Uptime: $(uptime -p)"
echo ""

# Resource usage
echo -e "${BLUE}=== Resource Usage ===${NC}"
echo "CPU Load: $(uptime | awk -F'load average:' '{print $2}' | sed 's/^ *//')"
echo "Memory Usage: $(free | grep Mem | awk '{printf("%.1f%% (%s/%s)\n", $3/$2 * 100.0, $3, $2)}')"
echo "Disk Usage (/): $(df -h / | awk 'NR==2{printf("%s (%s used of %s)\n", $5, $3, $2)}')"
echo "Disk Usage (/opt): $(df -h /opt 2>/dev/null | awk 'NR==2{printf("%s (%s used of %s)\n", $5, $3, $2)}' || echo 'N/A (same as /)')"
echo ""

# Service status
echo -e "${BLUE}=== Service Status ===${NC}"
services=("redis" "nginx" "netbox" "netbox-rq" "awx-web" "awx-task" "awx-scheduler" "telegraf")
for service in "${services[@]}"; do
    if systemctl --user list-unit-files "$service.service" &>/dev/null; then
        status=$(systemctl --user is-active "$service" 2>/dev/null)
        if [[ "$status" == "active" ]]; then
            echo -e "$service: ${GREEN}✓ running${NC}"
        else
            echo -e "$service: ${RED}✗ $status${NC}"
        fi
    else
        echo -e "$service: ${YELLOW}⚠ not installed${NC}"
    fi
done
echo ""

# Timer status
echo -e "${BLUE}=== Timer Status ===${NC}"
timers=("netbox-housekeeping.timer" "ssl-cert-renewal.timer" "redis-monitor.timer")
for timer in "${timers[@]}"; do
    if systemctl --user list-unit-files "$timer" &>/dev/null; then
        status=$(systemctl --user is-active "$timer" 2>/dev/null)
        if [[ "$status" == "active" ]]; then
            next_run=$(systemctl --user list-timers "$timer" --no-pager | grep "$timer" | awk '{print $1, $2, $3}')
            echo -e "$timer: ${GREEN}✓ active${NC} (next: $next_run)"
        else
            echo -e "$timer: ${RED}✗ $status${NC}"
        fi
    else
        echo -e "$timer: ${YELLOW}⚠ not configured${NC}"
    fi
done
echo ""

# Network connectivity
echo -e "${BLUE}=== Network Connectivity ===${NC}"
if curl -s --connect-timeout 5 https://8.8.8.8:443 >/dev/null; then
    echo -e "Internet connectivity: ${GREEN}✓ available${NC}"
else
    echo -e "Internet connectivity: ${RED}✗ unavailable${NC}"
fi
echo ""

# Database status
echo -e "${BLUE}=== Database Status ===${NC}"

# AWX database
if [[ -f "/opt/network-upgrade/awx/database/awx.db" ]]; then
    awx_db_size=$(du -h /opt/network-upgrade/awx/database/awx.db | cut -f1)
    echo -e "AWX database: ${GREEN}✓ available${NC} ($awx_db_size)"
else
    echo -e "AWX database: ${RED}✗ not found${NC}"
fi

# NetBox database
if [[ -f "/opt/network-upgrade/netbox/database/netbox.db" ]]; then
    netbox_db_size=$(du -h /opt/network-upgrade/netbox/database/netbox.db | cut -f1)
    echo -e "NetBox database: ${GREEN}✓ available${NC} ($netbox_db_size)"
else
    echo -e "NetBox database: ${RED}✗ not found${NC}"
fi

# Redis connectivity
if redis-cli -a "ChangeMeInProduction123!" ping &>/dev/null; then
    redis_memory=$(redis-cli -a "ChangeMeInProduction123!" INFO memory | grep used_memory_human | cut -d: -f2 | tr -d '\r')
    echo -e "Redis: ${GREEN}✓ responding${NC} (memory: $redis_memory)"
else
    echo -e "Redis: ${RED}✗ not responding${NC}"
fi
echo ""

# Web interface availability
echo -e "${BLUE}=== Web Interface Status ===${NC}"
if curl -k -s --connect-timeout 10 https://localhost:8443/ >/dev/null; then
    echo -e "AWX Web UI: ${GREEN}✓ responding${NC} (https://localhost:8443/)"
else
    echo -e "AWX Web UI: ${RED}✗ not responding${NC} (https://localhost:8443/)"
fi

if curl -k -s --connect-timeout 10 https://localhost:8000/ >/dev/null; then
    echo -e "NetBox Web UI: ${GREEN}✓ responding${NC} (https://localhost:8000/)"
else
    echo -e "NetBox Web UI: ${RED}✗ not responding${NC} (https://localhost:8000/)"
fi
echo ""

# SSL certificate status
echo -e "${BLUE}=== SSL Certificate Status ===${NC}"
if [[ -f "/etc/ssl/certs/network-upgrade.crt" ]]; then
    if openssl x509 -in /etc/ssl/certs/network-upgrade.crt -noout -checkend 2592000; then
        expiry_date=$(openssl x509 -in /etc/ssl/certs/network-upgrade.crt -noout -enddate | cut -d= -f2)
        echo -e "SSL Certificate: ${GREEN}✓ valid${NC} (expires: $expiry_date)"
    else
        echo -e "SSL Certificate: ${YELLOW}⚠ expires within 30 days${NC}"
    fi
else
    echo -e "SSL Certificate: ${RED}✗ not found${NC}"
fi
echo ""

# Log file status
echo -e "${BLUE}=== Log File Status ===${NC}"
log_dirs=("/var/log/network-upgrade" "/var/log/awx" "/var/log/netbox" "/var/log/redis" "/var/log/telegraf")
for log_dir in "${log_dirs[@]}"; do
    if [[ -d "$log_dir" ]]; then
        log_count=$(find "$log_dir" -name "*.log" -type f 2>/dev/null | wc -l)
        log_size=$(du -sh "$log_dir" 2>/dev/null | cut -f1 || echo "0")
        echo "$log_dir: ${GREEN}✓ $log_count files${NC} ($log_size)"
    else
        echo "$log_dir: ${YELLOW}⚠ directory not found${NC}"
    fi
done
echo ""

# Recent errors
echo -e "${BLUE}=== Recent System Errors ===${NC}"
error_count=$(journalctl --user --since="24 hours ago" -p err --no-pager | wc -l)
if [[ $error_count -eq 0 ]]; then
    echo -e "System errors (24h): ${GREEN}✓ none${NC}"
else
    echo -e "System errors (24h): ${YELLOW}⚠ $error_count errors${NC}"
    echo "Recent errors:"
    journalctl --user --since="24 hours ago" -p err --no-pager | tail -5
fi
echo ""

echo "========================================"
echo "Health check completed at $(date)"
echo "========================================"
EOF

    chmod +x /usr/local/bin/network-upgrade-health-full
    
    log "${GREEN}✓ Comprehensive health check script created${NC}"
}

# Verify all services are running
verify_services() {
    log "${BLUE}Verifying all services are running correctly...${NC}"
    
    sleep 10  # Allow services time to fully initialize
    
    # Check each service category
    failed_services=()
    
    # Core services
    for service in "${CORE_SERVICES[@]}"; do
        if systemctl --user is-active --quiet "$service"; then
            log "${GREEN}✓ $service is running${NC}"
        else
            log "${RED}✗ $service is not running${NC}"
            failed_services+=("$service")
        fi
    done
    
    # Application services
    for service in "${APPLICATION_SERVICES[@]}"; do
        if systemctl --user list-unit-files "$service.service" &>/dev/null; then
            if systemctl --user is-active --quiet "$service"; then
                log "${GREEN}✓ $service is running${NC}"
            else
                log "${RED}✗ $service is not running${NC}"
                failed_services+=("$service")
            fi
        fi
    done
    
    # Monitoring services
    for service in "${MONITORING_SERVICES[@]}"; do
        if systemctl --user list-unit-files "$service.service" &>/dev/null; then
            if systemctl --user is-active --quiet "$service"; then
                log "${GREEN}✓ $service is running${NC}"
            else
                log "${RED}✗ $service is not running${NC}"
                failed_services+=("$service")
            fi
        fi
    done
    
    # Report results
    if [[ ${#failed_services[@]} -eq 0 ]]; then
        log "${GREEN}✓ All services are running successfully!${NC}"
        return 0
    else
        log "${YELLOW}⚠ Some services failed to start:${NC}"
        for service in "${failed_services[@]}"; do
            log "  - $service"
            systemctl --user status "$service" --no-pager | head -5
        done
        return 1
    fi
}

# Create startup completion marker
create_completion_marker() {
    log "${BLUE}Creating system startup completion marker...${NC}"
    
    cat > /etc/network-upgrade/system_ready << EOF
# Network Device Upgrade Management System
# System Ready Marker File

INSTALLATION_DATE=$(date)
INSTALLATION_COMPLETED=true
SYSTEM_VERSION=1.0.0

# Service Status (at time of completion)
$(systemctl --user is-active redis nginx netbox netbox-rq awx-web awx-task awx-scheduler telegraf 2>/dev/null | \
  paste <(echo -e "redis\nnginx\nnetbox\nnetbox-rq\nawx-web\nawx-task\nawx-scheduler\ntelegraf") - | \
  sed 's/\t/=/')

# Web Interfaces
AWX_URL=https://localhost:8443/
NETBOX_URL=https://localhost:8000/

# Key Files
SYSTEM_CONFIG=/etc/network-upgrade/config.yml
AWX_CONFIG=/opt/network-upgrade/awx/config/settings.py
NETBOX_CONFIG=/opt/network-upgrade/netbox/config/configuration.py
SSL_CERT=/etc/ssl/certs/network-upgrade.crt
SSL_KEY=/etc/ssl/private/network-upgrade.key

# Management Commands
SERVICE_MANAGER=/usr/local/bin/network-upgrade-services
HEALTH_CHECK=/usr/local/bin/network-upgrade-health-full
BACKUP_SCRIPT=/usr/local/bin/network-upgrade-backup

# Installation Complete
EOF
    
    chmod 644 /etc/network-upgrade/system_ready
    
    log "${GREEN}✓ System ready marker created${NC}"
}

# Main service creation function
main() {
    log "${GREEN}Starting Network Upgrade System services creation...${NC}"
    log "${BLUE}Service startup initiated at: $(date)${NC}"
    
    check_prerequisites
    create_service_manager
    start_core_services
    start_application_services
    start_monitoring_services
    create_health_check
    
    if verify_services; then
        create_completion_marker
        
        log "${GREEN}✓ Network Upgrade System services started successfully!${NC}"
        log "${BLUE}Service startup completed at: $(date)${NC}"
        
        echo ""
        log "${YELLOW}System Startup Summary:${NC}"
        log "• All core services: Running"
        log "• Application services: Running"
        log "• Monitoring services: Running"
        log "• Timer services: Enabled"
        log ""
        log "${YELLOW}Web Interfaces:${NC}"
        log "• AWX: https://localhost:8443/"
        log "• NetBox: https://localhost:8000/"
        log ""
        log "${YELLOW}Management Commands:${NC}"
        log "• Service control: network-upgrade-services {start|stop|restart|status}"
        log "• Health check: network-upgrade-health-full"
        log "• System backup: network-upgrade-backup"
        log ""
        log "${YELLOW}Next Steps:${NC}"
        log "1. Access web interfaces and change default passwords"
        log "2. Configure AWX projects and job templates"
        log "3. Import device inventory into NetBox"
        log "4. Set up InfluxDB connection for metrics"
        log "5. Configure external integrations as needed"
        log ""
        log "${GREEN}🎉 Network Device Upgrade Management System is ready for use!${NC}"
        
    else
        log "${RED}✗ Some services failed to start. Check logs and retry.${NC}"
        log "Use 'network-upgrade-services status' to check service states"
        log "Use 'network-upgrade-services logs' to view recent logs"
        exit 1
    fi
}

# Run main function
main "$@"