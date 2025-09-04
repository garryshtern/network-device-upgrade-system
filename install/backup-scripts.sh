#!/bin/bash

# Backup and Recovery Scripts Setup for Network Upgrade System
# Creates comprehensive backup and disaster recovery capabilities

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_FILE="/var/log/network-upgrade/backup-setup.log"
BACKUP_BASE_DIR="/var/backups/network-upgrade"

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

# Create backup directories
create_backup_directories() {
    log "${BLUE}Creating backup directory structure...${NC}"
    
    mkdir -p "${BACKUP_BASE_DIR}"/{daily,weekly,monthly,manual,system,databases,configs,logs}
    mkdir -p "${BACKUP_BASE_DIR}/restore"
    
    # Set proper permissions
    chown -R network-upgrade:network-upgrade "${BACKUP_BASE_DIR}"
    chmod 750 "${BACKUP_BASE_DIR}"
    chmod 755 "${BACKUP_BASE_DIR}/restore"
    
    log "${GREEN}✓ Backup directories created${NC}"
}

# Create comprehensive backup script
create_backup_script() {
    log "${BLUE}Creating comprehensive backup script...${NC}"
    
    cat > /usr/local/bin/network-upgrade-backup << 'EOF'
#!/bin/bash
# Network Device Upgrade System Comprehensive Backup Script

# Configuration
BACKUP_BASE="/var/backups/network-upgrade"
LOG_FILE="/var/log/network-upgrade/backup.log"
RETENTION_DAILY=7
RETENTION_WEEKLY=4
RETENTION_MONTHLY=12

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

usage() {
    echo "Network Upgrade System Backup Script"
    echo ""
    echo "Usage: $0 {daily|weekly|monthly|manual|system|database|config|full|restore}"
    echo ""
    echo "Backup Types:"
    echo "  daily     Daily automated backup (configs + databases)"
    echo "  weekly    Weekly backup (includes logs and metrics)"
    echo "  monthly   Monthly full system backup"
    echo "  manual    Manual backup with custom retention"
    echo "  system    System configuration backup only"
    echo "  database  Database backup only"
    echo "  config    Configuration files backup only"
    echo "  full      Complete system backup (same as monthly)"
    echo "  restore   Interactive restore wizard"
    echo ""
    echo "Examples:"
    echo "  $0 daily"
    echo "  $0 manual"
    echo "  $0 restore"
}

backup_databases() {
    local backup_dir="$1"
    log "Backing up databases to $backup_dir"
    
    mkdir -p "$backup_dir/databases"
    
    # AWX SQLite database
    if [[ -f "/opt/network-upgrade/awx/database/awx.db" ]]; then
        log "Backing up AWX database..."
        sqlite3 /opt/network-upgrade/awx/database/awx.db ".backup $backup_dir/databases/awx_$(date +%Y%m%d_%H%M%S).db"
        log "✓ AWX database backed up"
    fi
    
    # NetBox SQLite database  
    if [[ -f "/opt/network-upgrade/netbox/database/netbox.db" ]]; then
        log "Backing up NetBox database..."
        sqlite3 /opt/network-upgrade/netbox/database/netbox.db ".backup $backup_dir/databases/netbox_$(date +%Y%m%d_%H%M%S).db"
        log "✓ NetBox database backed up"
    fi
    
    # Redis data dump
    if command -v redis-cli &> /dev/null; then
        log "Creating Redis data dump..."
        redis-cli -a "ChangeMeInProduction123!" BGSAVE >/dev/null
        sleep 5
        if [[ -f "/var/lib/redis/network-upgrade-redis.rdb" ]]; then
            cp /var/lib/redis/network-upgrade-redis.rdb "$backup_dir/databases/redis_$(date +%Y%m%d_%H%M%S).rdb"
            log "✓ Redis data backed up"
        fi
    fi
}

backup_configurations() {
    local backup_dir="$1"
    log "Backing up configuration files to $backup_dir"
    
    mkdir -p "$backup_dir/configs"
    
    # System configuration
    cp -r /etc/network-upgrade "$backup_dir/configs/" 2>/dev/null || true
    
    # AWX configuration
    if [[ -d "/opt/network-upgrade/awx/config" ]]; then
        cp -r /opt/network-upgrade/awx/config "$backup_dir/configs/awx-config"
    fi
    
    # NetBox configuration
    if [[ -d "/opt/network-upgrade/netbox/config" ]]; then
        cp -r /opt/network-upgrade/netbox/config "$backup_dir/configs/netbox-config"
    fi
    
    # SSL certificates
    mkdir -p "$backup_dir/configs/ssl"
    cp /etc/ssl/certs/network-upgrade.crt "$backup_dir/configs/ssl/" 2>/dev/null || true
    cp /etc/ssl/private/network-upgrade.key "$backup_dir/configs/ssl/" 2>/dev/null || true
    
    # Service configurations
    mkdir -p "$backup_dir/configs/services"
    cp /etc/systemd/system/network-upgrade*.service "$backup_dir/configs/services/" 2>/dev/null || true
    cp /etc/systemd/system/awx*.service "$backup_dir/configs/services/" 2>/dev/null || true
    cp /etc/systemd/system/netbox*.service "$backup_dir/configs/services/" 2>/dev/null || true
    
    # Nginx configuration
    cp -r /etc/nginx "$backup_dir/configs/" 2>/dev/null || true
    
    # Redis configuration
    cp /etc/redis/redis.conf "$backup_dir/configs/" 2>/dev/null || true
    
    # Telegraf configuration
    cp -r /etc/telegraf "$backup_dir/configs/" 2>/dev/null || true
    
    log "✓ Configuration files backed up"
}

backup_logs() {
    local backup_dir="$1"
    log "Backing up log files to $backup_dir"
    
    mkdir -p "$backup_dir/logs"
    
    # Application logs (recent only to save space)
    find /var/log/network-upgrade -name "*.log" -mtime -7 -exec cp {} "$backup_dir/logs/" \; 2>/dev/null || true
    find /var/log/awx -name "*.log" -mtime -7 -exec cp {} "$backup_dir/logs/" \; 2>/dev/null || true
    find /var/log/netbox -name "*.log" -mtime -7 -exec cp {} "$backup_dir/logs/" \; 2>/dev/null || true
    find /var/log/redis -name "*.log" -mtime -7 -exec cp {} "$backup_dir/logs/" \; 2>/dev/null || true
    find /var/log/telegraf -name "*.log" -mtime -7 -exec cp {} "$backup_dir/logs/" \; 2>/dev/null || true
    
    # System logs (compressed)
    journalctl --since="7 days ago" --output=export | gzip > "$backup_dir/logs/systemd_$(date +%Y%m%d_%H%M%S).log.gz"
    
    log "✓ Log files backed up"
}

backup_system_state() {
    local backup_dir="$1"
    log "Backing up system state to $backup_dir"
    
    mkdir -p "$backup_dir/system"
    
    # Package lists
    if command -v dnf &> /dev/null; then
        dnf list installed > "$backup_dir/system/packages_installed.txt"
    elif command -v apt &> /dev/null; then
        dpkg --get-selections > "$backup_dir/system/packages_installed.txt"
    fi
    
    # System information
    uname -a > "$backup_dir/system/system_info.txt"
    cat /etc/os-release >> "$backup_dir/system/system_info.txt"
    
    # Service status
    systemctl list-units --type=service --state=active > "$backup_dir/system/active_services.txt"
    
    # Network configuration
    ip addr show > "$backup_dir/system/network_config.txt"
    ip route show >> "$backup_dir/system/network_config.txt"
    
    # Firewall rules
    if command -v iptables &> /dev/null; then
        iptables -L > "$backup_dir/system/iptables_rules.txt" 2>/dev/null || true
    fi
    
    # Cron jobs
    crontab -l -u network-upgrade > "$backup_dir/system/crontab_network-upgrade.txt" 2>/dev/null || true
    
    log "✓ System state backed up"
}

backup_ansible_content() {
    local backup_dir="$1"
    log "Backing up Ansible content to $backup_dir"
    
    if [[ -d "/opt/network-upgrade/awx/projects/network-automation" ]]; then
        mkdir -p "$backup_dir/ansible"
        cp -r /opt/network-upgrade/awx/projects/network-automation "$backup_dir/ansible/"
        log "✓ Ansible content backed up"
    fi
}

create_backup_archive() {
    local backup_dir="$1"
    local backup_type="$2"
    
    log "Creating compressed archive for $backup_type backup"
    
    cd "$(dirname "$backup_dir")"
    tar -czf "${backup_dir}.tar.gz" "$(basename "$backup_dir")"
    
    if [[ -f "${backup_dir}.tar.gz" ]]; then
        rm -rf "$backup_dir"
        local size=$(du -h "${backup_dir}.tar.gz" | cut -f1)
        log "✓ Backup archive created: ${backup_dir}.tar.gz ($size)"
    else
        log "✗ Failed to create backup archive"
        return 1
    fi
}

cleanup_old_backups() {
    local backup_type="$1"
    local retention_days="$2"
    
    log "Cleaning up old $backup_type backups (keeping $retention_days)"
    
    find "$BACKUP_BASE/$backup_type" -name "*.tar.gz" -mtime +$retention_days -delete 2>/dev/null || true
    
    local remaining=$(find "$BACKUP_BASE/$backup_type" -name "*.tar.gz" | wc -l)
    log "✓ Cleanup complete. $remaining backup(s) remaining."
}

perform_backup() {
    local backup_type="$1"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="$BACKUP_BASE/$backup_type/${backup_type}_$timestamp"
    
    log "===========================================" 
    log "Starting $backup_type backup at $(date)"
    log "Backup directory: $backup_dir"
    log "==========================================="
    
    mkdir -p "$backup_dir"
    
    case "$backup_type" in
        daily)
            backup_configurations "$backup_dir"
            backup_databases "$backup_dir"
            create_backup_archive "$backup_dir" "$backup_type"
            cleanup_old_backups "$backup_type" $RETENTION_DAILY
            ;;
        weekly)
            backup_configurations "$backup_dir"
            backup_databases "$backup_dir"
            backup_logs "$backup_dir"
            backup_system_state "$backup_dir"
            create_backup_archive "$backup_dir" "$backup_type"
            cleanup_old_backups "$backup_type" $((RETENTION_WEEKLY * 7))
            ;;
        monthly|full)
            backup_configurations "$backup_dir"
            backup_databases "$backup_dir"
            backup_logs "$backup_dir"
            backup_system_state "$backup_dir"
            backup_ansible_content "$backup_dir"
            create_backup_archive "$backup_dir" "$backup_type"
            cleanup_old_backups "$backup_type" $((RETENTION_MONTHLY * 30))
            ;;
        manual)
            backup_configurations "$backup_dir"
            backup_databases "$backup_dir"
            backup_logs "$backup_dir"
            create_backup_archive "$backup_dir" "$backup_type"
            # No automatic cleanup for manual backups
            ;;
        system)
            backup_configurations "$backup_dir"
            backup_system_state "$backup_dir"
            create_backup_archive "$backup_dir" "$backup_type"
            ;;
        database)
            backup_databases "$backup_dir"
            create_backup_archive "$backup_dir" "$backup_type"
            ;;
        config)
            backup_configurations "$backup_dir"
            create_backup_archive "$backup_dir" "$backup_type"
            ;;
    esac
    
    log "==========================================="
    log "$backup_type backup completed at $(date)"
    log "==========================================="
}

restore_wizard() {
    echo "=========================================="
    echo "Network Upgrade System Restore Wizard"
    echo "=========================================="
    echo ""
    
    echo "Available backup types:"
    for backup_type in daily weekly monthly manual system database config; do
        if [[ -d "$BACKUP_BASE/$backup_type" ]]; then
            backup_count=$(find "$BACKUP_BASE/$backup_type" -name "*.tar.gz" | wc -l)
            if [[ $backup_count -gt 0 ]]; then
                echo "  $backup_type ($backup_count backups available)"
            fi
        fi
    done
    
    echo ""
    read -p "Select backup type to restore from: " backup_type
    
    if [[ ! -d "$BACKUP_BASE/$backup_type" ]]; then
        echo "Error: Backup type '$backup_type' not found"
        return 1
    fi
    
    echo ""
    echo "Available backups for $backup_type:"
    find "$BACKUP_BASE/$backup_type" -name "*.tar.gz" -printf "%f\t%TY-%Tm-%Td %TH:%TM\n" | sort -r | head -10
    
    echo ""
    read -p "Enter backup filename to restore: " backup_file
    
    backup_path="$BACKUP_BASE/$backup_type/$backup_file"
    if [[ ! -f "$backup_path" ]]; then
        echo "Error: Backup file '$backup_file' not found"
        return 1
    fi
    
    echo ""
    echo "WARNING: This will restore system files from backup."
    echo "Current configurations may be overwritten."
    echo ""
    read -p "Continue? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        echo "Restore cancelled"
        return 1
    fi
    
    # Perform restore
    restore_dir="$BACKUP_BASE/restore/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$restore_dir"
    
    echo "Extracting backup to $restore_dir..."
    tar -xzf "$backup_path" -C "$restore_dir"
    
    echo ""
    echo "Backup extracted. Manual steps required:"
    echo "1. Stop services: network-upgrade-services stop"
    echo "2. Review files in: $restore_dir"
    echo "3. Copy desired files to their original locations"
    echo "4. Start services: network-upgrade-services start"
    echo ""
    echo "For database restore, use sqlite3 .restore command"
    echo "For configuration restore, copy files from configs/ directory"
}

case "${1:-}" in
    daily|weekly|monthly|manual|system|database|config|full)
        perform_backup "$1"
        ;;
    restore)
        restore_wizard
        ;;
    *)
        usage
        exit 1
        ;;
esac
EOF

    chmod +x /usr/local/bin/network-upgrade-backup
    chown network-upgrade:network-upgrade /usr/local/bin/network-upgrade-backup
    
    log "${GREEN}✓ Comprehensive backup script created${NC}"
}

# Create backup monitoring script
create_backup_monitor() {
    log "${BLUE}Creating backup monitoring script...${NC}"
    
    cat > /usr/local/bin/backup-monitor << 'EOF'
#!/bin/bash
# Backup Monitoring and Alerting Script

BACKUP_BASE="/var/backups/network-upgrade"
LOG_FILE="/var/log/network-upgrade/backup-monitor.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

check_backup_health() {
    log "Starting backup health check"
    
    # Check if daily backup exists (within last 25 hours)
    daily_backup=$(find "$BACKUP_BASE/daily" -name "*.tar.gz" -mtime -1 | head -1)
    if [[ -n "$daily_backup" ]]; then
        log "✓ Recent daily backup found: $(basename "$daily_backup")"
    else
        log "✗ No recent daily backup found (last 24 hours)"
        return 1
    fi
    
    # Check backup directory sizes
    for backup_type in daily weekly monthly manual; do
        if [[ -d "$BACKUP_BASE/$backup_type" ]]; then
            backup_count=$(find "$BACKUP_BASE/$backup_type" -name "*.tar.gz" | wc -l)
            total_size=$(du -sh "$BACKUP_BASE/$backup_type" 2>/dev/null | cut -f1 || echo "0")
            log "Backup type $backup_type: $backup_count files, $total_size total"
        fi
    done
    
    # Check for backup failures in logs
    recent_failures=$(grep -c "ERROR\|FAILED" "$LOG_FILE" 2>/dev/null || echo 0)
    if [[ $recent_failures -gt 0 ]]; then
        log "⚠ Found $recent_failures recent backup errors"
    else
        log "✓ No recent backup errors found"
    fi
    
    # Check available disk space
    available_space=$(df "$BACKUP_BASE" | awk 'NR==2{print $4}')
    available_gb=$((available_space / 1024 / 1024))
    
    if [[ $available_gb -lt 5 ]]; then
        log "✗ Low disk space: ${available_gb}GB available"
        return 1
    elif [[ $available_gb -lt 10 ]]; then
        log "⚠ Disk space getting low: ${available_gb}GB available"
    else
        log "✓ Sufficient disk space: ${available_gb}GB available"
    fi
    
    log "Backup health check completed"
}

if ! check_backup_health; then
    log "Backup health check failed - manual attention required"
    exit 1
fi
EOF

    chmod +x /usr/local/bin/backup-monitor
    
    log "${GREEN}✓ Backup monitoring script created${NC}"
}

# Setup backup automation
setup_backup_automation() {
    log "${BLUE}Setting up backup automation...${NC}"
    
    # Daily backup service
    cat > /etc/systemd/system/network-upgrade-daily-backup.service << 'EOF'
[Unit]
Description=Network Upgrade System Daily Backup
Documentation=man:network-upgrade-backup(8)

[Service]
Type=oneshot
User=network-upgrade
Group=network-upgrade
ExecStart=/usr/local/bin/network-upgrade-backup daily
StandardOutput=journal
StandardError=journal

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/backups/network-upgrade /var/log/network-upgrade /opt/network-upgrade /etc/ssl
EOF

    # Daily backup timer
    cat > /etc/systemd/system/network-upgrade-daily-backup.timer << 'EOF'
[Unit]
Description=Network Upgrade System Daily Backup Timer
Documentation=man:network-upgrade-backup(8)

[Timer]
OnCalendar=daily
RandomizedDelaySec=3600
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Weekly backup service
    cat > /etc/systemd/system/network-upgrade-weekly-backup.service << 'EOF'
[Unit]
Description=Network Upgrade System Weekly Backup
Documentation=man:network-upgrade-backup(8)

[Service]
Type=oneshot
User=network-upgrade
Group=network-upgrade
ExecStart=/usr/local/bin/network-upgrade-backup weekly
StandardOutput=journal
StandardError=journal

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/backups/network-upgrade /var/log/network-upgrade /opt/network-upgrade /etc/ssl
EOF

    # Weekly backup timer
    cat > /etc/systemd/system/network-upgrade-weekly-backup.timer << 'EOF'
[Unit]
Description=Network Upgrade System Weekly Backup Timer
Documentation=man:network-upgrade-backup(8)

[Timer]
OnCalendar=weekly
RandomizedDelaySec=7200
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Monthly backup service
    cat > /etc/systemd/system/network-upgrade-monthly-backup.service << 'EOF'
[Unit]
Description=Network Upgrade System Monthly Backup
Documentation=man:network-upgrade-backup(8)

[Service]
Type=oneshot
User=network-upgrade
Group=network-upgrade
ExecStart=/usr/local/bin/network-upgrade-backup monthly
StandardOutput=journal
StandardError=journal

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/backups/network-upgrade /var/log/network-upgrade /opt/network-upgrade /etc/ssl
EOF

    # Monthly backup timer
    cat > /etc/systemd/system/network-upgrade-monthly-backup.timer << 'EOF'
[Unit]
Description=Network Upgrade System Monthly Backup Timer
Documentation=man:network-upgrade-backup(8)

[Timer]
OnCalendar=monthly
RandomizedDelaySec=14400
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Backup monitoring service
    cat > /etc/systemd/system/backup-monitor.service << 'EOF'
[Unit]
Description=Backup Health Monitoring
Documentation=man:backup-monitor(8)

[Service]
Type=oneshot
ExecStart=/usr/local/bin/backup-monitor
StandardOutput=journal
StandardError=journal
EOF

    # Backup monitoring timer (daily)
    cat > /etc/systemd/system/backup-monitor.timer << 'EOF'
[Unit]
Description=Backup Health Monitoring Timer
Documentation=man:backup-monitor(8)

[Timer]
OnCalendar=daily
RandomizedDelaySec=1800
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Enable all backup timers
    systemctl daemon-reload
    systemctl enable network-upgrade-daily-backup.timer
    systemctl enable network-upgrade-weekly-backup.timer
    systemctl enable network-upgrade-monthly-backup.timer
    systemctl enable backup-monitor.timer
    
    systemctl start network-upgrade-daily-backup.timer
    systemctl start network-upgrade-weekly-backup.timer
    systemctl start network-upgrade-monthly-backup.timer
    systemctl start backup-monitor.timer
    
    log "${GREEN}✓ Backup automation configured and enabled${NC}"
}

# Create disaster recovery documentation
create_disaster_recovery_docs() {
    log "${BLUE}Creating disaster recovery documentation...${NC}"
    
    cat > "${BACKUP_BASE_DIR}/DISASTER_RECOVERY.md" << 'EOF'
# Network Device Upgrade System - Disaster Recovery Guide

## Overview

This document provides step-by-step procedures for recovering the Network Device Upgrade Management System from various failure scenarios.

## Backup Types

### Daily Backups
- **Frequency**: Every day at random time
- **Retention**: 7 days
- **Contents**: Configurations + Databases
- **Use Case**: Quick recovery from configuration issues

### Weekly Backups  
- **Frequency**: Weekly
- **Retention**: 4 weeks
- **Contents**: Configs + Databases + Logs + System State
- **Use Case**: Recovery from system changes or updates

### Monthly Backups
- **Frequency**: Monthly
- **Retention**: 12 months  
- **Contents**: Full system backup including Ansible content
- **Use Case**: Complete system rebuild

## Recovery Scenarios

### Scenario 1: Database Corruption

**Symptoms**: Web interfaces not loading, database errors in logs

**Recovery Steps**:
1. Stop services: `network-upgrade-services stop`
2. Find recent database backup: `ls /var/backups/network-upgrade/daily/`
3. Extract backup: `network-upgrade-backup restore`
4. Restore database files to original locations
5. Start services: `network-upgrade-services start`
6. Verify functionality

### Scenario 2: Configuration File Loss

**Symptoms**: Services fail to start, configuration errors

**Recovery Steps**:
1. Extract recent backup with configurations
2. Copy configuration files from backup to original locations:
   - `/etc/network-upgrade/`
   - `/opt/network-upgrade/awx/config/`
   - `/opt/network-upgrade/netbox/config/`
3. Reload services: `network-upgrade-services restart`

### Scenario 3: SSL Certificate Issues

**Symptoms**: HTTPS access fails, certificate expired

**Recovery Steps**:
1. Check certificate status: `/usr/local/bin/validate-ssl-cert`
2. If expired, renew: `/usr/local/bin/renew-ssl-cert` (Let's Encrypt)
3. Or restore from backup: Extract SSL certificates from backup
4. Reload nginx: `systemctl reload nginx`

### Scenario 4: Complete System Failure

**Symptoms**: Server hardware failure, OS corruption

**Recovery Steps**:
1. Install fresh OS on new/repaired hardware
2. Install base system: `./install/install-system.sh`
3. Extract latest monthly backup
4. Restore all configuration files
5. Restore databases
6. Install and configure services:
   - `./install/install-awx.sh`
   - `./install/install-netbox.sh`
   - `./install/configure-telegraf.sh`
7. Start services: `network-upgrade-services start`
8. Verify all functionality

### Scenario 5: Service-Specific Failures

#### AWX Service Issues
1. Check service status: `systemctl status awx-web awx-task awx-scheduler`
2. Check logs: `journalctl -u awx-web -n 50`
3. Restart services: `systemctl restart awx-web awx-task awx-scheduler`
4. If database issues, restore AWX database from backup

#### NetBox Service Issues
1. Check service status: `systemctl status netbox netbox-rq`
2. Check logs: `journalctl -u netbox -n 50`
3. Restart services: `systemctl restart netbox netbox-rq`
4. If database issues, restore NetBox database from backup

#### Redis Issues
1. Check Redis status: `systemctl status redis`
2. Test connectivity: `redis-cli -a ChangeMeInProduction123! ping`
3. Check memory usage: `redis-cli -a ChangeMeInProduction123! info memory`
4. Restart if needed: `systemctl restart redis`

## Recovery Testing

### Monthly Recovery Tests
Perform these tests monthly to ensure backup integrity:

1. **Configuration Recovery Test**
   - Extract recent configuration backup
   - Verify all config files are present
   - Check file integrity and permissions

2. **Database Recovery Test**
   - Create test environment
   - Restore database from backup
   - Verify data integrity

3. **Complete System Recovery Test** (Quarterly)
   - Use test environment or VM
   - Perform complete system recovery from backup
   - Document time required and any issues

## Backup Monitoring

### Daily Checks
- Verify backup completion: `backup-monitor`
- Check disk space: `df -h /var/backups/network-upgrade`
- Review backup logs: `tail -f /var/log/network-upgrade/backup.log`

### Weekly Checks
- Verify backup file integrity
- Test restore process on sample files
- Update disaster recovery procedures if needed

## Emergency Contacts

Document your emergency contacts here:

- **System Administrator**: [Name/Phone/Email]
- **Network Team**: [Contact Info]
- **Vendor Support**: [Contact Info if applicable]

## Recovery Time Objectives (RTO)

- **Database corruption**: 30 minutes
- **Configuration loss**: 15 minutes
- **SSL certificate issues**: 10 minutes
- **Complete system failure**: 4-6 hours
- **Service-specific failures**: 15-30 minutes

## Recovery Point Objectives (RPO)

- **Daily backups**: Maximum 24 hours of data loss
- **Weekly backups**: Maximum 7 days of data loss
- **Monthly backups**: Maximum 30 days of data loss

## Post-Recovery Validation

After any recovery operation, verify:

1. **Web Interface Access**
   - AWX: https://localhost:8443/
   - NetBox: https://localhost:8000/

2. **Service Status**
   - Run: `network-upgrade-services status`
   - All services should be "active"

3. **Database Connectivity**
   - Log into web interfaces
   - Verify data is accessible

4. **SSL Certificates**
   - Run: `/usr/local/bin/validate-ssl-cert`
   - Verify certificates are valid

5. **System Health**
   - Run: `/usr/local/bin/network-upgrade-health-full`
   - Address any warnings or errors

## Maintenance

- Review and update this document quarterly
- Test recovery procedures monthly
- Update backup retention policies as needed
- Monitor backup storage capacity

---

*Document Version: 1.0*  
*Last Updated: $(date)*
*Contact: Network Operations Team*
EOF

    chmod 644 "${BACKUP_BASE_DIR}/DISASTER_RECOVERY.md"
    chown network-upgrade:network-upgrade "${BACKUP_BASE_DIR}/DISASTER_RECOVERY.md"
    
    log "${GREEN}✓ Disaster recovery documentation created${NC}"
}

# Main backup setup function
main() {
    log "${GREEN}Starting backup and recovery setup...${NC}"
    log "${BLUE}Setup started at: $(date)${NC}"
    
    create_backup_directories
    create_backup_script
    create_backup_monitor
    setup_backup_automation
    create_disaster_recovery_docs
    
    # Create initial backup
    log "Creating initial system backup..."
    /usr/local/bin/network-upgrade-backup manual
    
    log "${GREEN}✓ Backup and recovery setup completed successfully!${NC}"
    log "${BLUE}Setup finished at: $(date)${NC}"
    
    echo ""
    log "${YELLOW}Backup and Recovery Setup Summary:${NC}"
    log "• Backup directory: ${BACKUP_BASE_DIR}"
    log "• Main script: /usr/local/bin/network-upgrade-backup"
    log "• Monitoring: /usr/local/bin/backup-monitor"
    log "• Disaster recovery guide: ${BACKUP_BASE_DIR}/DISASTER_RECOVERY.md"
    log ""
    log "${YELLOW}Automated Backups:${NC}"
    log "• Daily: Configurations + Databases (7 day retention)"
    log "• Weekly: Full backup with logs (4 week retention)"
    log "• Monthly: Complete system backup (12 month retention)"
    log ""
    log "${YELLOW}Manual Commands:${NC}"
    log "• Create backup: network-upgrade-backup {daily|weekly|monthly|manual}"
    log "• Restore wizard: network-upgrade-backup restore"
    log "• Monitor health: backup-monitor"
    log ""
    log "${YELLOW}Backup Types Available:${NC}"
    log "• daily - Quick daily backup (configs + databases)"
    log "• weekly - Weekly backup with logs and system state" 
    log "• monthly - Full system backup including Ansible content"
    log "• manual - On-demand backup with custom retention"
    log "• system - System configuration only"
    log "• database - Database backup only"
    log "• config - Configuration files only"
    log ""
    log "${YELLOW}Next Steps:${NC}"
    log "1. Review disaster recovery guide: ${BACKUP_BASE_DIR}/DISASTER_RECOVERY.md"
    log "2. Test backup restore procedure in development environment"
    log "3. Configure off-site backup storage if required"
    log "4. Schedule quarterly disaster recovery tests"
}

# Run main function
main "$@"