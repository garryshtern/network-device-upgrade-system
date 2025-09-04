#!/bin/bash

# Redis Configuration Script for Network Upgrade System
# Optimized configuration for AWX and NetBox job queuing

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_FILE="/var/log/network-upgrade/redis-config.log"

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

# Optimize Redis configuration
optimize_redis_config() {
    log "${BLUE}Optimizing Redis configuration for network upgrade system...${NC}"
    
    # Backup original configuration
    cp /etc/redis/redis.conf /etc/redis/redis.conf.backup-$(date +%Y%m%d_%H%M%S)
    
    # Create optimized Redis configuration
    cat > /etc/redis/redis.conf << 'EOF'
# Redis Configuration for Network Device Upgrade Management System
# Optimized for AWX and NetBox with multiple database separation

################################## NETWORK ###################################

# Accept connections on localhost only for security
bind 127.0.0.1

# Port configuration
port 6379

# TCP listen backlog
tcp-backlog 511

# Close connection after client is idle for N seconds (0 to disable)
timeout 0

# TCP keepalive
tcp-keepalive 300

################################# TLS/SSL ####################################

# Uncomment and configure for SSL/TLS if needed
# tls-port 6380
# tls-cert-file /etc/ssl/certs/redis.crt
# tls-key-file /etc/ssl/private/redis.key

################################# GENERAL #####################################

# Run as daemon
daemonize yes

# PID file
pidfile /var/run/redis/redis-server.pid

# Log level (debug, verbose, notice, warning)
loglevel notice

# Log file
logfile /var/log/redis/redis-server.log

# Number of databases (0-15)
databases 16

# Always show logo
always-show-logo yes

################################ SNAPSHOTTING  ################################

# Save snapshots for persistence
save 900 1    # Save if at least 1 key changed in 900 seconds
save 300 10   # Save if at least 10 keys changed in 300 seconds
save 60 10000 # Save if at least 10000 keys changed in 60 seconds

# Stop accepting writes if RDB snapshots failed
stop-writes-on-bgsave-error yes

# Compress RDB files
rdbcompression yes

# Checksum RDB files
rdbchecksum yes

# RDB filename
dbfilename network-upgrade-redis.rdb

# Working directory for dump files
dir /var/lib/redis

################################# REPLICATION #################################

# Master authentication (not needed for single server)
# masterauth <master-password>

# Replica authentication (not needed for single server)  
# requirepass <password>

################################## SECURITY ###################################

# Require password for all connections
requirepass ChangeMeInProduction123!

# Command renaming for security (uncomment if needed)
# rename-command FLUSHDB ""
# rename-command FLUSHALL ""
# rename-command KEYS ""
# rename-command CONFIG "CONFIG_b835d59d7b8c4f2a9e"

################################### LIMITS ####################################

# Max connected clients
maxclients 1000

# Memory limit (adjust based on available system memory)
maxmemory 2gb

# Memory eviction policy when maxmemory is reached
maxmemory-policy allkeys-lru

# Memory sampling for LRU/LFU algorithms
maxmemory-samples 5

############################# LAZY FREEING ####################################

# Delete keys asynchronously in background
lazyfree-lazy-eviction yes
lazyfree-lazy-expire yes
lazyfree-lazy-server-del yes

############################ KERNEL OOM CONTROL ##############################

# OOM score adjustment for Redis process
oom-score-adj no

#################### KERNEL TRANSPARENT HUGEPAGE CONTROL ######################

# Disable transparent huge pages (recommended)
disable-thp yes

############################## APPEND ONLY FILE ###############################

# Enable AOF persistence for better durability
appendonly yes

# AOF filename
appendfilename "network-upgrade-redis.aof"

# AOF sync policy
appendfsync everysec

# Rewrite AOF when it grows by this percentage
auto-aof-rewrite-percentage 100

# Minimum AOF file size to trigger rewrite
auto-aof-rewrite-min-size 64mb

# Load truncated AOF file on startup
aof-load-truncated yes

# Use RDB-AOF hybrid persistence
aof-use-rdb-preamble yes

################################ LUA SCRIPTING  ###############################

# Max execution time for Lua scripts (milliseconds)
lua-time-limit 5000

################################## SLOW LOG ###################################

# Log queries slower than this many microseconds
slowlog-log-slower-than 10000

# Maximum length of slow log
slowlog-max-len 128

################################ LATENCY MONITOR ##############################

# Latency monitoring (0 disables it)
latency-monitor-threshold 100

############################# EVENT NOTIFICATION ##############################

# Enable keyspace notifications for expired events (useful for job timeouts)
notify-keyspace-events "Ex"

############################### ADVANCED CONFIG ###############################

# Hash table parameters
hash-max-ziplist-entries 512
hash-max-ziplist-value 64

# List parameters
list-max-ziplist-size -2
list-compress-depth 0

# Set parameters
set-max-intset-entries 512

# Sorted set parameters
zset-max-ziplist-entries 128
zset-max-ziplist-value 64

# HyperLogLog sparse representation settings
hll-sparse-max-bytes 3000

# Stream parameters
stream-node-max-bytes 4096
stream-node-max-entries 100

# Active rehashing
activerehashing yes

# Client output buffer limits
client-output-buffer-limit normal 0 0 0
client-output-buffer-limit replica 256mb 64mb 60
client-output-buffer-limit pubsub 32mb 8mb 60

# Client query buffer limit
client-query-buffer-limit 1gb

# Client query buffer hard limit
proto-max-bulk-len 512mb

# Frequency of background tasks
hz 10

# Enable dynamic HZ
dynamic-hz yes

# AOF rewrite incremental fsync
aof-rewrite-incremental-fsync yes

# RDB save incremental fsync  
rdb-save-incremental-fsync yes

# Jemalloc background thread enabled
jemalloc-bg-thread yes

# EOF
EOF

    # Set proper permissions
    chown redis:redis /etc/redis/redis.conf
    chmod 640 /etc/redis/redis.conf
    
    # Create Redis log directory if it doesn't exist
    mkdir -p /var/log/redis
    chown redis:redis /var/log/redis
    chmod 755 /var/log/redis
    
    log "${GREEN}✓ Redis configuration optimized${NC}"
}

# Configure Redis for different services
configure_redis_databases() {
    log "${BLUE}Configuring Redis database allocation...${NC}"
    
    # Create Redis database allocation documentation
    cat > /etc/redis/database_allocation.md << 'EOF'
# Redis Database Allocation for Network Upgrade System

## Database Usage Map

- **Database 0**: General system cache and session storage
- **Database 1**: AWX web application cache and sessions  
- **Database 2**: AWX Celery broker and task results
- **Database 3**: NetBox task queue (RQ)
- **Database 4**: NetBox application cache
- **Database 5**: Network upgrade progress tracking
- **Database 6**: Metrics and monitoring temporary storage
- **Database 7**: Reserved for future use
- **Database 8**: Job scheduling and coordination
- **Database 9**: Device state caching
- **Database 10**: Configuration backup tracking
- **Database 11**: Alert and notification queue
- **Database 12-15**: Reserved for future expansion

## Performance Considerations

- Databases 1-4 are high-frequency (AWX/NetBox)
- Database 5 is medium-frequency (upgrade tracking)
- Databases 6-11 are low-frequency (monitoring/misc)

## Memory Usage Monitoring

Monitor memory usage per database with:
```bash
redis-cli -a ChangeMeInProduction123! INFO memory
redis-cli -a ChangeMeInProduction123! MEMORY usage <key>
```

## Backup Strategy

- RDB snapshots: Every 15 minutes if 1+ keys changed
- AOF: Append-only file for durability
- Manual backups: Use BGSAVE command during maintenance windows
EOF
    
    chown network-upgrade:network-upgrade /etc/redis/database_allocation.md
    chmod 644 /etc/redis/database_allocation.md
    
    log "${GREEN}✓ Redis database allocation documented${NC}"
}

# Configure Redis monitoring
configure_redis_monitoring() {
    log "${BLUE}Configuring Redis monitoring...${NC}"
    
    # Create Redis monitoring script
    cat > /usr/local/bin/redis-monitor << 'EOF'
#!/bin/bash
# Redis Health Monitoring Script for Network Upgrade System

REDIS_PASSWORD="ChangeMeInProduction123!"
REDIS_CLI="/usr/bin/redis-cli"

echo "=== Redis Health Monitor - $(date) ==="
echo ""

# Test basic connectivity
echo "=== Connection Test ==="
if $REDIS_CLI -a "$REDIS_PASSWORD" ping &>/dev/null; then
    echo "✓ Redis is responding to PING"
else
    echo "✗ Redis connection failed"
    exit 1
fi
echo ""

# Memory usage
echo "=== Memory Usage ==="
MEMORY_INFO=$($REDIS_CLI -a "$REDIS_PASSWORD" INFO memory)
USED_MEMORY=$(echo "$MEMORY_INFO" | grep "used_memory_human:" | cut -d: -f2 | tr -d '\r')
MAX_MEMORY=$(echo "$MEMORY_INFO" | grep "maxmemory_human:" | cut -d: -f2 | tr -d '\r')
echo "Used Memory: $USED_MEMORY"
echo "Max Memory: $MAX_MEMORY"
echo ""

# Database statistics
echo "=== Database Statistics ==="
for db in {0..15}; do
    KEYS_COUNT=$($REDIS_CLI -a "$REDIS_PASSWORD" -n $db DBSIZE 2>/dev/null)
    if [[ $KEYS_COUNT -gt 0 ]]; then
        echo "Database $db: $KEYS_COUNT keys"
    fi
done
echo ""

# Connection statistics
echo "=== Connection Statistics ==="
CLIENTS_INFO=$($REDIS_CLI -a "$REDIS_PASSWORD" INFO clients)
CONNECTED_CLIENTS=$(echo "$CLIENTS_INFO" | grep "connected_clients:" | cut -d: -f2 | tr -d '\r')
echo "Connected Clients: $CONNECTED_CLIENTS"
echo ""

# Performance statistics
echo "=== Performance Statistics ==="
STATS_INFO=$($REDIS_CLI -a "$REDIS_PASSWORD" INFO stats)
TOTAL_COMMANDS=$(echo "$STATS_INFO" | grep "total_commands_processed:" | cut -d: -f2 | tr -d '\r')
OPS_PER_SEC=$(echo "$STATS_INFO" | grep "instantaneous_ops_per_sec:" | cut -d: -f2 | tr -d '\r')
echo "Total Commands: $TOTAL_COMMANDS"
echo "Operations/sec: $OPS_PER_SEC"
echo ""

# Slow log
echo "=== Recent Slow Queries ==="
SLOW_COUNT=$($REDIS_CLI -a "$REDIS_PASSWORD" SLOWLOG LEN)
if [[ $SLOW_COUNT -gt 0 ]]; then
    echo "Slow queries found: $SLOW_COUNT"
    $REDIS_CLI -a "$REDIS_PASSWORD" SLOWLOG GET 5
else
    echo "No slow queries logged"
fi
echo ""

# Keyspace events
echo "=== Recent Keyspace Events ==="
echo "Expired keys in last minute:"
$REDIS_CLI -a "$REDIS_PASSWORD" --latency-history -i 1 | head -5
echo ""

echo "=== Redis Health Check Complete ==="
EOF
    
    chmod +x /usr/local/bin/redis-monitor
    
    # Create systemd timer for regular monitoring
    cat > /etc/systemd/system/redis-monitor.service << 'EOF'
[Unit]
Description=Redis Health Monitor
Documentation=man:redis-cli(1)

[Service]
Type=oneshot
ExecStart=/usr/local/bin/redis-monitor
StandardOutput=append:/var/log/redis/redis-monitor.log
StandardError=append:/var/log/redis/redis-monitor.log
User=redis
Group=redis
EOF

    cat > /etc/systemd/system/redis-monitor.timer << 'EOF'
[Unit]
Description=Run Redis Health Monitor every 15 minutes
Documentation=man:redis-cli(1)

[Timer]
OnCalendar=*:0/15
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Enable the monitoring timer
    systemctl daemon-reload
    systemctl enable redis-monitor.timer
    systemctl start redis-monitor.timer
    
    log "${GREEN}✓ Redis monitoring configured${NC}"
}

# Configure Redis security
configure_redis_security() {
    log "${BLUE}Configuring Redis security settings...${NC}"
    
    # Create Redis security script
    cat > /usr/local/bin/redis-security-check << 'EOF'
#!/bin/bash
# Redis Security Configuration Check

REDIS_CONF="/etc/redis/redis.conf"

echo "=== Redis Security Configuration Check ==="
echo ""

# Check bind address
BIND_ADDRESS=$(grep "^bind " "$REDIS_CONF" | head -1)
if [[ "$BIND_ADDRESS" == "bind 127.0.0.1" ]]; then
    echo "✓ Redis is bound to localhost only"
else
    echo "⚠ WARNING: Redis may be accepting external connections"
    echo "  Current setting: $BIND_ADDRESS"
fi

# Check authentication
if grep -q "^requirepass " "$REDIS_CONF"; then
    echo "✓ Redis authentication is enabled"
else
    echo "✗ WARNING: Redis authentication is not configured"
fi

# Check dangerous commands
DANGEROUS_COMMANDS=("FLUSHDB" "FLUSHALL" "KEYS" "CONFIG" "DEBUG" "EVAL" "SHUTDOWN")
for cmd in "${DANGEROUS_COMMANDS[@]}"; do
    if grep -q "rename-command $cmd" "$REDIS_CONF"; then
        echo "✓ Dangerous command $cmd is disabled/renamed"
    else
        echo "⚠ Command $cmd is available (consider disabling in production)"
    fi
done

# Check file permissions
REDIS_CONF_PERMS=$(stat -c %a "$REDIS_CONF")
if [[ "$REDIS_CONF_PERMS" == "640" ]]; then
    echo "✓ Redis configuration file has secure permissions (640)"
else
    echo "⚠ Redis configuration file permissions: $REDIS_CONF_PERMS (recommend 640)"
fi

# Check if Redis is running as non-root
REDIS_USER=$(ps -eo user,comm | grep redis-server | awk '{print $1}' | head -1)
if [[ "$REDIS_USER" == "redis" ]]; then
    echo "✓ Redis is running as redis user"
else
    echo "⚠ Redis is running as: $REDIS_USER (should be redis)"
fi

echo ""
echo "=== Security Check Complete ==="
EOF
    
    chmod +x /usr/local/bin/redis-security-check
    
    log "${GREEN}✓ Redis security configuration completed${NC}"
}

# Test Redis configuration
test_redis_configuration() {
    log "${BLUE}Testing Redis configuration...${NC}"
    
    # Stop Redis if running
    systemctl stop redis || true
    
    # Test configuration file syntax
    if redis-server /etc/redis/redis.conf --test-memory 1024; then
        log "${GREEN}✓ Redis configuration syntax is valid${NC}"
    else
        error_exit "Redis configuration test failed"
    fi
    
    # Start Redis service
    systemctl start redis
    sleep 3
    
    # Test basic functionality
    if redis-cli -a "ChangeMeInProduction123!" ping | grep -q "PONG"; then
        log "${GREEN}✓ Redis is responding to commands${NC}"
    else
        error_exit "Redis is not responding correctly"
    fi
    
    # Test different databases
    for db in 0 1 2 3 4; do
        if redis-cli -a "ChangeMeInProduction123!" -n $db SET "test_key_$db" "test_value" > /dev/null; then
            redis-cli -a "ChangeMeInProduction123!" -n $db DEL "test_key_$db" > /dev/null
        else
            log "${YELLOW}⚠ Warning: Could not test database $db${NC}"
        fi
    done
    
    log "${GREEN}✓ Redis database tests completed${NC}"
}

# Configure log rotation for Redis
configure_redis_logrotation() {
    log "${BLUE}Configuring Redis log rotation...${NC}"
    
    cat > /etc/logrotate.d/redis-server << 'EOF'
/var/log/redis/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 640 redis redis
    sharedscripts
    postrotate
        if [ -f /var/run/redis/redis-server.pid ]; then
            kill -USR1 $(cat /var/run/redis/redis-server.pid)
        fi
    endscript
}
EOF
    
    log "${GREEN}✓ Redis log rotation configured${NC}"
}

# Main configuration function
main() {
    log "${GREEN}Starting Redis configuration for Network Upgrade System...${NC}"
    log "${BLUE}Configuration started at: $(date)${NC}"
    
    optimize_redis_config
    configure_redis_databases
    configure_redis_monitoring
    configure_redis_security
    test_redis_configuration
    configure_redis_logrotation
    
    # Enable Redis service
    systemctl enable redis
    
    log "${GREEN}✓ Redis configuration completed successfully!${NC}"
    log "${BLUE}Configuration finished at: $(date)${NC}"
    
    echo ""
    log "${YELLOW}Redis Configuration Summary:${NC}"
    log "• Configuration file: /etc/redis/redis.conf"
    log "• Database allocation: /etc/redis/database_allocation.md"
    log "• Log files: /var/log/redis/"
    log "• Monitoring script: /usr/local/bin/redis-monitor"
    log "• Security check: /usr/local/bin/redis-security-check"
    log "• Password: ChangeMeInProduction123! (CHANGE IN PRODUCTION!)"
    log ""
    log "${YELLOW}Database Allocation:${NC}"
    log "• DB 0: General system cache"
    log "• DB 1: AWX web cache"
    log "• DB 2: AWX Celery tasks"
    log "• DB 3: NetBox RQ tasks"
    log "• DB 4: NetBox cache"
    log "• DB 5: Upgrade progress"
    log ""
    log "${YELLOW}Monitoring:${NC}"
    log "• Health checks run every 15 minutes"
    log "• Logs rotated daily (30 days retention)"
    log "• Performance monitoring enabled"
    log ""
    log "${YELLOW}Next steps:${NC}"
    log "1. CHANGE THE DEFAULT PASSWORD in production!"
    log "2. Review security settings with: /usr/local/bin/redis-security-check"
    log "3. Monitor performance with: /usr/local/bin/redis-monitor"
    log "4. Configure backup strategy for RDB files"
}

# Run main function
main "$@"