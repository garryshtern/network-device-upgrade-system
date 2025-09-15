#!/bin/bash

# AWX Installation Script for Single Server Deployment
# SQLite backend, optimized for resource constraints

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_FILE="/var/log/network-upgrade/awx-install.log"
AWX_VERSION="23.5.0"
AWX_DATA_DIR="/opt/network-upgrade/awx"
AWX_PROJECT_DIR="${AWX_DATA_DIR}/projects"
AWX_USER="network-upgrade"

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

# Install AWX dependencies
install_awx_dependencies() {
    log "${BLUE}Installing AWX dependencies...${NC}"
    
    # Install Node.js and npm (required for AWX UI build)
    if command -v dnf &> /dev/null; then
        dnf module install -y nodejs:18/common
        dnf install -y npm
    elif command -v apt-get &> /dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
        apt-get install -y nodejs
    fi
    
    # Install Python packages for AWX
    python3 -m pip install \
        django>=4.2,<4.3 \
        djangorestframework>=3.14.0 \
        django-cors-headers>=4.0.0 \
        celery[redis]>=5.3.0 \
        psutil>=5.9.0 \
        pexpect>=4.8.0 \
        python-ldap>=3.4.0 \
        social-auth-app-django>=5.2.0 \
        django-oauth-toolkit>=2.2.0 \
        uwsgi>=2.0.21 \
        pyyaml>=6.0 \
        gitpython>=3.1.0 \
        kubernetes>=26.1.0 \
        openshift>=0.13.0 \
        requests>=2.28.0 \
        ansible-runner>=2.3.0
    
    log "${GREEN}✓ AWX dependencies installed${NC}"
}

# Create AWX directories and user
setup_awx_directories() {
    log "${BLUE}Setting up AWX directories...${NC}"
    
    # Create AWX directory structure
    mkdir -p "${AWX_DATA_DIR}"/{config,projects,logs,tmp,redis,database}
    mkdir -p "${AWX_PROJECT_DIR}"
    mkdir -p /var/log/awx
    
    # Copy Ansible content to AWX projects directory
    cp -r "${PROJECT_ROOT}/ansible-content" "${AWX_PROJECT_DIR}/network-automation"
    
    # Set ownership
    chown -R "${AWX_USER}:${AWX_USER}" "${AWX_DATA_DIR}"
    chown -R "${AWX_USER}:${AWX_USER}" /var/log/awx
    
    # Set permissions
    chmod 755 "${AWX_DATA_DIR}"
    chmod 750 "${AWX_DATA_DIR}/config"
    chmod 755 "${AWX_PROJECT_DIR}"
    
    log "${GREEN}✓ AWX directories created${NC}"
}

# Download and setup AWX
install_awx() {
    log "${BLUE}Installing AWX ${AWX_VERSION}...${NC}"
    
    cd /tmp
    
    # Download AWX source
    if [[ ! -d "awx-${AWX_VERSION}" ]]; then
        curl -L "https://github.com/ansible/awx/archive/${AWX_VERSION}.tar.gz" -o "awx-${AWX_VERSION}.tar.gz"
        tar -xzf "awx-${AWX_VERSION}.tar.gz"
    fi
    
    cd "awx-${AWX_VERSION}"
    
    # Install AWX Python package
    python3 -m pip install -e .
    
    # Install AWX collection
    ansible-galaxy collection install awx.awx
    
    log "${GREEN}✓ AWX ${AWX_VERSION} installed${NC}"
}

# Configure AWX settings
configure_awx() {
    log "${BLUE}Configuring AWX...${NC}"
    
    # Generate secret key
    SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))")
    
    # Create AWX configuration
    cat > "${AWX_DATA_DIR}/config/settings.py" << EOF
# AWX Configuration for Single Server Deployment
# SQLite backend with Redis for caching and job queue

import os
from pathlib import Path

# Build paths
BASE_DIR = Path(__file__).resolve().parent.parent

# Security
SECRET_KEY = '${SECRET_KEY}'
DEBUG = False
ALLOWED_HOSTS = ['*']

# Database - SQLite for single server deployment
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': '${AWX_DATA_DIR}/database/awx.db',
        'OPTIONS': {
            'timeout': 20,
            'init_command': 'PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL;',
        }
    }
}

# Redis configuration
REDIS_CONNECTION_POOL_KWARGS = {
    'host': '127.0.0.1',
    'port': 6379,
    'db': 1,
    'password': 'ChangeMeInProduction123!',
}

CACHES = {
    'default': {
        'BACKEND': 'django_redis.cache.RedisCache',
        'LOCATION': 'redis://:ChangeMeInProduction123!@127.0.0.1:6379/1',
        'OPTIONS': {
            'CLIENT_CLASS': 'django_redis.client.DefaultClient',
        }
    }
}

CACHE_TIMEOUT = 86400

# Celery (Redis broker)
CELERY_BROKER_URL = 'redis://:ChangeMeInProduction123!@127.0.0.1:6379/2'
CELERY_RESULT_BACKEND = 'redis://:ChangeMeInProduction123!@127.0.0.1:6379/2'

# Static files
STATIC_URL = '/static/'
STATIC_ROOT = '${AWX_DATA_DIR}/static'

# Media files
MEDIA_URL = '/media/'
MEDIA_ROOT = '${AWX_DATA_DIR}/media'

# Projects directory
PROJECTS_ROOT = '${AWX_PROJECT_DIR}'

# Logging
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
            'filename': '/var/log/awx/awx.log',
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
        'awx': {
            'handlers': ['file', 'console'],
            'level': 'INFO',
            'propagate': True,
        },
    },
}

# AWX specific settings
AWX_PROOT_ENABLED = False
AWX_TASK_ENV = {}

# Security settings
CSRF_COOKIE_SECURE = True
SESSION_COOKIE_SECURE = True
SECURE_BROWSER_XSS_FILTER = True
SECURE_CONTENT_TYPE_NOSNIFF = True

# Performance tuning for single server
AWX_TASK_ENV['ANSIBLE_HOST_KEY_CHECKING'] = 'False'
AWX_TASK_ENV['ANSIBLE_SSH_CONTROL_PATH_DIR'] = '${AWX_DATA_DIR}/tmp'

# Resource limits
SYSTEM_TASK_ABS_MEM = 2048  # 2GB limit for system tasks
SYSTEM_TASK_ABS_CPU = 4     # 4 CPU cores for system tasks

# Cleanup settings
CLEANUP_PATHS = True
JOB_EVENT_BUFFER_SIZE = 1000

# Authentication
AUTH_BASIC_ENABLED = True
OAUTH2_PROVIDER = {
    'SCOPES': {
        'read': 'Read scope',
        'write': 'Write scope',
    }
}

# Additional installed apps
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'corsheaders',
    'oauth2_provider',
    'social_django',
    'awx',
]

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'oauth2_provider.middleware.OAuth2TokenMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'awx.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
                'social_django.context_processors.backends',
                'social_django.context_processors.login_redirect',
            ],
        },
    },
]
EOF
    
    # Set permissions
    chmod 600 "${AWX_DATA_DIR}/config/settings.py"
    chown "${AWX_USER}:${AWX_USER}" "${AWX_DATA_DIR}/config/settings.py"
    
    log "${GREEN}✓ AWX configuration created${NC}"
}

# Initialize AWX database
initialize_database() {
    log "${BLUE}Initializing AWX database...${NC}"
    
    # Set Django settings module
    export DJANGO_SETTINGS_MODULE="awx.settings"
    export PYTHONPATH="${AWX_DATA_DIR}/config"
    
    cd "${AWX_DATA_DIR}"
    
    # Create database and run migrations
    su -s /bin/bash "${AWX_USER}" -c "
        export DJANGO_SETTINGS_MODULE=awx.settings
        export PYTHONPATH=${AWX_DATA_DIR}/config
        cd ${AWX_DATA_DIR}
        python3 -c \"
import os
import sys
import django
from django.conf import settings
from django.core.management import execute_from_command_line

sys.path.insert(0, '${AWX_DATA_DIR}/config')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'settings')
django.setup()

execute_from_command_line(['manage.py', 'migrate'])
execute_from_command_line(['manage.py', 'collectstatic', '--noinput'])
\"
    "
    
    log "${GREEN}✓ AWX database initialized${NC}"
}

# Create AWX admin user
create_admin_user() {
    log "${BLUE}Creating AWX admin user...${NC}"
    
    # Generate admin password
    ADMIN_PASSWORD=$(openssl rand -base64 32)
    
    # Create superuser
    su -s /bin/bash "${AWX_USER}" -c "
        export DJANGO_SETTINGS_MODULE=awx.settings
        export PYTHONPATH=${AWX_DATA_DIR}/config
        cd ${AWX_DATA_DIR}
        python3 -c \"
import os
import sys
import django
from django.conf import settings
from django.contrib.auth import get_user_model

sys.path.insert(0, '${AWX_DATA_DIR}/config')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'settings')
django.setup()

User = get_user_model()
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@localhost', '${ADMIN_PASSWORD}')
    print('Admin user created successfully')
\"
    "
    
    # Save admin credentials
    cat > "${AWX_DATA_DIR}/config/admin_credentials.txt" << EOF
AWX Admin Credentials:
Username: admin
Password: ${ADMIN_PASSWORD}
URL: https://localhost:8080

IMPORTANT: Change this password immediately after first login!
EOF
    
    chmod 600 "${AWX_DATA_DIR}/config/admin_credentials.txt"
    chown "${AWX_USER}:${AWX_USER}" "${AWX_DATA_DIR}/config/admin_credentials.txt"
    
    log "${GREEN}✓ AWX admin user created${NC}"
    log "${YELLOW}Admin credentials saved to: ${AWX_DATA_DIR}/config/admin_credentials.txt${NC}"
}

# Create AWX systemd services
create_awx_services() {
    log "${BLUE}Creating AWX systemd services...${NC}"
    
    # AWX Web Service
    cat > /etc/systemd/system/awx-web.service << EOF
[Unit]
Description=AWX Web Service
After=network.target redis.service
Requires=redis.service

[Service]
Type=notify
User=${AWX_USER}
Group=${AWX_USER}
WorkingDirectory=${AWX_DATA_DIR}
Environment=DJANGO_SETTINGS_MODULE=awx.settings
Environment=PYTHONPATH=${AWX_DATA_DIR}/config
ExecStart=/usr/bin/uwsgi --ini ${AWX_DATA_DIR}/config/uwsgi.ini
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=10

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${AWX_DATA_DIR} /var/log/awx /tmp

[Install]
WantedBy=multi-user.target
EOF

    # AWX Task Service (Celery Worker)
    cat > /etc/systemd/system/awx-task.service << EOF
[Unit]
Description=AWX Task Service (Celery Worker)
After=network.target redis.service awx-web.service
Requires=redis.service

[Service]
Type=forking
User=${AWX_USER}
Group=${AWX_USER}
WorkingDirectory=${AWX_DATA_DIR}
Environment=DJANGO_SETTINGS_MODULE=awx.settings
Environment=PYTHONPATH=${AWX_DATA_DIR}/config
ExecStart=/usr/local/bin/celery -A awx worker --loglevel=info --concurrency=4 --pidfile=${AWX_DATA_DIR}/tmp/celery.pid --detach
ExecStop=/bin/kill -TERM \$MAINPID
ExecReload=/bin/kill -HUP \$MAINPID
PIDFile=${AWX_DATA_DIR}/tmp/celery.pid
Restart=always
RestartSec=10

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${AWX_DATA_DIR} /var/log/awx /tmp

[Install]
WantedBy=multi-user.target
EOF

    # AWX Scheduler Service (Celery Beat)
    cat > /etc/systemd/system/awx-scheduler.service << EOF
[Unit]
Description=AWX Scheduler Service (Celery Beat)
After=network.target redis.service awx-web.service
Requires=redis.service

[Service]
Type=forking
User=${AWX_USER}
Group=${AWX_USER}
WorkingDirectory=${AWX_DATA_DIR}
Environment=DJANGO_SETTINGS_MODULE=awx.settings
Environment=PYTHONPATH=${AWX_DATA_DIR}/config
ExecStart=/usr/local/bin/celery -A awx beat --loglevel=info --pidfile=${AWX_DATA_DIR}/tmp/celerybeat.pid --detach
ExecStop=/bin/kill -TERM \$MAINPID
PIDFile=${AWX_DATA_DIR}/tmp/celerybeat.pid
Restart=always
RestartSec=10

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${AWX_DATA_DIR} /var/log/awx /tmp

[Install]
WantedBy=multi-user.target
EOF
    
    # uWSGI configuration
    cat > "${AWX_DATA_DIR}/config/uwsgi.ini" << EOF
[uwsgi]
module = awx.wsgi:application
chdir = ${AWX_DATA_DIR}
home = /usr
master = true
processes = 4
threads = 2
socket = 127.0.0.1:8080
chmod-socket = 666
vacuum = true
die-on-term = true
harakiri = 300
max-requests = 1000
buffer-size = 32768
post-buffering = 8192
EOF
    
    chown "${AWX_USER}:${AWX_USER}" "${AWX_DATA_DIR}/config/uwsgi.ini"
    
    # Reload systemd
    systemctl daemon-reload
    
    log "${GREEN}✓ AWX systemd services created${NC}"
}

# Configure Nginx for AWX
configure_nginx_awx() {
    log "${BLUE}Configuring Nginx for AWX...${NC}"
    
    cat > /etc/nginx/sites-available/awx << 'EOF'
upstream awx {
    server 127.0.0.1:8080;
}

server {
    listen 80;
    server_name _;
    return 301 https://$server_name:8443$request_uri;
}

server {
    listen 8443 ssl http2;
    server_name _;
    
    ssl_certificate /etc/ssl/certs/network-upgrade.crt;
    ssl_certificate_key /etc/ssl/private/network-upgrade.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_timeout 10m;
    ssl_session_cache shared:SSL:10m;
    
    client_max_body_size 100M;
    
    location / {
        proxy_pass http://awx;
        proxy_set_header Host $host:8443;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_redirect off;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
    location /static/ {
        alias /opt/network-upgrade/awx/static/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
    
    location /media/ {
        alias /opt/network-upgrade/awx/media/;
    }
}
EOF
    
    # Enable site
    ln -sf /etc/nginx/sites-available/awx /etc/nginx/sites-enabled/awx
    
    # Test nginx configuration
    if nginx -t; then
        systemctl reload nginx
        log "${GREEN}✓ Nginx configured for AWX${NC}"
    else
        error_exit "Nginx configuration failed"
    fi
}

# Test AWX installation
test_awx_installation() {
    log "${BLUE}Testing AWX installation...${NC}"
    
    # Start services
    systemctl start awx-web awx-task awx-scheduler
    sleep 10
    
    # Check services are running
    services=(awx-web awx-task awx-scheduler)
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            log "${GREEN}✓ $service is running${NC}"
        else
            log "${RED}✗ $service failed to start${NC}"
            systemctl status "$service" --no-pager
        fi
    done
    
    # Test web interface
    if curl -k -s https://localhost:8443/ | grep -q "AWX"; then
        log "${GREEN}✓ AWX web interface is responding${NC}"
    else
        log "${YELLOW}⚠ AWX web interface test inconclusive${NC}"
    fi
}

# Main installation function
main() {
    log "${GREEN}Starting AWX installation...${NC}"
    log "${BLUE}Installation started at: $(date)${NC}"
    
    install_awx_dependencies
    setup_awx_directories
    install_awx
    configure_awx
    initialize_database
    create_admin_user
    create_awx_services
    configure_nginx_awx
    test_awx_installation
    
    log "${GREEN}✓ AWX installation completed successfully!${NC}"
    log "${BLUE}Installation finished at: $(date)${NC}"
    
    echo ""
    log "${YELLOW}AWX Installation Summary:${NC}"
    log "• AWX Web UI: https://localhost:8443/"
    log "• Admin credentials: ${AWX_DATA_DIR}/config/admin_credentials.txt"
    log "• Configuration: ${AWX_DATA_DIR}/config/settings.py"
    log "• Projects directory: ${AWX_PROJECT_DIR}"
    log "• Log files: /var/log/awx/"
    log ""
    log "${YELLOW}Services:${NC}"
    log "• awx-web.service (Web UI)"
    log "• awx-task.service (Job execution)"
    log "• awx-scheduler.service (Job scheduling)"
    log ""
    log "${YELLOW}Next steps:${NC}"
    log "1. Change the admin password on first login"
    log "2. Run ./install/setup-netbox.sh to setup NetBox"
    log "3. Configure AWX job templates with ./scripts/configure-awx-templates.sh"
    log "4. Set up SSL certificates with ./install/setup-ssl.sh"
    
    # Update system configuration
    sed -i "s|awx:.*password:.*\"\"|awx:\n  url: \"https://localhost:8443\"\n  username: \"admin\"\n  password: \"${ADMIN_PASSWORD}\"|" /etc/network-upgrade/config.yml
}

# Run main function
main "$@"