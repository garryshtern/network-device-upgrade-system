#!/bin/bash

# Telegraf Configuration Script for Network Upgrade System
# Integration with existing InfluxDB v2 for metrics collection

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_FILE="/var/log/network-upgrade/telegraf-install.log"
TELEGRAF_USER="telegraf"
TELEGRAF_CONFIG_DIR="/etc/telegraf"
TELEGRAF_DATA_DIR="/var/lib/telegraf"

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

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error_exit "This script must be run as root"
fi

# Check if base system is installed
if [[ ! -f "/etc/network-upgrade/config.yml" ]]; then
    error_exit "Base system not installed. Run ./install/install-system.sh first"
fi

# Prompt for InfluxDB configuration
get_influxdb_config() {
    log "${BLUE}InfluxDB v2 Configuration Required${NC}"
    
    echo ""
    echo "This script will configure Telegraf to connect to your existing InfluxDB v2 instance."
    echo "Please provide the following information:"
    echo ""
    
    read -p "InfluxDB URL (e.g., https://influxdb.example.com:8086): " INFLUXDB_URL
    read -p "InfluxDB Organization: " INFLUXDB_ORG  
    read -p "InfluxDB Bucket (default: network-upgrades): " INFLUXDB_BUCKET
    read -s -p "InfluxDB Token: " INFLUXDB_TOKEN
    echo ""
    
    # Set defaults
    INFLUXDB_BUCKET=${INFLUXDB_BUCKET:-"network-upgrades"}
    
    # Validate inputs
    if [[ -z "$INFLUXDB_URL" || -z "$INFLUXDB_ORG" || -z "$INFLUXDB_TOKEN" ]]; then
        error_exit "All InfluxDB configuration parameters are required"
    fi
    
    log "${GREEN}✓ InfluxDB configuration collected${NC}"
}

# Install Telegraf
install_telegraf() {
    log "${BLUE}Installing Telegraf...${NC}"
    
    case $(lsb_release -is 2>/dev/null || echo "Unknown") in
        "CentOS"|"RedHat"|"Rocky"|"AlmaLinux")
            # Add InfluxData repository
            cat > /etc/yum.repos.d/influxdb.repo << 'EOF'
[influxdb]
name = InfluxDB Repository - RHEL
baseurl = https://repos.influxdata.com/rhel/$releasever/$basearch/stable
enabled = 1
gpgcheck = 1
gpgkey = https://repos.influxdata.com/influxdb.key
EOF
            dnf install -y telegraf
            ;;
        "Ubuntu"|"Debian")
            # Add InfluxData repository
            curl -sL https://repos.influxdata.com/influxdb.key | apt-key add -
            echo "deb https://repos.influxdata.com/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/influxdb.list
            apt-get update
            apt-get install -y telegraf
            ;;
        *)
            # Manual installation
            ARCH=$(uname -m)
            case $ARCH in
                x86_64) ARCH="amd64" ;;
                aarch64) ARCH="arm64" ;;
                armv7l) ARCH="armhf" ;;
                *) error_exit "Unsupported architecture: $ARCH" ;;
            esac
            
            TELEGRAF_VERSION="1.28.3"
            cd /tmp
            curl -L "https://dl.influxdata.com/telegraf/releases/telegraf-${TELEGRAF_VERSION}_linux_${ARCH}.tar.gz" -o telegraf.tar.gz
            tar -xzf telegraf.tar.gz
            cp "telegraf-${TELEGRAF_VERSION}/usr/bin/telegraf" /usr/bin/
            chmod +x /usr/bin/telegraf
            
            # Create telegraf user and group
            groupadd -r telegraf || true
            useradd -r -g telegraf -s /bin/false -d /var/lib/telegraf telegraf || true
            ;;
    esac
    
    # Create directories
    mkdir -p "${TELEGRAF_CONFIG_DIR}/telegraf.d"
    mkdir -p "${TELEGRAF_DATA_DIR}"
    mkdir -p /var/log/telegraf
    
    # Set ownership
    chown -R telegraf:telegraf "${TELEGRAF_DATA_DIR}"
    chown -R telegraf:telegraf /var/log/telegraf
    chown -R root:telegraf "${TELEGRAF_CONFIG_DIR}"
    chmod 750 "${TELEGRAF_CONFIG_DIR}"
    
    log "${GREEN}✓ Telegraf installed${NC}"
}

# Configure Telegraf
configure_telegraf() {
    log "${BLUE}Configuring Telegraf...${NC}"
    
    # Main Telegraf configuration
    cat > "${TELEGRAF_CONFIG_DIR}/telegraf.conf" << EOF
# Telegraf Configuration for Network Upgrade Management System
# Optimized for single server deployment with InfluxDB v2

[global_tags]
  environment = "production"
  system = "network-upgrade"
  
[agent]
  interval = "60s"
  round_interval = true
  metric_batch_size = 1000
  metric_buffer_limit = 10000
  collection_jitter = "0s"
  flush_interval = "10s"
  flush_jitter = "0s"
  precision = ""
  hostname = ""
  omit_hostname = false
  debug = false
  quiet = false
  logfile = "/var/log/telegraf/telegraf.log"
  logfile_rotation_interval = "24h"
  logfile_rotation_max_size = "100MB"
  logfile_rotation_max_archives = 5

###############################################################################
#                            OUTPUT PLUGINS                                  #
###############################################################################

# InfluxDB v2 output plugin
[[outputs.influxdb_v2]]
  urls = ["${INFLUXDB_URL}"]
  token = "${INFLUXDB_TOKEN}"
  organization = "${INFLUXDB_ORG}"
  bucket = "${INFLUXDB_BUCKET}"
  timeout = "30s"
  user_agent = "telegraf-network-upgrade"
  
  # Optional TLS Config
  # tls_ca = "/etc/ssl/certs/ca-certificates.crt"
  # tls_cert = "/etc/ssl/certs/telegraf.crt"
  # tls_key = "/etc/ssl/private/telegraf.key"
  # insecure_skip_verify = false

###############################################################################
#                            INPUT PLUGINS                                   #
###############################################################################

# System metrics
[[inputs.cpu]]
  percpu = true
  totalcpu = true
  collect_cpu_time = false
  report_active = false

[[inputs.disk]]
  ignore_fs = ["tmpfs", "devtmpfs", "devfs", "iso9660", "overlay", "aufs", "squashfs"]

[[inputs.diskio]]

[[inputs.kernel]]

[[inputs.mem]]

[[inputs.processes]]

[[inputs.swap]]

[[inputs.system]]

[[inputs.net]]

[[inputs.netstat]]

# System services monitoring
[[inputs.systemd_units]]
  pattern = "(awx-*|netbox*|network-upgrade|redis|nginx|telegraf)"

# Redis monitoring
[[inputs.redis]]
  servers = ["tcp://127.0.0.1:6379"]
  password = "ChangeMeInProduction123!"

# Nginx monitoring
[[inputs.nginx]]
  urls = ["http://localhost/nginx_status"]

# Log parsing for application logs  
[[inputs.tail]]
  files = ["/var/log/network-upgrade/*.log"]
  from_beginning = false
  pipe = false
  watch_method = "inotify"
  data_format = "grok"
  grok_patterns = [
    "%{TIMESTAMP_ISO8601:timestamp} - %{DATA:logger} - %{LOGLEVEL:level} - %{GREEDYDATA:message}"
  ]
  grok_timezone = "UTC"
  name_override = "network_upgrade_logs"
  [inputs.tail.tags]
    log_type = "application"

[[inputs.tail]]
  files = ["/var/log/awx/*.log"]
  from_beginning = false
  pipe = false
  watch_method = "inotify"
  data_format = "grok"
  grok_patterns = [
    "%{LOGLEVEL:level} %{TIMESTAMP_ISO8601:timestamp} %{DATA:module} %{INT:process} %{INT:thread} %{GREEDYDATA:message}"
  ]
  grok_timezone = "UTC"
  name_override = "awx_logs"
  [inputs.tail.tags]
    log_type = "awx"

[[inputs.tail]]
  files = ["/var/log/netbox/*.log"]  
  from_beginning = false
  pipe = false
  watch_method = "inotify"
  data_format = "grok"
  grok_patterns = [
    "%{LOGLEVEL:level} %{TIMESTAMP_ISO8601:timestamp} %{DATA:module} %{INT:process} %{INT:thread} %{GREEDYDATA:message}"
  ]
  grok_timezone = "UTC"
  name_override = "netbox_logs"
  [inputs.tail.tags]
    log_type = "netbox"

# Include additional configuration files
[agent]
  include = ["/etc/telegraf/telegraf.d/*.conf"]
EOF
    
    # Create custom metrics collection scripts directory
    mkdir -p /usr/local/bin/telegraf-scripts
    
    log "${GREEN}✓ Main Telegraf configuration created${NC}"
}

# Create custom metric collection scripts
create_metric_scripts() {
    log "${BLUE}Creating custom metric collection scripts...${NC}"
    
    # AWX metrics collection script
    cat > /usr/local/bin/telegraf-scripts/awx-metrics.py << 'EOF'
#!/usr/bin/env python3
"""
AWX Metrics Collection Script for Telegraf
Collects job status and performance metrics from AWX
"""

import json
import sqlite3
import sys
from datetime import datetime, timedelta
import requests
import urllib3
urllib3.disable_warnings()

def get_awx_metrics():
    """Collect AWX metrics from database and API"""
    metrics = []
    timestamp = datetime.utcnow().isoformat() + "Z"
    
    try:
        # Connect to AWX SQLite database
        conn = sqlite3.connect('/opt/network-upgrade/awx/database/awx.db')
        cursor = conn.cursor()
        
        # Job status counts (last 24 hours)
        cursor.execute("""
            SELECT status, COUNT(*) as count 
            FROM main_unifiedjob 
            WHERE created > datetime('now', '-24 hours')
            GROUP BY status
        """)
        
        for status, count in cursor.fetchall():
            metrics.append(f"awx_jobs,status={status} count={count}i {timestamp}")
        
        # Active job count
        cursor.execute("""
            SELECT COUNT(*) as count 
            FROM main_unifiedjob 
            WHERE status IN ('running', 'pending')
        """)
        
        active_count = cursor.fetchone()[0]
        metrics.append(f"awx_active_jobs count={active_count}i {timestamp}")
        
        conn.close()
        
    except Exception as e:
        print(f"# ERROR: Failed to collect AWX metrics: {e}", file=sys.stderr)
        return
    
    # Output metrics in InfluxDB line protocol
    for metric in metrics:
        print(metric)

if __name__ == "__main__":
    get_awx_metrics()
EOF

    # NetBox metrics collection script
    cat > /usr/local/bin/telegraf-scripts/netbox-metrics.py << 'EOF'
#!/usr/bin/env python3
"""
NetBox Metrics Collection Script for Telegraf
Collects device inventory and compliance metrics
"""

import json
import sqlite3
import sys
from datetime import datetime
import requests
import urllib3
urllib3.disable_warnings()

def get_netbox_metrics():
    """Collect NetBox device inventory metrics"""
    metrics = []
    timestamp = datetime.utcnow().isoformat() + "Z"
    
    try:
        # Connect to NetBox SQLite database
        conn = sqlite3.connect('/opt/network-upgrade/netbox/database/netbox.db')
        cursor = conn.cursor()
        
        # Device count by status
        cursor.execute("""
            SELECT dcim_devicestatus.value, COUNT(*) as count
            FROM dcim_device 
            JOIN dcim_devicestatus ON dcim_device.status_id = dcim_devicestatus.id
            GROUP BY dcim_devicestatus.value
        """)
        
        for status, count in cursor.fetchall():
            metrics.append(f"netbox_devices,status={status} count={count}i {timestamp}")
        
        # Device count by manufacturer
        cursor.execute("""
            SELECT dcim_manufacturer.name, COUNT(*) as count
            FROM dcim_device
            JOIN dcim_devicetype ON dcim_device.device_type_id = dcim_devicetype.id
            JOIN dcim_manufacturer ON dcim_devicetype.manufacturer_id = dcim_manufacturer.id
            GROUP BY dcim_manufacturer.name
        """)
        
        for manufacturer, count in cursor.fetchall():
            metrics.append(f"netbox_devices,manufacturer={manufacturer} count={count}i {timestamp}")
        
        # Device count by site
        cursor.execute("""
            SELECT dcim_site.name, COUNT(*) as count
            FROM dcim_device
            JOIN dcim_site ON dcim_device.site_id = dcim_site.id
            GROUP BY dcim_site.name
        """)
        
        for site, count in cursor.fetchall():
            metrics.append(f"netbox_devices,site={site} count={count}i {timestamp}")
            
        conn.close()
        
    except Exception as e:
        print(f"# ERROR: Failed to collect NetBox metrics: {e}", file=sys.stderr)
        return
    
    # Output metrics in InfluxDB line protocol
    for metric in metrics:
        print(metric)

if __name__ == "__main__":
    get_netbox_metrics()
EOF

    # Network validation metrics script
    cat > /usr/local/bin/telegraf-scripts/validation-metrics.py << 'EOF'
#!/usr/bin/env python3
"""
Network Validation Metrics Collection Script
Collects validation results and compliance data
"""

import json
import os
import sys
from datetime import datetime
from pathlib import Path

def get_validation_metrics():
    """Collect network validation metrics from log files"""
    metrics = []
    timestamp = datetime.utcnow().isoformat() + "Z"
    
    validation_log_dir = Path("/var/log/network-upgrade")
    
    if not validation_log_dir.exists():
        return
    
    try:
        # Parse validation result logs
        validation_files = list(validation_log_dir.glob("validation_*.json"))
        
        success_count = 0
        failure_count = 0
        
        for log_file in validation_files[-100:]:  # Last 100 files
            try:
                with open(log_file, 'r') as f:
                    data = json.load(f)
                    if data.get('success', False):
                        success_count += 1
                    else:
                        failure_count += 1
            except (json.JSONDecodeError, KeyError):
                continue
        
        metrics.append(f"network_validations,result=success count={success_count}i {timestamp}")
        metrics.append(f"network_validations,result=failure count={failure_count}i {timestamp}")
        
    except Exception as e:
        print(f"# ERROR: Failed to collect validation metrics: {e}", file=sys.stderr)
        return
    
    # Output metrics in InfluxDB line protocol
    for metric in metrics:
        print(metric)

if __name__ == "__main__":
    get_validation_metrics()
EOF

    # Make scripts executable
    chmod +x /usr/local/bin/telegraf-scripts/*.py
    chown -R telegraf:telegraf /usr/local/bin/telegraf-scripts/
    
    log "${GREEN}✓ Custom metric collection scripts created${NC}"
}

# Configure custom input plugins
configure_custom_inputs() {
    log "${BLUE}Configuring custom input plugins...${NC}"
    
    # AWX metrics input
    cat > "${TELEGRAF_CONFIG_DIR}/telegraf.d/awx-metrics.conf" << 'EOF'
# AWX Custom Metrics Collection
[[inputs.exec]]
  commands = ["/usr/local/bin/telegraf-scripts/awx-metrics.py"]
  timeout = "30s"
  data_format = "influx"
  interval = "60s"
  name_override = "awx_metrics"
EOF

    # NetBox metrics input
    cat > "${TELEGRAF_CONFIG_DIR}/telegraf.d/netbox-metrics.conf" << 'EOF'
# NetBox Custom Metrics Collection  
[[inputs.exec]]
  commands = ["/usr/local/bin/telegraf-scripts/netbox-metrics.py"]
  timeout = "30s"
  data_format = "influx"
  interval = "300s"  # Every 5 minutes
  name_override = "netbox_metrics"
EOF

    # Network validation metrics input
    cat > "${TELEGRAF_CONFIG_DIR}/telegraf.d/validation-metrics.conf" << 'EOF'
# Network Validation Metrics Collection
[[inputs.exec]]
  commands = ["/usr/local/bin/telegraf-scripts/validation-metrics.py"]
  timeout = "30s"
  data_format = "influx"
  interval = "120s"  # Every 2 minutes
  name_override = "validation_metrics"
EOF
    
    # File-based metrics for upgrade progress
    cat > "${TELEGRAF_CONFIG_DIR}/telegraf.d/upgrade-progress.conf" << 'EOF'
# Upgrade Progress Metrics from JSON Files
[[inputs.file]]
  files = ["/var/log/network-upgrade/upgrade_*.json"]
  data_format = "json"
  json_string_fields = ["device_id", "phase", "status"]
  name_override = "upgrade_progress"
  interval = "30s"
EOF

    log "${GREEN}✓ Custom input plugins configured${NC}"
}

# Configure Nginx status for monitoring
configure_nginx_status() {
    log "${BLUE}Configuring Nginx status endpoint...${NC}"
    
    # Add status location to default site
    if ! grep -q "nginx_status" /etc/nginx/sites-available/default; then
        sed -i '/location \/ {/i \    location /nginx_status {\n        stub_status on;\n        access_log off;\n        allow 127.0.0.1;\n        deny all;\n    }\n' /etc/nginx/sites-available/default
        
        # Reload Nginx
        nginx -t && systemctl reload nginx
        log "${GREEN}✓ Nginx status endpoint configured${NC}"
    else
        log "${YELLOW}Nginx status endpoint already configured${NC}"
    fi
}

# Test Telegraf configuration
test_telegraf_config() {
    log "${BLUE}Testing Telegraf configuration...${NC}"
    
    # Test configuration syntax
    if telegraf --config "${TELEGRAF_CONFIG_DIR}/telegraf.conf" --test --quiet; then
        log "${GREEN}✓ Telegraf configuration is valid${NC}"
    else
        error_exit "Telegraf configuration test failed"
    fi
    
    # Test InfluxDB connectivity
    if timeout 10 telegraf --config "${TELEGRAF_CONFIG_DIR}/telegraf.conf" --test --input-filter cpu --output-filter influxdb_v2; then
        log "${GREEN}✓ InfluxDB connectivity test passed${NC}"
    else
        log "${YELLOW}⚠ InfluxDB connectivity test failed - check configuration${NC}"
    fi
}

# Start and enable Telegraf service
start_telegraf_service() {
    log "${BLUE}Starting Telegraf service...${NC}"
    
    # Enable and start Telegraf
    systemctl enable telegraf
    systemctl start telegraf
    
    # Wait for service to start
    sleep 5
    
    if systemctl is-active --quiet telegraf; then
        log "${GREEN}✓ Telegraf service is running${NC}"
    else
        log "${RED}✗ Telegraf service failed to start${NC}"
        systemctl status telegraf --no-pager
        journalctl -u telegraf --no-pager -n 20
    fi
}

# Update system configuration
update_system_config() {
    log "${BLUE}Updating system configuration...${NC}"
    
    # Update main config file with InfluxDB settings
    sed -i "s|influxdb:.*url:.*\"\"|influxdb:\n  url: \"${INFLUXDB_URL}\"\n  token: \"${INFLUXDB_TOKEN}\"\n  org: \"${INFLUXDB_ORG}\"\n  bucket: \"${INFLUXDB_BUCKET}\"|" /etc/network-upgrade/config.yml
    
    log "${GREEN}✓ System configuration updated${NC}"
}

# Main installation function
main() {
    log "${GREEN}Starting Telegraf configuration...${NC}"
    log "${BLUE}Configuration started at: $(date)${NC}"
    
    get_influxdb_config
    install_telegraf
    configure_telegraf
    create_metric_scripts
    configure_custom_inputs
    configure_nginx_status
    test_telegraf_config
    start_telegraf_service
    update_system_config
    
    log "${GREEN}✓ Telegraf configuration completed successfully!${NC}"
    log "${BLUE}Configuration finished at: $(date)${NC}"
    
    echo ""
    log "${YELLOW}Telegraf Configuration Summary:${NC}"
    log "• Configuration file: ${TELEGRAF_CONFIG_DIR}/telegraf.conf"
    log "• Custom inputs: ${TELEGRAF_CONFIG_DIR}/telegraf.d/"
    log "• Custom scripts: /usr/local/bin/telegraf-scripts/"
    log "• Log file: /var/log/telegraf/telegraf.log"
    log "• InfluxDB URL: ${INFLUXDB_URL}"
    log "• InfluxDB Bucket: ${INFLUXDB_BUCKET}"
    log ""
    log "${YELLOW}Metrics being collected:${NC}"
    log "• System metrics (CPU, memory, disk, network)"
    log "• Service status (AWX, NetBox, Redis, Nginx)"
    log "• Application logs (parsed and structured)"
    log "• Custom AWX job metrics"
    log "• NetBox device inventory metrics"
    log "• Network validation results"
    log "• Upgrade progress tracking"
    log ""
    log "${YELLOW}Next steps:${NC}"
    log "1. Verify metrics are appearing in InfluxDB"
    log "2. Set up Grafana dashboards for visualization"
    log "3. Configure alerting rules based on collected metrics"
    log "4. Run ./install/setup-ssl.sh to configure SSL certificates"
}

# Run main function
main "$@"