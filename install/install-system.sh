#!/bin/bash

# Network Device Upgrade Management System - Base System Installation
# Single server deployment with SQLite backend
# Optimized for limited resources (4 CPU, 8GB RAM)

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_DIR="/var/log/network-upgrade"
DATA_DIR="/opt/network-upgrade"
BACKUP_DIR="/var/backups/network-upgrade"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging setup
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/system-install.log"

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

# Detect OS and version
detect_os() {
    log "${BLUE}Detecting operating system...${NC}"
    
    if [[ -f /etc/redhat-release ]]; then
        OS="rhel"
        if grep -q "CentOS" /etc/redhat-release; then
            DISTRO="centos"
        elif grep -q "Red Hat" /etc/redhat-release; then
            DISTRO="rhel"
        else
            DISTRO="rhel"
        fi
        OS_VERSION=$(rpm -E %{rhel})
    elif [[ -f /etc/debian_version ]]; then
        OS="debian"
        if grep -q "Ubuntu" /etc/os-release; then
            DISTRO="ubuntu"
            OS_VERSION=$(lsb_release -rs | cut -d. -f1)
        else
            DISTRO="debian"
            OS_VERSION=$(cat /etc/debian_version | cut -d. -f1)
        fi
    else
        error_exit "Unsupported operating system. This script supports RHEL/CentOS 8+ or Ubuntu 20.04+"
    fi
    
    log "${GREEN}✓ Detected: ${DISTRO^} ${OS_VERSION}${NC}"
    
    # Version checks
    if [[ "$OS" == "rhel" ]] && [[ "$OS_VERSION" -lt 8 ]]; then
        error_exit "RHEL/CentOS 8 or higher is required"
    fi
    
    if [[ "$DISTRO" == "ubuntu" ]] && [[ "$OS_VERSION" -lt 20 ]]; then
        error_exit "Ubuntu 20.04 or higher is required"
    fi
}

# System resource checks
check_system_resources() {
    log "${BLUE}Checking system resources...${NC}"
    
    # CPU check
    CPU_CORES=$(nproc)
    if [[ $CPU_CORES -lt 4 ]]; then
        log "${YELLOW}WARNING: Only ${CPU_CORES} CPU cores detected. Minimum 4 recommended.${NC}"
    else
        log "${GREEN}✓ CPU cores: ${CPU_CORES}${NC}"
    fi
    
    # Memory check
    MEMORY_GB=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $MEMORY_GB -lt 8 ]]; then
        log "${YELLOW}WARNING: Only ${MEMORY_GB}GB RAM detected. Minimum 8GB recommended.${NC}"
    else
        log "${GREEN}✓ Memory: ${MEMORY_GB}GB${NC}"
    fi
    
    # Disk space check
    DISK_AVAIL_GB=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
    if [[ $DISK_AVAIL_GB -lt 100 ]]; then
        log "${YELLOW}WARNING: Only ${DISK_AVAIL_GB}GB disk space available. Minimum 100GB recommended.${NC}"
    else
        log "${GREEN}✓ Disk space: ${DISK_AVAIL_GB}GB available${NC}"
    fi
}

# Install system packages
install_system_packages() {
    log "${BLUE}Installing system packages...${NC}"
    
    case $OS in
        rhel)
            # Enable EPEL repository
            if [[ "$DISTRO" == "centos" ]]; then
                dnf install -y epel-release
            else
                dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-${OS_VERSION}.noarch.rpm
            fi
            
            # Install packages
            dnf update -y
            dnf groupinstall -y "Development Tools"
            dnf install -y \
                python3 python3-pip python3-venv python3-devel \
                git curl wget vim unzip tar \
                sqlite sqlite-devel \
                redis nginx \
                nodejs npm \
                openssl openssl-devel \
                gcc gcc-c++ make \
                rsync sshpass \
                htop tmux screen \
                logrotate crontabs \
                firewalld
            ;;
        debian)
            # Update package lists
            apt-get update -y
            
            # Install packages
            apt-get install -y \
                python3 python3-pip python3-venv python3-dev \
                git curl wget vim unzip tar \
                sqlite3 libsqlite3-dev \
                redis-server nginx \
                nodejs npm \
                openssl libssl-dev \
                build-essential \
                rsync sshpass \
                htop tmux screen \
                logrotate cron \
                ufw
            ;;
    esac
    
    log "${GREEN}✓ System packages installed${NC}"
}

# Create system user and directories
setup_system_user() {
    log "${BLUE}Setting up system user and directories...${NC}"
    
    # Create network-upgrade user
    if ! id "network-upgrade" &>/dev/null; then
        useradd -r -d "${DATA_DIR}" -s /bin/bash -c "Network Upgrade System" network-upgrade
        log "${GREEN}✓ Created network-upgrade user${NC}"
    else
        log "${YELLOW}User network-upgrade already exists${NC}"
    fi
    
    # Create directories
    mkdir -p "${DATA_DIR}"/{config,firmware,backups,logs,tmp}
    mkdir -p "${LOG_DIR}"
    mkdir -p "${BACKUP_DIR}"
    mkdir -p /etc/network-upgrade
    
    # Set permissions
    chown -R network-upgrade:network-upgrade "${DATA_DIR}"
    chown -R network-upgrade:network-upgrade "${LOG_DIR}"
    chown -R network-upgrade:network-upgrade "${BACKUP_DIR}"
    
    chmod 750 "${DATA_DIR}"
    chmod 755 "${LOG_DIR}"
    chmod 750 "${BACKUP_DIR}"
    
    log "${GREEN}✓ System directories created${NC}"
}

# Install Python requirements
install_python_requirements() {
    log "${BLUE}Installing Python requirements...${NC}"
    
    # Upgrade pip
    python3 -m pip install --upgrade pip setuptools wheel
    
    # Install core Python packages
    python3 -m pip install \
        ansible-core>=2.14.0 \
        ansible-runner>=2.3.0 \
        requests>=2.28.0 \
        pyyaml>=6.0 \
        jinja2>=3.1.0 \
        cryptography>=40.0.0 \
        netaddr>=0.8.0 \
        paramiko>=3.1.0 \
        redis>=4.5.0 \
        psutil>=5.9.0
    
    log "${GREEN}✓ Python requirements installed${NC}"
}

# Configure Redis
configure_redis() {
    log "${BLUE}Configuring Redis...${NC}"
    
    # Redis configuration optimized for single server
    cat > /etc/redis/redis.conf << 'EOF'
# Network Upgrade System Redis Configuration
# Optimized for single server deployment

bind 127.0.0.1
port 6379
timeout 0
keepalive 300

# Memory management
maxmemory 1gb
maxmemory-policy allkeys-lru
maxmemory-samples 5

# Persistence (minimal for job queue usage)
save 900 1
save 300 10
save 60 10000

dbfilename network-upgrade-redis.rdb
dir /var/lib/redis

# Logging
loglevel notice
logfile /var/log/redis/redis-server.log

# Security
requirepass ChangeMeInProduction123!

# Performance tuning
tcp-keepalive 300
tcp-backlog 511
databases 16
EOF
    
    # Set Redis password in environment
    echo "REDIS_PASSWORD=ChangeMeInProduction123!" >> /etc/environment
    
    # Start and enable Redis
    systemctl start redis
    systemctl enable redis
    
    # Test Redis connection
    if redis-cli -a "ChangeMeInProduction123!" ping | grep -q "PONG"; then
        log "${GREEN}✓ Redis configured and running${NC}"
    else
        error_exit "Redis configuration failed"
    fi
}

# Configure Nginx
configure_nginx() {
    log "${BLUE}Configuring Nginx...${NC}"
    
    # Backup original config
    cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
    
    # Main Nginx configuration
    cat > /etc/nginx/nginx.conf << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 100M;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    # Include server configurations
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF
    
    # Create sites directories
    mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled
    
    # Default site configuration (will be updated by AWX/NetBox installers)
    cat > /etc/nginx/sites-available/default << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    
    location / {
        return 301 https://$server_name$request_uri;
    }
    
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
}

server {
    listen 443 ssl http2 default_server;
    listen [::]:443 ssl http2 default_server;
    server_name _;
    
    ssl_certificate /etc/ssl/certs/network-upgrade.crt;
    ssl_certificate_key /etc/ssl/private/network-upgrade.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_timeout 10m;
    ssl_session_cache shared:SSL:10m;
    
    root /var/www/html;
    index index.html index.htm;
    
    location / {
        try_files $uri $uri/ =404;
    }
}
EOF
    
    ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
    
    # Create web root
    mkdir -p /var/www/html
    chown -R nginx:nginx /var/www/html
    
    # Test Nginx configuration
    if nginx -t; then
        log "${GREEN}✓ Nginx configuration valid${NC}"
    else
        error_exit "Nginx configuration failed"
    fi
}

# Configure firewall
configure_firewall() {
    log "${BLUE}Configuring firewall...${NC}"
    
    case $OS in
        rhel)
            # Configure firewalld
            systemctl start firewalld
            systemctl enable firewalld
            
            # Open required ports
            firewall-cmd --permanent --add-service=http
            firewall-cmd --permanent --add-service=https
            firewall-cmd --permanent --add-service=ssh
            
            # Custom ports for services (will be configured by individual installers)
            firewall-cmd --permanent --add-port=8080/tcp  # AWX
            firewall-cmd --permanent --add-port=8000/tcp  # NetBox
            
            firewall-cmd --reload
            ;;
        debian)
            # Configure ufw
            ufw --force enable
            ufw default deny incoming
            ufw default allow outgoing
            
            # Open required ports
            ufw allow ssh
            ufw allow http
            ufw allow https
            ufw allow 8080/tcp  # AWX
            ufw allow 8000/tcp  # NetBox
            ;;
    esac
    
    log "${GREEN}✓ Firewall configured${NC}"
}

# Create systemd service templates
create_service_templates() {
    log "${BLUE}Creating systemd service templates...${NC}"
    
    # Network upgrade main service template
    cat > /etc/systemd/system/network-upgrade.service << 'EOF'
[Unit]
Description=Network Device Upgrade Management System
After=network.target redis.service
Requires=redis.service

[Service]
Type=notify
User=network-upgrade
Group=network-upgrade
WorkingDirectory=/opt/network-upgrade
Environment=PYTHONPATH=/opt/network-upgrade
Environment=REDIS_URL=redis://:ChangeMeInProduction123!@localhost:6379/0
ExecStart=/usr/bin/python3 -m network_upgrade.main
ExecReload=/bin/kill -HUP $MAINPID
Restart=always
RestartSec=10

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/network-upgrade /var/log/network-upgrade /var/backups/network-upgrade

[Install]
WantedBy=multi-user.target
EOF
    
    # Log rotation configuration
    cat > /etc/logrotate.d/network-upgrade << 'EOF'
/var/log/network-upgrade/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 0644 network-upgrade network-upgrade
    postrotate
        systemctl reload network-upgrade 2>/dev/null || true
    endscript
}
EOF
    
    log "${GREEN}✓ Service templates created${NC}"
}

# Create configuration files
create_configuration() {
    log "${BLUE}Creating configuration files...${NC}"
    
    # Main configuration file
    cat > /etc/network-upgrade/config.yml << 'EOF'
# Network Device Upgrade Management System Configuration
# Single Server Deployment with SQLite Backend

system:
  data_dir: "/opt/network-upgrade"
  log_dir: "/var/log/network-upgrade"
  backup_dir: "/var/backups/network-upgrade"
  tmp_dir: "/opt/network-upgrade/tmp"
  
database:
  type: "sqlite"
  path: "/opt/network-upgrade/config/network_upgrade.db"
  backup_interval: 3600  # Backup every hour
  
redis:
  host: "127.0.0.1"
  port: 6379
  password: "ChangeMeInProduction123!"
  db: 0
  
security:
  ssl_cert: "/etc/ssl/certs/network-upgrade.crt"
  ssl_key: "/etc/ssl/private/network-upgrade.key"
  vault_password_file: "/etc/network-upgrade/vault_pass"
  
logging:
  level: "INFO"
  max_file_size: "100MB"
  backup_count: 10
  format: "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
  
performance:
  max_concurrent_jobs: 50
  max_device_connections: 100
  connection_timeout: 30
  command_timeout: 300
  
monitoring:
  enabled: true
  metrics_interval: 60
  health_check_interval: 300
  
# Default values - will be overridden by AWX/NetBox configurations
awx:
  url: "https://localhost:8080"
  username: "admin"
  password: ""  # Set during installation
  
netbox:
  url: "https://localhost:8000"
  token: ""  # Set during installation
  
influxdb:
  url: ""  # Configure to point to existing InfluxDB v2
  token: ""
  org: ""
  bucket: "network_upgrades"
EOF
    
    # Set secure permissions
    chmod 600 /etc/network-upgrade/config.yml
    chown network-upgrade:network-upgrade /etc/network-upgrade/config.yml
    
    log "${GREEN}✓ Configuration files created${NC}"
}

# Create utility scripts
create_utility_scripts() {
    log "${BLUE}Creating utility scripts...${NC}"
    
    # System health check script
    cat > /usr/local/bin/network-upgrade-health << 'EOF'
#!/bin/bash
# Network Upgrade System Health Check

echo "=== Network Device Upgrade Management System Health Check ==="
echo "Date: $(date)"
echo ""

# Service status
echo "=== Service Status ==="
services=(redis nginx network-upgrade)
for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service"; then
        echo "✓ $service: RUNNING"
    else
        echo "✗ $service: STOPPED"
    fi
done
echo ""

# System resources
echo "=== System Resources ==="
echo "CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')%"
echo "Memory Usage: $(free | grep Mem | awk '{printf("%.2f%%", $3/$2 * 100.0)}')"
echo "Disk Usage: $(df / | awk 'NR==2{printf("%.2f%%", $3/$2*100)}')"
echo ""

# Database connectivity
echo "=== Database Status ==="
if [[ -f "/opt/network-upgrade/config/network_upgrade.db" ]]; then
    echo "✓ SQLite database exists"
    db_size=$(ls -lh /opt/network-upgrade/config/network_upgrade.db | awk '{print $5}')
    echo "Database size: $db_size"
else
    echo "✗ SQLite database not found"
fi
echo ""

# Redis connectivity
echo "=== Redis Status ==="
if redis-cli -a "ChangeMeInProduction123!" ping &>/dev/null; then
    echo "✓ Redis connection successful"
else
    echo "✗ Redis connection failed"
fi
echo ""

# Log file status
echo "=== Log File Status ==="
if [[ -d "/var/log/network-upgrade" ]]; then
    log_count=$(find /var/log/network-upgrade -name "*.log" | wc -l)
    echo "Log files found: $log_count"
    if [[ $log_count -gt 0 ]]; then
        echo "Latest log entries:"
        find /var/log/network-upgrade -name "*.log" -exec tail -n 3 {} \; 2>/dev/null | head -10
    fi
else
    echo "✗ Log directory not found"
fi
EOF
    
    chmod +x /usr/local/bin/network-upgrade-health
    
    # System backup script
    cat > /usr/local/bin/network-upgrade-backup << 'EOF'
#!/bin/bash
# Network Upgrade System Backup Script

BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="/var/backups/network-upgrade/system_backup_${BACKUP_DATE}"

echo "Creating system backup: $BACKUP_PATH"

mkdir -p "$BACKUP_PATH"

# Backup configuration
cp -r /etc/network-upgrade "$BACKUP_PATH/"

# Backup database
if [[ -f "/opt/network-upgrade/config/network_upgrade.db" ]]; then
    cp /opt/network-upgrade/config/network_upgrade.db "$BACKUP_PATH/"
fi

# Backup important logs
cp -r /var/log/network-upgrade "$BACKUP_PATH/" 2>/dev/null || true

# Create archive
tar -czf "${BACKUP_PATH}.tar.gz" -C "/var/backups/network-upgrade" "system_backup_${BACKUP_DATE}"
rm -rf "$BACKUP_PATH"

echo "Backup completed: ${BACKUP_PATH}.tar.gz"

# Cleanup old backups (keep 30 days)
find /var/backups/network-upgrade -name "system_backup_*.tar.gz" -mtime +30 -delete
EOF
    
    chmod +x /usr/local/bin/network-upgrade-backup
    
    log "${GREEN}✓ Utility scripts created${NC}"
}

# Create cron jobs
setup_cron_jobs() {
    log "${BLUE}Setting up cron jobs...${NC}"
    
    # Create crontab for network-upgrade user
    cat > /tmp/network-upgrade-cron << 'EOF'
# Network Device Upgrade Management System Cron Jobs

# Daily system backup at 2 AM
0 2 * * * /usr/local/bin/network-upgrade-backup

# Health check every 15 minutes
*/15 * * * * /usr/local/bin/network-upgrade-health > /var/log/network-upgrade/health.log 2>&1

# Log rotation check hourly
0 * * * * /usr/sbin/logrotate /etc/logrotate.d/network-upgrade 2>&1 | logger -t logrotate
EOF
    
    # Install crontab
    crontab -u network-upgrade /tmp/network-upgrade-cron
    rm /tmp/network-upgrade-cron
    
    log "${GREEN}✓ Cron jobs configured${NC}"
}

# Main installation function
main() {
    log "${GREEN}Starting Network Device Upgrade Management System base installation...${NC}"
    log "${BLUE}Installation started at: $(date)${NC}"
    
    detect_os
    check_system_resources
    install_system_packages
    setup_system_user
    install_python_requirements
    configure_redis
    configure_nginx
    configure_firewall
    create_service_templates
    create_configuration
    create_utility_scripts
    setup_cron_jobs
    
    log "${GREEN}✓ Base system installation completed successfully!${NC}"
    log "${BLUE}Installation finished at: $(date)${NC}"
    
    echo ""
    log "${YELLOW}Next steps:${NC}"
    log "1. Run ./install/install-awx.sh to install AWX"
    log "2. Run ./install/install-netbox.sh to install NetBox"
    log "3. Run ./install/configure-telegraf.sh to configure monitoring"
    log "4. Run ./install/setup-ssl.sh to configure SSL certificates"
    log "5. Run ./install/create-services.sh to start all services"
    log ""
    log "System health check: /usr/local/bin/network-upgrade-health"
    log "System backup: /usr/local/bin/network-upgrade-backup"
    log "Configuration file: /etc/network-upgrade/config.yml"
    log "Log directory: /var/log/network-upgrade/"
}

# Run main function
main "$@"