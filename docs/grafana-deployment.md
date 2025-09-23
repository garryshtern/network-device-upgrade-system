# Grafana Integration - Network Device Upgrade Management System

This directory contains Grafana dashboard configuration and provisioning automation for the Network Device Upgrade Management System.

## Overview

The Grafana integration provides comprehensive monitoring and visualization for network device upgrades across 1000+ heterogeneous devices. The system includes automated dashboard provisioning, real-time operational monitoring, and platform-specific metrics collection.

## Directory Structure

```
integration/grafana/
├── dashboards/                    # Dashboard JSON definitions
│   ├── network-upgrade-overview.json     # Main system overview
│   ├── platform-specific-metrics.json   # Platform-focused monitoring  
│   └── real-time-operations.json        # Live operational dashboard
├── provision-dashboards.sh       # Automated provisioning script
└── README.md                     # This file
```

## Dashboard Descriptions

### 1. Network Upgrade Overview
**File**: `dashboards/network-upgrade-overview.json`
- **Purpose**: Executive dashboard providing high-level system metrics
- **Key Metrics**: Device compliance, upgrade success rates, system health
- **Panels**: 
  - System status overview table
  - Device compliance pie chart
  - Upgrade success rate timeline
  - Error distribution analysis
- **Update Frequency**: 1 minute refresh
- **Target Audience**: Network operations managers, executives

### 2. Platform-Specific Metrics
**File**: `dashboards/platform-specific-metrics.json`
- **Purpose**: Detailed monitoring of platform-specific components
- **Key Focus**: Multi-architecture Opengear support, Cisco validation suites
- **Panels**:
  - Opengear architecture distribution (Legacy CLI vs Modern API)
  - Model-specific performance metrics
  - Cisco BFD session health monitoring
  - IPSec tunnel status validation
  - Interface optics monitoring
- **Update Frequency**: 30 seconds refresh
- **Target Audience**: Platform engineers, technical operations

### 3. Real-Time Operations
**File**: `dashboards/real-time-operations.json`
- **Purpose**: Live monitoring of active upgrade operations
- **Key Features**: Real-time progress tracking, failure detection
- **Panels**:
  - Active upgrade progress bars
  - Device state transition monitoring
  - Failure rate alerts
  - Queue depth analysis
- **Update Frequency**: 15 seconds refresh (real-time)
- **Target Audience**: NOC operators, on-call engineers

## Prerequisites

### Required Software
- **curl**: HTTP client for API calls
- **jq**: JSON processor for response parsing
- **Grafana**: Version 8.0+ with API access
- **InfluxDB**: Version 2.0+ with token authentication

### Required Services
- **Grafana**: Running and accessible at configured URL
- **InfluxDB v2**: Configured with organization and bucket
- **Network Access**: Connectivity between Grafana and InfluxDB

### Environment Variables
```bash
# Grafana Configuration
export GRAFANA_URL="http://localhost:3000"
export GRAFANA_ADMIN_USER="admin"
export GRAFANA_ADMIN_PASS="admin"

# InfluxDB Configuration
export INFLUXDB_URL="http://localhost:8086"
export INFLUXDB_TOKEN="your_influxdb_token_here"
export INFLUXDB_ORG="network-operations"
export INFLUXDB_BUCKET="network-upgrade-metrics"

# Optional: Slack Integration
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/your/webhook/url"
```

## Deployment

### Automated Deployment
Use the provided provisioning script for complete automated setup:

```bash
# Make script executable
chmod +x provision-dashboards.sh

# Set required environment variables
export INFLUXDB_TOKEN="your_token_here"

# Run provisioning
./provision-dashboards.sh
```

### Manual Deployment Steps

1. **Configure Data Source**:
   - Access Grafana UI → Configuration → Data Sources
   - Add new InfluxDB data source
   - Configure with InfluxDB v2 settings (Flux query language)

2. **Import Dashboards**:
   - Access Grafana UI → Create → Import
   - Upload each JSON file from `dashboards/` directory
   - Verify data source mapping

3. **Validate Configuration**:
   - Confirm all panels display data correctly
   - Test alert notifications if configured
   - Verify refresh intervals are appropriate

### Verification Steps

After deployment, verify the installation:

```bash
# Test Grafana connectivity
curl -s "$GRAFANA_URL/api/health"

# List deployed dashboards
curl -s -H "Authorization: Bearer $GRAFANA_API_KEY" \
     "$GRAFANA_URL/api/search?type=dash-db" | jq '.[].title'

# Test data source connectivity
curl -s -H "Authorization: Bearer $GRAFANA_API_KEY" \
     "$GRAFANA_URL/api/datasources" | jq '.[] | select(.name=="InfluxDB-NetworkUpgrade")'
```

## Configuration

### Data Source Configuration
The system automatically configures an InfluxDB v2 data source with the following settings:
- **Name**: InfluxDB-NetworkUpgrade
- **Type**: InfluxDB (Flux)
- **URL**: Configured via INFLUXDB_URL
- **Organization**: Configured via INFLUXDB_ORG
- **Default Bucket**: Configured via INFLUXDB_BUCKET
- **Authentication**: Token-based (secure)

### Alert Configuration
Optional Slack integration for upgrade failure notifications:
- **Channel**: #network-operations
- **Trigger Conditions**: Upgrade failures, device unreachable, validation errors
- **Notification Format**: Structured alerts with device details and error context

### Dashboard Customization
Each dashboard can be customized for your environment:
- **Time Ranges**: Adjust default time ranges in dashboard settings
- **Thresholds**: Modify alert thresholds for your network requirements
- **Refresh Intervals**: Adjust based on monitoring needs and system load
- **Panel Layout**: Reorganize panels to match operational workflows

## Troubleshooting

### Common Issues

**Authentication Failures**:
```bash
# Verify Grafana credentials
curl -u "$GRAFANA_ADMIN_USER:$GRAFANA_ADMIN_PASS" "$GRAFANA_URL/api/user"
```

**Data Source Connection Issues**:
```bash
# Test InfluxDB connectivity
curl -H "Authorization: Token $INFLUXDB_TOKEN" "$INFLUXDB_URL/health"
```

**Dashboard Import Failures**:
- Verify JSON syntax with `jq` validation
- Check data source name mapping
- Confirm Grafana version compatibility

**No Data in Panels**:
- Verify Telegraf is collecting metrics
- Check InfluxDB bucket name and organization
- Validate Flux query syntax

### Log Analysis
Monitor provisioning script logs:
```bash
# Run with verbose output
DEBUG=1 ./provision-dashboards.sh

# Check Grafana logs
docker logs grafana-container
```

## Maintenance

### Dashboard Updates
To update dashboards after modifications:

```bash
# Re-run provisioning (will overwrite existing)
./provision-dashboards.sh

# Or import manually via Grafana UI
```

### Data Retention
Configure InfluxDB retention policies:
```bash
# Set retention policy for metrics bucket
influx bucket update \
  --name network-upgrade-metrics \
  --retention 90d \
  --org network-operations
```

### Performance Optimization
- **Panel Count**: Limit panels per dashboard to maintain performance
- **Query Frequency**: Balance refresh rates with system load
- **Data Aggregation**: Use appropriate time grouping for historical data
- **Index Optimization**: Ensure proper InfluxDB indexing on tag keys

## Security Considerations

### Token Management
- Store InfluxDB tokens securely (environment variables, secret management)
- Use read-only tokens for Grafana data sources when possible
- Rotate tokens regularly according to security policies

### Network Security
- Configure TLS/SSL for Grafana and InfluxDB connections
- Implement network segmentation for monitoring infrastructure
- Use authentication proxies if required by security policies

### Access Control
- Configure Grafana user roles and permissions
- Implement dashboard folder permissions
- Audit dashboard access and modifications

## Integration with Main System

### Metrics Collection
The dashboards consume metrics generated by:
- **Telegraf**: Real-time device metrics collection
- **Ansible Playbooks**: Upgrade operation metrics
- **AWX**: Job execution statistics
- **Custom Exporters**: Platform-specific metrics

### Automated Workflow
Dashboard provisioning integrates with:
- **CI/CD Pipelines**: Automated deployment with infrastructure updates
- **Configuration Management**: Dashboard-as-code approach
- **Monitoring Stack**: Part of comprehensive observability solution

## Support

### Documentation References
- [Grafana API Documentation](https://grafana.com/docs/grafana/latest/http_api/)
- [InfluxDB v2 Documentation](https://docs.influxdata.com/influxdb/v2.0/)
- [Flux Query Language](https://docs.influxdata.com/flux/v0.x/)

### Monitoring Stack Architecture
This Grafana integration is part of the larger monitoring architecture described in:
- [Installation Guide](installation-guide.md) - System architecture overview
- [Workflow Architecture](workflow-architecture.md) - CI/CD and monitoring integration
- [Project Overview](../README.md) - Main project documentation

For system-wide issues, consult the main project documentation and issue tracking system.