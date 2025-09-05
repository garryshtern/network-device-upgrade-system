W#!/bin/bash

# NetBox Installation Script for Single Server Deployment  
# SQLite backend, optimized for single server use

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_FILE="/var/log/network-upgrade/netbox-install.log"
NETBOX_VERSION="3.6.6"
NETBOX_DATA_DIR="/opt/network-upgrade/netbox"
NETBOX_USER="network-upgrade"
NETBOX_ROOT="${NETBOX_DATA_DIR}/netbox"

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
    error_exit "Base system not installed. Run ./install/setup-system.sh first"
fi

# Install NetBox dependencies
install_netbox_dependencies() {
    log "${BLUE}Installing NetBox dependencies...${NC}"
    
    # Install Python packages for NetBox
    python3 -m pip install \
        django>=4.1,<4.2 \
        djangorestframework>=3.14.0 \
        django-cors-headers>=4.0.0 \
        django-debug-toolbar>=4.2.0 \
        django-filter>=23.0 \
        django-graphiql-debug-toolbar>=0.2.0 \
        django-mptt>=0.15.0 \
        django-prometheus>=2.3.1 \
        django-redis>=5.3.0 \
        django-rq>=2.8.1 \
        django-tables2>=2.5.3 \
        django-taggit>=4.0.0 \
        django-timezone-field>=5.1 \
        drf-spectacular>=0.26.0 \
        graphene-django>=3.0.0 \
        gunicorn>=21.2.0 \
        jinja2>=3.1.0 \
        markdown>=3.5.0 \
        netaddr>=0.9.0 \
        pillow>=10.0.0 \
        psycopg2-binary>=2.9.0 \
        pyyaml>=6.0.0 \
        svglib>=1.5.1 \
        tablib>=3.5.0 \
        mkdocs-material>=9.4.0
    
    log "${GREEN}✓ NetBox dependencies installed${NC}"
}

# Create NetBox directories
setup_netbox_directories() {
    log "${BLUE}Setting up NetBox directories...${NC}"
    
    # Create NetBox directory structure
    mkdir -p "${NETBOX_DATA_DIR}"/{config,media,reports,scripts,static,database}
    mkdir -p /var/log/netbox
    
    # Set ownership
    chown -R "${NETBOX_USER}:${NETBOX_USER}" "${NETBOX_DATA_DIR}"
    chown -R "${NETBOX_USER}:${NETBOX_USER}" /var/log/netbox
    
    # Set permissions
    chmod 755 "${NETBOX_DATA_DIR}"
    chmod 750 "${NETBOX_DATA_DIR}/config"
    chmod 755 "${NETBOX_DATA_DIR}/media"
    
    log "${GREEN}✓ NetBox directories created${NC}"
}

# Download and install NetBox
install_netbox() {
    log "${BLUE}Installing NetBox ${NETBOX_VERSION}...${NC}"
    
    cd "${NETBOX_DATA_DIR}"
    
    # Download NetBox source
    if [[ ! -d "netbox-${NETBOX_VERSION}" ]]; then
        curl -L "https://github.com/netbox-community/netbox/archive/v${NETBOX_VERSION}.tar.gz" -o "netbox-${NETBOX_VERSION}.tar.gz"
        tar -xzf "netbox-${NETBOX_VERSION}.tar.gz"
        mv "netbox-${NETBOX_VERSION}" netbox
        rm "netbox-${NETBOX_VERSION}.tar.gz"
    fi
    
    # Install NetBox requirements
    cd "${NETBOX_ROOT}"
    python3 -m pip install -r requirements.txt
    
    chown -R "${NETBOX_USER}:${NETBOX_USER}" "${NETBOX_ROOT}"
    
    log "${GREEN}✓ NetBox ${NETBOX_VERSION} installed${NC}"
}

# Configure NetBox
configure_netbox() {
    log "${BLUE}Configuring NetBox...${NC}"
    
    # Generate secret key
    SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))")
    
    # Create NetBox configuration
    cat > "${NETBOX_DATA_DIR}/config/configuration.py" << EOF
# NetBox Configuration for Single Server Deployment
# SQLite backend with Redis for caching and task queue

import os
from pathlib import Path

# Build paths
BASE_DIR = Path(__file__).resolve().parent.parent

#########################
#                       #
#   Required settings   #
#                       #
#########################

# Database - SQLite for single server deployment
DATABASE = {
    'ENGINE': 'django.db.backends.sqlite3',
    'NAME': '${NETBOX_DATA_DIR}/database/netbox.db',
    'OPTIONS': {
        'timeout': 20,
        'init_command': 'PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL;',
    }
}

# Redis configuration
REDIS = {
    'tasks': {
        'HOST': '127.0.0.1',
        'PORT': 6379,
        'PASSWORD': 'ChangeMeInProduction123!',
        'DATABASE': 3,
        'SSL': False,
    },
    'caching': {
        'HOST': '127.0.0.1', 
        'PORT': 6379,
        'PASSWORD': 'ChangeMeInProduction123!',
        'DATABASE': 4,
        'SSL': False,
    }
}

# Secret key
SECRET_KEY = '${SECRET_KEY}'

#########################
#                       #
#   Optional settings   #
#                       #
#########################

# Specify one or more name and email address tuples representing NetBox administrators
ADMINS = [
    ('Network Admin', 'netops@company.com'),
]

# Permitted hostnames
ALLOWED_HOSTS = ['*']

# Base URL path
BASE_PATH = ''

# Cache timeout
CACHE_TIMEOUT = 900

# API Cross-Origin Resource Sharing (CORS) settings
CORS_ALLOW_ALL_ORIGINS = True

# Set to True to enable server debugging
DEBUG = False

# Email settings
EMAIL = {
    'SERVER': 'localhost',
    'PORT': 587,
    'USERNAME': '',
    'PASSWORD': '',
    'USE_SSL': False,
    'USE_TLS': False,
    'TIMEOUT': 10,
    'FROM_EMAIL': 'netbox@localhost',
}

# Enforcement of unique IP space can be toggled
ENFORCE_GLOBAL_UNIQUE = False

# HTTP proxies NetBox should use when sending outbound HTTP requests
HTTP_PROXIES = None

# Enable custom logging
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '{levelname} {asctime} {module} {process:d} {thread:d} {message}',
            'style': '{',
        },
    },
    'handlers': {
        'file': {
            'level': 'INFO',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': '/var/log/netbox/netbox.log',
            'maxBytes': 10485760,  # 10MB
            'backupCount': 10,
            'formatter': 'verbose',
        },
        'console': {
            'level': 'INFO',
            'class': 'logging.StreamHandler',
            'formatter': 'verbose',
        },
    },
    'loggers': {
        'django': {
            'handlers': ['file', 'console'],
            'level': 'INFO',
            'propagate': True,
        },
        'netbox': {
            'handlers': ['file', 'console'], 
            'level': 'INFO',
            'propagate': True,
        },
    },
}

# Setting this to True will permit the evaluation of any expression
ALLOW_TOKEN_RETRIEVAL = False

# Credentials that NetBox will use to authenticate to devices
NETBOX_USERNAME = ''
NETBOX_PASSWORD = ''

# Text to include on the login page
LOGIN_BANNER = 'Network Device Upgrade Management System'

# Maximum number of objects that can be processed in bulk
MAX_PAGE_SIZE = 1000

# Enable installed plugins
PLUGINS = []

# Plugin configuration settings
PLUGINS_CONFIG = {}

# Remote authentication support
REMOTE_AUTH_ENABLED = False

# Time zone
TIME_ZONE = 'UTC'

# Date/time formatting
DATE_FORMAT = 'N j, Y'
SHORT_DATE_FORMAT = 'Y-m-d'
TIME_FORMAT = 'g:i a'
SHORT_TIME_FORMAT = 'H:i:s'
DATETIME_FORMAT = 'N j, Y g:i a'
SHORT_DATETIME_FORMAT = 'Y-m-d H:i'

# Prefer IPv4 addresses over IPv6
PREFER_IPV4 = False

# Default pagination count
PAGINATE_COUNT = 50

# Rack elevation default unit height
RACK_ELEVATION_DEFAULT_UNIT_HEIGHT = 22

# Rack elevation default unit width  
RACK_ELEVATION_DEFAULT_UNIT_WIDTH = 220

# Security settings
CSRF_COOKIE_NAME = 'csrftoken'
SESSION_COOKIE_NAME = 'sessionid'

# Enable GraphQL API
GRAPHQL_ENABLED = True

# Media settings
MEDIA_ROOT = '${NETBOX_DATA_DIR}/media'

# Reports & scripts
REPORTS_ROOT = '${NETBOX_DATA_DIR}/reports'
SCRIPTS_ROOT = '${NETBOX_DATA_DIR}/scripts'

# Static files
STATIC_ROOT = '${NETBOX_DATA_DIR}/static'

# Storage backend (for uploaded files)
DEFAULT_FILE_STORAGE = 'django.core.files.storage.FileSystemStorage'

# Maximum execution time for background tasks (RQ)
RQ_DEFAULT_TIMEOUT = 300

# Enable maintenance mode bypass
MAINTENANCE_MODE = False

# Custom field choices
FIELD_CHOICES = {}

# NetBox extensions
INSTALLED_APPS = []

# Custom validators for model fields  
CUSTOM_VALIDATORS = {}

# Custom links for objects
CUSTOM_LINKS = {}

# Customization configuration
BANNER_TOP = ''
BANNER_BOTTOM = ''
BANNER_LOGIN = 'Network Device Upgrade Management System - Device Inventory'

# Release check settings
RELEASE_CHECK_URL = None

# Login required for all views
LOGIN_REQUIRED = True

# Changelog retention (days)
CHANGELOG_RETENTION = 90

# Job result retention (days)  
JOBRESULT_RETENTION = 90

# Maps configuration
MAPS_URL = 'https://maps.google.com/maps?q='

# Napalm configuration
NAPALM_USERNAME = ''
NAPALM_PASSWORD = ''
NAPALM_TIMEOUT = 30
NAPALM_ARGS = {}
EOF

    # Set permissions
    chmod 600 "${NETBOX_DATA_DIR}/config/configuration.py"
    chown "${NETBOX_USER}:${NETBOX_USER}" "${NETBOX_DATA_DIR}/config/configuration.py"
    
    # Create symbolic link
    ln -sf "${NETBOX_DATA_DIR}/config/configuration.py" "${NETBOX_ROOT}/netbox/configuration.py"
    
    log "${GREEN}✓ NetBox configuration created${NC}"
}

# Initialize NetBox database
initialize_netbox_database() {
    log "${BLUE}Initializing NetBox database...${NC}"
    
    cd "${NETBOX_ROOT}"
    
    # Run database migrations and create superuser
    su -s /bin/bash "${NETBOX_USER}" -c "
        cd ${NETBOX_ROOT}
        python3 manage.py migrate
        python3 manage.py collectstatic --noinput
        python3 manage.py remove_stale_contenttypes --noinput
        python3 manage.py reindex --lazy
    "
    
    log "${GREEN}✓ NetBox database initialized${NC}"
}

# Create NetBox admin user
create_netbox_admin_user() {
    log "${BLUE}Creating NetBox admin user...${NC}"
    
    # Generate admin password
    ADMIN_PASSWORD=$(openssl rand -base64 32)
    
    # Create superuser
    su -s /bin/bash "${NETBOX_USER}" -c "
        cd ${NETBOX_ROOT}
        python3 manage.py shell << EOF
from django.contrib.auth import get_user_model
from users.models import Token

User = get_user_model()
if not User.objects.filter(username='admin').exists():
    user = User.objects.create_superuser('admin', 'admin@localhost', '${ADMIN_PASSWORD}')
    token = Token.objects.create(user=user, key='netbox_api_token_$(openssl rand -hex 20)')
    print(f'Admin user created - Token: {token.key}')
EOF
    "
    
    # Save admin credentials
    cat > "${NETBOX_DATA_DIR}/config/admin_credentials.txt" << EOF
NetBox Admin Credentials:
Username: admin
Password: ${ADMIN_PASSWORD}
URL: https://localhost:8000

API Token: netbox_api_token_$(openssl rand -hex 20)

IMPORTANT: Change this password immediately after first login!
EOF
    
    chmod 600 "${NETBOX_DATA_DIR}/config/admin_credentials.txt"
    chown "${NETBOX_USER}:${NETBOX_USER}" "${NETBOX_DATA_DIR}/config/admin_credentials.txt"
    
    log "${GREEN}✓ NetBox admin user created${NC}"
    log "${YELLOW}Admin credentials saved to: ${NETBOX_DATA_DIR}/config/admin_credentials.txt${NC}"
}

# Create NetBox systemd services
create_netbox_services() {
    log "${BLUE}Creating NetBox systemd services...${NC}"
    
    # NetBox Web Service (Gunicorn)
    cat > /etc/systemd/system/netbox.service << EOF
[Unit]
Description=NetBox WSGI Service
Documentation=https://netbox.readthedocs.io/
After=network.target redis.service
Requires=redis.service

[Service]
Type=notify
User=${NETBOX_USER}
Group=${NETBOX_USER}
PIDFile=/var/tmp/netbox.pid
WorkingDirectory=${NETBOX_ROOT}
Environment=DJANGO_SETTINGS_MODULE=netbox.settings
ExecStart=/usr/local/bin/gunicorn netbox.wsgi --bind 127.0.0.1:8000 --workers 3 --timeout 120 --max-requests 1000 --pid /var/tmp/netbox.pid
ExecReload=/bin/kill -HUP \$MAINPID
ExecStop=/bin/kill -TERM \$MAINPID
Restart=always
RestartSec=10

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${NETBOX_DATA_DIR} /var/log/netbox /var/tmp

[Install]
WantedBy=multi-user.target
EOF

    # NetBox RQ Worker Service
    cat > /etc/systemd/system/netbox-rq.service << EOF
[Unit]
Description=NetBox Request Queue Worker
Documentation=https://netbox.readthedocs.io/
After=network.target redis.service netbox.service
Requires=redis.service

[Service]
Type=simple
User=${NETBOX_USER}
Group=${NETBOX_USER}
WorkingDirectory=${NETBOX_ROOT}
Environment=DJANGO_SETTINGS_MODULE=netbox.settings
ExecStart=/usr/bin/python3 manage.py rqworker high default low
Restart=always
RestartSec=10

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${NETBOX_DATA_DIR} /var/log/netbox /var/tmp

[Install]
WantedBy=multi-user.target
EOF

    # NetBox Housekeeping Service
    cat > /etc/systemd/system/netbox-housekeeping.service << EOF
[Unit]
Description=NetBox Housekeeping
Documentation=https://netbox.readthedocs.io/

[Service]
Type=oneshot
User=${NETBOX_USER}
Group=${NETBOX_USER}
WorkingDirectory=${NETBOX_ROOT}
Environment=DJANGO_SETTINGS_MODULE=netbox.settings
ExecStart=/usr/bin/python3 manage.py housekeeping

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${NETBOX_DATA_DIR} /var/log/netbox /var/tmp
EOF

    # Housekeeping timer
    cat > /etc/systemd/system/netbox-housekeeping.timer << EOF
[Unit]
Description=NetBox Housekeeping Timer
Documentation=https://netbox.readthedocs.io/

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF
    
    # Reload systemd
    systemctl daemon-reload
    
    log "${GREEN}✓ NetBox systemd services created${NC}"
}

# Configure Nginx for NetBox
configure_nginx_netbox() {
    log "${BLUE}Configuring Nginx for NetBox...${NC}"
    
    cat > /etc/nginx/sites-available/netbox << 'EOF'
upstream netbox {
    server 127.0.0.1:8000;
}

server {
    listen 80;
    server_name _;
    return 301 https://$server_name:8000$request_uri;
}

server {
    listen 8000 ssl http2 default_server;
    server_name _;
    
    ssl_certificate /etc/ssl/certs/network-upgrade.crt;
    ssl_certificate_key /etc/ssl/private/network-upgrade.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_timeout 10m;
    ssl_session_cache shared:SSL:10m;
    
    client_max_body_size 25M;
    
    location /static/ {
        alias /opt/network-upgrade/netbox/static/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
    
    location /media/ {
        alias /opt/network-upgrade/netbox/media/;
        expires 7d;
        add_header Cache-Control "public";
    }
    
    location / {
        proxy_pass http://netbox;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_redirect off;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF
    
    # Enable site
    ln -sf /etc/nginx/sites-available/netbox /etc/nginx/sites-enabled/netbox
    
    # Test nginx configuration
    if nginx -t; then
        systemctl reload nginx
        log "${GREEN}✓ Nginx configured for NetBox${NC}"
    else
        error_exit "Nginx configuration failed"
    fi
}

# Test NetBox installation
test_netbox_installation() {
    log "${BLUE}Testing NetBox installation...${NC}"
    
    # Start services
    systemctl start netbox netbox-rq
    systemctl enable netbox netbox-rq netbox-housekeeping.timer
    sleep 10
    
    # Check services are running
    services=(netbox netbox-rq)
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            log "${GREEN}✓ $service is running${NC}"
        else
            log "${RED}✗ $service failed to start${NC}"
            systemctl status "$service" --no-pager
        fi
    done
    
    # Test web interface
    if curl -k -s https://localhost:8000/ | grep -q "NetBox"; then
        log "${GREEN}✓ NetBox web interface is responding${NC}"
    else
        log "${YELLOW}⚠ NetBox web interface test inconclusive${NC}"
    fi
}

# Main installation function
main() {
    log "${GREEN}Starting NetBox installation...${NC}"
    log "${BLUE}Installation started at: $(date)${NC}"
    
    install_netbox_dependencies
    setup_netbox_directories
    install_netbox
    configure_netbox
    initialize_netbox_database
    create_netbox_admin_user
    create_netbox_services
    configure_nginx_netbox
    test_netbox_installation
    
    log "${GREEN}✓ NetBox installation completed successfully!${NC}"
    log "${BLUE}Installation finished at: $(date)${NC}"
    
    echo ""
    log "${YELLOW}NetBox Installation Summary:${NC}"
    log "• NetBox Web UI: https://localhost:8000/"
    log "• Admin credentials: ${NETBOX_DATA_DIR}/config/admin_credentials.txt"
    log "• Configuration: ${NETBOX_DATA_DIR}/config/configuration.py"
    log "• Media files: ${NETBOX_DATA_DIR}/media/"
    log "• Log files: /var/log/netbox/"
    log ""
    log "${YELLOW}Services:${NC}"
    log "• netbox.service (Web UI)"
    log "• netbox-rq.service (Background tasks)"
    log "• netbox-housekeeping.timer (Daily cleanup)"
    log ""
    log "${YELLOW}Next steps:${NC}"
    log "1. Change the admin password on first login"
    log "2. Configure device types, sites, and initial inventory"
    log "3. Generate API token for AWX integration"
    log "4. Run ./install/configure-telegraf.sh to set up monitoring"
    
    # Update system configuration with NetBox token
    NETBOX_TOKEN=$(grep "API Token:" "${NETBOX_DATA_DIR}/config/admin_credentials.txt" | cut -d' ' -f3)
    sed -i "s|netbox:.*token:.*\"\"|netbox:\n  url: \"https://localhost:8000\"\n  token: \"${NETBOX_TOKEN}\"|" /etc/network-upgrade/config.yml
}

# Run main function
main "$@"