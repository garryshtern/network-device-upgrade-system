#!/bin/bash

# SSL Certificate Setup Script for Network Upgrade System
# Creates self-signed certificates or integrates with Let's Encrypt

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_FILE="/var/log/network-upgrade/ssl-setup.log"
SSL_DIR="/etc/ssl"
CERT_DIR="${SSL_DIR}/certs"
KEY_DIR="${SSL_DIR}/private"
CERT_NAME="network-upgrade"

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

# Get SSL certificate configuration
get_ssl_config() {
    log "${BLUE}SSL Certificate Configuration${NC}"
    
    echo ""
    echo "This script will set up SSL certificates for the Network Upgrade System."
    echo "You can choose between self-signed certificates or Let's Encrypt."
    echo ""
    
    # Get domain information
    read -p "Enter your domain name (e.g., network-upgrade.example.com) or press Enter for localhost: " DOMAIN_NAME
    DOMAIN_NAME=${DOMAIN_NAME:-"localhost"}
    
    # Get IP address for SAN
    DEFAULT_IP=$(ip route get 1.1.1.1 | awk '{print $7}' | head -1)
    read -p "Enter server IP address [$DEFAULT_IP]: " SERVER_IP
    SERVER_IP=${SERVER_IP:-$DEFAULT_IP}
    
    # Certificate type selection
    echo ""
    echo "Certificate options:"
    echo "1) Self-signed certificate (recommended for testing/internal use)"
    echo "2) Let's Encrypt certificate (requires public domain and port 80/443 access)"
    echo ""
    read -p "Select certificate type [1]: " CERT_TYPE
    CERT_TYPE=${CERT_TYPE:-1}
    
    log "${GREEN}✓ SSL configuration collected${NC}"
}

# Install SSL dependencies
install_ssl_dependencies() {
    log "${BLUE}Installing SSL dependencies...${NC}"
    
    case $(lsb_release -is 2>/dev/null || echo "Unknown") in
        "CentOS"|"RedHat"|"Rocky"|"AlmaLinux")
            dnf install -y openssl certbot
            ;;
        "Ubuntu"|"Debian")
            apt-get update
            apt-get install -y openssl certbot
            ;;
        *)
            log "${YELLOW}⚠ Unknown OS, assuming OpenSSL is available${NC}"
            ;;
    esac
    
    # Ensure directories exist
    mkdir -p "${CERT_DIR}" "${KEY_DIR}"
    chmod 755 "${CERT_DIR}"
    chmod 700 "${KEY_DIR}"
    
    log "${GREEN}✓ SSL dependencies installed${NC}"
}

# Create self-signed certificate
create_self_signed_cert() {
    log "${BLUE}Creating self-signed SSL certificate...${NC}"
    
    # Generate private key
    openssl genrsa -out "${KEY_DIR}/${CERT_NAME}.key" 4096
    chmod 600 "${KEY_DIR}/${CERT_NAME}.key"
    
    # Create certificate configuration
    cat > "/tmp/cert_config.conf" << EOF
[req]
default_bits = 4096
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
C=US
ST=State
L=City
O=Network Operations
OU=Network Upgrade System
CN=${DOMAIN_NAME}

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${DOMAIN_NAME}
DNS.2 = localhost
DNS.3 = *.${DOMAIN_NAME}
IP.1 = ${SERVER_IP}
IP.2 = 127.0.0.1
EOF
    
    # Generate certificate signing request
    openssl req -new -key "${KEY_DIR}/${CERT_NAME}.key" -out "/tmp/${CERT_NAME}.csr" -config "/tmp/cert_config.conf"
    
    # Generate self-signed certificate (valid for 2 years)
    openssl x509 -req -in "/tmp/${CERT_NAME}.csr" -signkey "${KEY_DIR}/${CERT_NAME}.key" \
        -out "${CERT_DIR}/${CERT_NAME}.crt" -days 730 -extensions v3_req -extfile "/tmp/cert_config.conf"
    
    # Set permissions
    chmod 644 "${CERT_DIR}/${CERT_NAME}.crt"
    chown root:root "${CERT_DIR}/${CERT_NAME}.crt" "${KEY_DIR}/${CERT_NAME}.key"
    
    # Cleanup
    rm -f "/tmp/${CERT_NAME}.csr" "/tmp/cert_config.conf"
    
    log "${GREEN}✓ Self-signed certificate created${NC}"
}

# Setup Let's Encrypt certificate
setup_letsencrypt_cert() {
    log "${BLUE}Setting up Let's Encrypt certificate...${NC}"
    
    # Check if domain is publicly accessible
    if ! dig +short "$DOMAIN_NAME" >/dev/null 2>&1; then
        log "${YELLOW}⚠ Warning: Domain $DOMAIN_NAME may not be publicly resolvable${NC}"
        read -p "Continue anyway? [y/N]: " CONTINUE
        if [[ "${CONTINUE,,}" != "y" ]]; then
            error_exit "Let's Encrypt setup cancelled"
        fi
    fi
    
    # Stop web services temporarily
    systemctl stop nginx || true
    
    # Get certificate
    certbot certonly --standalone \
        --agree-tos \
        --no-eff-email \
        --email "admin@${DOMAIN_NAME}" \
        -d "$DOMAIN_NAME" \
        --non-interactive
    
    if [[ $? -eq 0 ]]; then
        # Link certificates to standard location
        ln -sf "/etc/letsencrypt/live/${DOMAIN_NAME}/fullchain.pem" "${CERT_DIR}/${CERT_NAME}.crt"
        ln -sf "/etc/letsencrypt/live/${DOMAIN_NAME}/privkey.pem" "${KEY_DIR}/${CERT_NAME}.key"
        
        # Setup auto-renewal
        setup_cert_renewal
        
        log "${GREEN}✓ Let's Encrypt certificate obtained${NC}"
    else
        error_exit "Failed to obtain Let's Encrypt certificate"
    fi
    
    # Restart web services
    systemctl start nginx || true
}

# Setup certificate auto-renewal
setup_cert_renewal() {
    log "${BLUE}Setting up certificate auto-renewal...${NC}"
    
    # Create renewal script
    cat > /usr/local/bin/renew-ssl-cert << 'EOF'
#!/bin/bash
# SSL Certificate Renewal Script for Network Upgrade System

LOG_FILE="/var/log/network-upgrade/ssl-renewal.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Renew certificate
log "Starting certificate renewal process"

if certbot renew --quiet --no-self-upgrade; then
    log "Certificate renewed successfully"
    
    # Reload web services
    if systemctl reload nginx; then
        log "Nginx reloaded successfully"
    else
        log "ERROR: Failed to reload Nginx"
    fi
    
    # Test certificate validity
    if openssl x509 -in /etc/ssl/certs/network-upgrade.crt -noout -checkend 2592000; then
        log "Certificate is valid for at least 30 days"
    else
        log "WARNING: Certificate expires within 30 days"
    fi
    
else
    log "ERROR: Certificate renewal failed"
    exit 1
fi

log "Certificate renewal process completed"
EOF
    
    chmod +x /usr/local/bin/renew-ssl-cert
    
    # Create systemd service for renewal
    cat > /etc/systemd/system/ssl-cert-renewal.service << 'EOF'
[Unit]
Description=SSL Certificate Renewal
Documentation=man:certbot(8)

[Service]
Type=oneshot
ExecStart=/usr/local/bin/renew-ssl-cert
StandardOutput=journal
StandardError=journal
EOF

    # Create systemd timer for renewal
    cat > /etc/systemd/system/ssl-cert-renewal.timer << 'EOF'
[Unit]
Description=SSL Certificate Renewal Timer
Documentation=man:certbot(8)

[Timer]
OnCalendar=daily
RandomizedDelaySec=3600
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Enable renewal timer
    systemctl daemon-reload
    systemctl enable ssl-cert-renewal.timer
    systemctl start ssl-cert-renewal.timer
    
    log "${GREEN}✓ Certificate auto-renewal configured${NC}"
}

# Create certificate validation script
create_cert_validator() {
    log "${BLUE}Creating certificate validation script...${NC}"
    
    cat > /usr/local/bin/validate-ssl-cert << 'EOF'
#!/bin/bash
# SSL Certificate Validation Script

CERT_FILE="/etc/ssl/certs/network-upgrade.crt"
KEY_FILE="/etc/ssl/private/network-upgrade.key"

echo "=== SSL Certificate Validation ==="
echo "Date: $(date)"
echo ""

# Check if files exist
if [[ ! -f "$CERT_FILE" ]]; then
    echo "✗ Certificate file not found: $CERT_FILE"
    exit 1
fi

if [[ ! -f "$KEY_FILE" ]]; then
    echo "✗ Private key file not found: $KEY_FILE"
    exit 1
fi

echo "✓ Certificate and key files exist"

# Check certificate validity
echo ""
echo "=== Certificate Information ==="
openssl x509 -in "$CERT_FILE" -noout -subject -issuer -dates

# Check if certificate matches private key
CERT_MODULUS=$(openssl x509 -noout -modulus -in "$CERT_FILE" | openssl md5)
KEY_MODULUS=$(openssl rsa -noout -modulus -in "$KEY_FILE" 2>/dev/null | openssl md5)

if [[ "$CERT_MODULUS" == "$KEY_MODULUS" ]]; then
    echo "✓ Certificate matches private key"
else
    echo "✗ Certificate does not match private key"
    exit 1
fi

# Check certificate expiration
if openssl x509 -in "$CERT_FILE" -noout -checkend 0; then
    echo "✓ Certificate is currently valid"
else
    echo "✗ Certificate has expired"
    exit 1
fi

# Check if certificate expires within 30 days
if openssl x509 -in "$CERT_FILE" -noout -checkend 2592000; then
    echo "✓ Certificate is valid for at least 30 days"
else
    echo "⚠ Certificate expires within 30 days"
fi

# Check SAN entries
echo ""
echo "=== Subject Alternative Names ==="
openssl x509 -in "$CERT_FILE" -noout -text | grep -A 10 "Subject Alternative Name" || echo "No SAN entries found"

# Test SSL connection to services
echo ""
echo "=== Service SSL Tests ==="

# Test AWX (port 8443)
if timeout 5 openssl s_client -connect localhost:8443 -servername localhost </dev/null &>/dev/null; then
    echo "✓ AWX SSL connection successful (port 8443)"
else
    echo "✗ AWX SSL connection failed (port 8443)"
fi

# Test NetBox (port 8000)
if timeout 5 openssl s_client -connect localhost:8000 -servername localhost </dev/null &>/dev/null; then
    echo "✓ NetBox SSL connection successful (port 8000)"
else
    echo "✗ NetBox SSL connection failed (port 8000)"
fi

echo ""
echo "=== Validation Complete ==="
EOF

    chmod +x /usr/local/bin/validate-ssl-cert
    
    log "${GREEN}✓ Certificate validation script created${NC}"
}

# Update service configurations for SSL
update_service_configs() {
    log "${BLUE}Updating service configurations for SSL...${NC}"
    
    # Update system configuration
    sed -i "s|ssl_cert:.*|ssl_cert: \"${CERT_DIR}/${CERT_NAME}.crt\"|" /etc/network-upgrade/config.yml
    sed -i "s|ssl_key:.*|ssl_key: \"${KEY_DIR}/${CERT_NAME}.key\"|" /etc/network-upgrade/config.yml
    
    # Restart services to pick up new certificates
    systemctl reload nginx || true
    
    log "${GREEN}✓ Service configurations updated${NC}"
}

# Test SSL configuration
test_ssl_configuration() {
    log "${BLUE}Testing SSL configuration...${NC}"
    
    # Validate certificate
    if /usr/local/bin/validate-ssl-cert; then
        log "${GREEN}✓ SSL certificate validation passed${NC}"
    else
        log "${YELLOW}⚠ SSL certificate validation warnings (see details above)${NC}"
    fi
    
    # Test web service SSL
    sleep 5
    
    # Test AWX HTTPS
    if curl -k -s --connect-timeout 10 "https://localhost:8443/" >/dev/null; then
        log "${GREEN}✓ AWX HTTPS is accessible${NC}"
    else
        log "${YELLOW}⚠ AWX HTTPS test failed (service may not be running)${NC}"
    fi
    
    # Test NetBox HTTPS
    if curl -k -s --connect-timeout 10 "https://localhost:8000/" >/dev/null; then
        log "${GREEN}✓ NetBox HTTPS is accessible${NC}"
    else
        log "${YELLOW}⚠ NetBox HTTPS test failed (service may not be running)${NC}"
    fi
}

# Create SSL management utilities
create_ssl_utilities() {
    log "${BLUE}Creating SSL management utilities...${NC}"
    
    # Create certificate backup script
    cat > /usr/local/bin/backup-ssl-certs << 'EOF'
#!/bin/bash
# SSL Certificate Backup Script

BACKUP_DIR="/var/backups/network-upgrade/ssl"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/ssl_backup_${TIMESTAMP}.tar.gz"

echo "Creating SSL certificate backup..."

mkdir -p "$BACKUP_DIR"

# Create backup archive
tar -czf "$BACKUP_FILE" \
    -C /etc/ssl certs/network-upgrade.crt private/network-upgrade.key \
    -C /etc letsencrypt 2>/dev/null || \
tar -czf "$BACKUP_FILE" \
    -C /etc/ssl certs/network-upgrade.crt private/network-upgrade.key

if [[ -f "$BACKUP_FILE" ]]; then
    echo "SSL backup created: $BACKUP_FILE"
    # Keep only last 10 backups
    find "$BACKUP_DIR" -name "ssl_backup_*.tar.gz" -type f | sort -r | tail -n +11 | xargs rm -f
    echo "Old backups cleaned up"
else
    echo "ERROR: Failed to create SSL backup"
    exit 1
fi
EOF

    chmod +x /usr/local/bin/backup-ssl-certs
    
    # Create certificate info script
    cat > /usr/local/bin/ssl-cert-info << 'EOF'
#!/bin/bash
# SSL Certificate Information Display

CERT_FILE="/etc/ssl/certs/network-upgrade.crt"

if [[ ! -f "$CERT_FILE" ]]; then
    echo "SSL certificate not found: $CERT_FILE"
    exit 1
fi

echo "=== SSL Certificate Information ==="
echo ""

# Basic info
echo "Subject: $(openssl x509 -in "$CERT_FILE" -noout -subject | sed 's/subject=//')"
echo "Issuer: $(openssl x509 -in "$CERT_FILE" -noout -issuer | sed 's/issuer=//')"
echo ""

# Validity period
echo "Valid From: $(openssl x509 -in "$CERT_FILE" -noout -startdate | sed 's/notBefore=//')"
echo "Valid To: $(openssl x509 -in "$CERT_FILE" -noout -enddate | sed 's/notAfter=//')"
echo ""

# Days until expiration
EXPIRY_DATE=$(openssl x509 -in "$CERT_FILE" -noout -enddate | sed 's/notAfter=//')
EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s)
CURRENT_EPOCH=$(date +%s)
DAYS_LEFT=$(( ($EXPIRY_EPOCH - $CURRENT_EPOCH) / 86400 ))

if [[ $DAYS_LEFT -gt 30 ]]; then
    echo "Days until expiration: $DAYS_LEFT ✓"
elif [[ $DAYS_LEFT -gt 0 ]]; then
    echo "Days until expiration: $DAYS_LEFT ⚠"
else
    echo "Certificate expired $((-$DAYS_LEFT)) days ago ✗"
fi
echo ""

# SAN entries
echo "Subject Alternative Names:"
openssl x509 -in "$CERT_FILE" -noout -text | grep -A 1 "Subject Alternative Name" | tail -1 | sed 's/.*: //' | sed 's/, /\n/g' | sed 's/^/  /'
echo ""

# Key size
echo "Key Size: $(openssl x509 -in "$CERT_FILE" -noout -text | grep "Public-Key:" | sed 's/.*(//' | sed 's/).*//')"

# Signature algorithm
echo "Signature Algorithm: $(openssl x509 -in "$CERT_FILE" -noout -text | grep "Signature Algorithm" | head -1 | sed 's/.*: //')"
EOF

    chmod +x /usr/local/bin/ssl-cert-info
    
    log "${GREEN}✓ SSL management utilities created${NC}"
}

# Main SSL setup function
main() {
    log "${GREEN}Starting SSL certificate setup...${NC}"
    log "${BLUE}Setup started at: $(date)${NC}"
    
    get_ssl_config
    install_ssl_dependencies
    
    case $CERT_TYPE in
        1)
            create_self_signed_cert
            ;;
        2)
            setup_letsencrypt_cert
            ;;
        *)
            error_exit "Invalid certificate type selection"
            ;;
    esac
    
    create_cert_validator
    update_service_configs
    test_ssl_configuration
    create_ssl_utilities
    
    # Create initial backup
    /usr/local/bin/backup-ssl-certs
    
    log "${GREEN}✓ SSL certificate setup completed successfully!${NC}"
    log "${BLUE}Setup finished at: $(date)${NC}"
    
    echo ""
    log "${YELLOW}SSL Certificate Setup Summary:${NC}"
    log "• Certificate: ${CERT_DIR}/${CERT_NAME}.crt"
    log "• Private Key: ${KEY_DIR}/${CERT_NAME}.key"
    log "• Domain: ${DOMAIN_NAME}"
    log "• Server IP: ${SERVER_IP}"
    log "• Type: $([ $CERT_TYPE -eq 1 ] && echo 'Self-signed' || echo 'Let'\''s Encrypt')"
    log ""
    log "${YELLOW}Management Commands:${NC}"
    log "• Certificate info: /usr/local/bin/ssl-cert-info"
    log "• Validate certificate: /usr/local/bin/validate-ssl-cert"
    log "• Backup certificates: /usr/local/bin/backup-ssl-certs"
    if [[ $CERT_TYPE -eq 2 ]]; then
        log "• Renew certificate: /usr/local/bin/renew-ssl-cert"
    fi
    log ""
    log "${YELLOW}Service URLs (with SSL):${NC}"
    log "• AWX: https://${DOMAIN_NAME}:8443/"
    log "• NetBox: https://${DOMAIN_NAME}:8000/"
    log ""
    if [[ $CERT_TYPE -eq 1 ]]; then
        log "${YELLOW}Important Notes:${NC}"
        log "• Self-signed certificate requires browser security exception"
        log "• Consider using Let's Encrypt for production environments"
        log "• Certificate expires in 2 years ($(date -d '+2 years' '+%Y-%m-%d'))"
    else
        log "${YELLOW}Important Notes:${NC}"
        log "• Certificate will auto-renew via systemd timer"
        log "• Monitor renewal logs in /var/log/network-upgrade/ssl-renewal.log"
    fi
    log ""
    log "${YELLOW}Next steps:${NC}"
    log "1. Test SSL access to web interfaces"
    log "2. Configure firewall rules for HTTPS ports"
    log "3. Update DNS records if using custom domain"
    log "4. Run ./install/create-services.sh to finalize setup"
}

# Run main function
main "$@"