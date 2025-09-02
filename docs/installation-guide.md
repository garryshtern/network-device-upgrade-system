# Installation Guide

Complete installation guide for the Network Device Upgrade Management System. This guide covers single server deployment with SQLite backend optimized for 1000+ device management.

## System Requirements

### Minimum Hardware Requirements
- **CPU**: 4 cores minimum (8 cores recommended)
- **RAM**: 8GB minimum (16GB recommended)  
- **Storage**: 100GB minimum (500GB recommended for firmware storage)
- **Network**: Reliable connectivity to all managed devices

### Supported Operating Systems
- **RHEL/CentOS**: 8.0 or higher
- **Ubuntu**: 20.04 LTS or higher
- **Rocky Linux**: 8.0 or higher
- **AlmaLinux**: 8.0 or higher

### Network Requirements
- **Management Access**: SSH access to all target network devices
- **Internet Access**: Required for downloading packages and firmware
- **DNS Resolution**: Proper DNS configuration for device hostnames
- **Time Synchronization**: NTP configured for accurate logging

## Pre-Installation Checklist

Before beginning installation, ensure:

- [ ] Fresh server installation with root access
- [ ] All system updates applied
- [ ] Firewall rules allow SSH (port 22)
- [ ] DNS resolution working properly
- [ ] NTP synchronization configured
- [ ] Sufficient disk space available
- [ ] Network connectivity to target devices tested

## Installation Process

### Step 1: Download and Prepare

```bash
# Clone the repository
git clone https://github.com/company/network-device-upgrade-system.git
cd network-device-upgrade-system

# Make installation scripts executable
chmod +x install/*.sh

# Verify system requirements
./scripts/system-health.sh
```

### Step 2: Base System Installation

Install the base system components including Python, Redis, and Nginx:

```bash
# Run as root
sudo ./install/install-system.sh
```

This script will:
- Detect your operating system and version
- Install required system packages
- Create the `network-upgrade` user and directories
- Configure Redis with optimized settings
- Set up Nginx with SSL-ready configuration
- Configure firewall rules
- Create systemd service templates
- Set up log rotation and cron jobs

**Expected Duration**: 15-30 minutes

### Step 3: AWX Installation

Install AWX (Ansible automation platform) with SQLite backend:

```bash
# Run as root
sudo ./install/install-awx.sh
```

This script will:
- Install AWX dependencies (Node.js, Python packages)
- Download and install AWX 23.5.0
- Configure SQLite database backend
- Create AWX systemd services
- Generate admin credentials
- Configure Nginx reverse proxy
- Test the installation

**Expected Duration**: 30-45 minutes

**Important**: Save the admin credentials displayed at the end of installation.

### Step 4: NetBox Installation

Install NetBox (DCIM/IPAM system) for device inventory:

```bash
# Run as root
sudo ./install/install-netbox.sh
```

This script will:
- Install NetBox with SQLite backend
- Configure device inventory structure
- Create custom fields for upgrade tracking
- Set up NetBox systemd services
- Configure Nginx integration
- Create initial superuser account

**Expected Duration**: 20-30 minutes

### Step 5: Telegraf Configuration

Configure Telegraf for metrics collection and InfluxDB integration:

```bash
# Run as root  
sudo ./install/configure-telegraf.sh
```

You will be prompted for:
- InfluxDB v2 server URL
- InfluxDB authentication token
- Organization name
- Bucket name for metrics

**Expected Duration**: 10-15 minutes

### Step 6: SSL Certificate Setup

Configure SSL certificates for secure web access:

```bash
# Run as root
sudo ./install/setup-ssl.sh
```

Options available:
- Generate self-signed certificates (default)
- Use existing certificate files
- Configure Let's Encrypt (if server has public DNS)

**Expected Duration**: 5-10 minutes

### Step 7: Service Creation and Startup

Create and start all system services:

```bash
# Run as root
sudo ./install/create-services.sh
```

This will:
- Enable all systemd services
- Start Redis, AWX, NetBox, and Telegraf
- Configure service dependencies
- Verify all services are running
- Test web interface connectivity

**Expected Duration**: 5-10 minutes

### Step 8: AWX Template Configuration

Configure AWX job templates and workflows:

```bash
# Run as network-upgrade user
su - network-upgrade
./scripts/configure-awx-templates.sh
```

This script will:
- Import all job templates
- Create workflow templates
- Set up inventories and credentials
- Configure notification templates
- Test template execution

**Expected Duration**: 15-20 minutes

## Post-Installation Configuration

### 1. Change Default Passwords

**AWX Admin Password**:
```bash
# Access AWX web interface at https://your-server:8443
# Login with credentials from /opt/network-upgrade/awx/config/admin_credentials.txt
# Go to Access → Users → admin → Edit to change password
```

**NetBox Admin Password**:
```bash
# Access NetBox web interface at https://your-server:8000
# Login with credentials from /opt/network-upgrade/netbox/config/admin_credentials.txt
# Go to Admin → Authentication and Authorization → Users to change password
```

### 2. Configure Device Access Credentials

**SSH Key Setup**:
```bash
# Generate SSH key pair for device access
ssh-keygen -t rsa -b 4096 -f /opt/network-upgrade/config/device_ssh_key -N ""

# Add public key to network devices or use username/password credentials in AWX
```

**AWX Credential Configuration**:
1. Access AWX web interface
2. Navigate to Resources → Credentials
3. Create "Network Device SSH" credential with:
   - Credential Type: Machine
   - Username: Your network device username
   - Password: Your network device password (or SSH key)

### 3. Device Inventory Setup

**NetBox Device Import**:
```bash
# Import devices from CSV file
./netbox-config/import-scripts/import-from-csv.py devices.csv

# Or sync from existing inventory system
./netbox-config/import-scripts/sync-from-inventory.py
```

**AWX Inventory Sync**:
1. In AWX, go to Resources → Inventories
2. Select "Network Devices" inventory
3. Go to Sources → NetBox Source
4. Click "Sync" to pull devices from NetBox

### 4. Firmware Repository Setup

```bash
# Create firmware storage directory
mkdir -p /opt/network-upgrade/firmware/{cisco,arista,fortinet,metamako,opengear}

# Set proper permissions
chown -R network-upgrade:network-upgrade /opt/network-upgrade/firmware
chmod 755 /opt/network-upgrade/firmware

# Create firmware hash files (example)
echo "abc123def456...sha512hash" > /opt/network-upgrade/firmware/cisco/n9000-dk9.10.2.3.F.bin.sha512
```

## Verification and Testing

### 1. Service Status Check

```bash
# Run system health check
/usr/local/bin/network-upgrade-health

# Check individual services
systemctl status redis nginx awx-web awx-task awx-scheduler netbox telegraf
```

### 2. Web Interface Access

- **AWX**: https://your-server:8443
- **NetBox**: https://your-server:8000
- **System Health**: Use `/usr/local/bin/network-upgrade-health`

### 3. Test Device Connectivity

```bash
# Run device health check job template in AWX
# Navigate to Templates → Device Health Check → Launch
# Select a few test devices and run validation
```

### 4. Verify Monitoring Integration

```bash
# Check Telegraf metrics collection
systemctl status telegraf

# Verify InfluxDB connectivity
telegraf --test --config /etc/telegraf/telegraf.conf --input-filter influxdb_v2_listener
```

## Troubleshooting Common Issues

### Installation Failures

**Problem**: Package installation fails
**Solution**: 
```bash
# Update package repositories
sudo dnf update -y    # RHEL/CentOS
sudo apt update -y    # Ubuntu

# Clear package cache
sudo dnf clean all    # RHEL/CentOS  
sudo apt clean        # Ubuntu
```

**Problem**: Service startup failures
**Solution**:
```bash
# Check service logs
journalctl -u service-name -f

# Check disk space
df -h

# Check memory usage
free -h
```

### Web Interface Issues

**Problem**: Cannot access AWX web interface
**Solution**:
```bash
# Check AWX services
systemctl status awx-web awx-task

# Check Nginx configuration
nginx -t
systemctl status nginx

# Check firewall
firewall-cmd --list-all   # RHEL/CentOS
ufw status               # Ubuntu
```

**Problem**: SSL certificate errors
**Solution**:
```bash
# Regenerate self-signed certificates
sudo ./install/setup-ssl.sh

# Check certificate validity
openssl x509 -in /etc/ssl/certs/network-upgrade.crt -text -noout
```

### Database Issues

**Problem**: SQLite database corruption
**Solution**:
```bash
# Stop services
systemctl stop awx-web awx-task netbox

# Backup databases
cp /opt/network-upgrade/awx/database/awx.db /var/backups/network-upgrade/
cp /opt/network-upgrade/netbox/database/netbox.db /var/backups/network-upgrade/

# Check database integrity
sqlite3 /opt/network-upgrade/awx/database/awx.db "PRAGMA integrity_check;"

# Restore from backup if needed
/usr/local/bin/network-upgrade-restore
```

## Backup and Recovery

### Automated Backups

Daily backups are configured automatically:
```bash
# Backup script location
/usr/local/bin/network-upgrade-backup

# Backup storage location  
/var/backups/network-upgrade/

# Restore script
/usr/local/bin/network-upgrade-restore
```

### Manual Backup

```bash
# Create immediate backup
/usr/local/bin/network-upgrade-backup

# Backup specific components
systemctl stop awx-web awx-task netbox
cp /opt/network-upgrade/awx/database/awx.db /backup/location/
cp /opt/network-upgrade/netbox/database/netbox.db /backup/location/
cp -r /etc/network-upgrade /backup/location/
systemctl start awx-web awx-task netbox
```

## Performance Tuning

### For High Device Count (1000+ devices)

**Increase Connection Limits**:
```bash
# Edit /etc/network-upgrade/config.yml
performance:
  max_concurrent_jobs: 100
  max_device_connections: 200
  connection_timeout: 45
```

**Optimize AWX Settings**:
```bash
# Edit AWX configuration
# Increase worker processes and memory limits
```

**Database Optimization**:
```bash
# SQLite optimization for high load
# Configure WAL mode and increase cache size
```

## Security Hardening

### 1. SSL/TLS Configuration

- Use strong SSL ciphers and protocols
- Implement proper certificate management
- Enable HTTP Strict Transport Security (HSTS)

### 2. Access Control

- Change all default passwords
- Implement role-based access control in AWX
- Use SSH keys for device authentication
- Regular credential rotation

### 3. System Security

- Keep all packages updated
- Configure proper firewall rules
- Enable system audit logging
- Implement intrusion detection

## Next Steps

After successful installation:

1. **Device Onboarding**: Import your network device inventory into NetBox
2. **Credential Setup**: Configure device access credentials in AWX
3. **Test Upgrades**: Perform test upgrades on non-production devices
4. **Monitoring Setup**: Configure Grafana dashboards for visualization
5. **Process Documentation**: Document your specific upgrade procedures
6. **Staff Training**: Train operations staff on the web interfaces and procedures

For detailed operational procedures, see the [User Guide](user-guide.md) and [Administrator Guide](administrator-guide.md).

## Support and Maintenance

### Log Locations
- **System Logs**: `/var/log/network-upgrade/`
- **AWX Logs**: `/var/log/awx/`
- **NetBox Logs**: `/var/log/netbox/`
- **Nginx Logs**: `/var/log/nginx/`

### Maintenance Schedule
- **Daily**: Automated backups and health checks
- **Weekly**: Log rotation and cleanup
- **Monthly**: System updates and security patches
- **Quarterly**: Full system backup verification

### Getting Help
- Review the [Troubleshooting Guide](troubleshooting.md)
- Check system health with `/usr/local/bin/network-upgrade-health`
- Examine log files in `/var/log/network-upgrade/`
- Consult vendor-specific guides in [docs/vendor-guides/](vendor-guides/)