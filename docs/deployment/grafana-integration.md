# Grafana Integration Guide

**Last Updated**: November 4, 2025

Complete guide for deploying and configuring Grafana dashboards for the Network Device Upgrade Management System.

## Overview

The Grafana integration provides comprehensive monitoring and visualization for network device upgrades across 1000+ heterogeneous devices. The system includes automated dashboard provisioning, real-time operational monitoring, and platform-specific metrics collection.

## Prerequisites

### Required Software
- **curl**: HTTP client for API calls
- **jq**: JSON processor for response parsing
- **Grafana**: Version 8.0+ with API access
- **InfluxDB v2**: Version 2.0+ with token authentication

### Required Services
- **Grafana**: Running and accessible at configured URL
- **InfluxDB v2**: Configured with organization and bucket
- **Network Access**: Connectivity between Grafana and InfluxDB

## Environment Setup

### Required Environment Variables
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

## Quick Start

### 1. Basic Deployment
```bash
cd integration/grafana/
chmod +x *.sh
./provision-dashboards.sh
```

### 2. Environment-Specific Deployment
```bash
# Development environment
./deploy-to-environment.sh development

# Production environment  
./deploy-to-environment.sh production

# Staging environment
./deploy-to-environment.sh staging
```

### 3. Validation
```bash
# Quick validation
./validate-deployment.sh --quick

# Comprehensive validation
./validate-deployment.sh --deep
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

## Deployment Scripts

### Core Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `provision-dashboards.sh` | Main provisioning automation | `./provision-dashboards.sh` |
| `deploy-to-environment.sh` | Environment-specific deployment | `./deploy-to-environment.sh [env]` |
| `validate-deployment.sh` | Deployment validation | `./validate-deployment.sh [options]` |

### Configuration Files

| File | Purpose | Environment |
|------|---------|-------------|
| `config-templates/development.env` | Development configuration | Local development |
| `config-templates/staging.env` | Staging configuration | Pre-production testing |
| `config-templates/production.env` | Production configuration | Live operations |

## Deployment Scenarios

### Scenario 1: First-Time Setup
```bash
# 1. Clone repository and navigate to Grafana integration
cd integration/grafana/

# 2. Set environment variables
export INFLUXDB_TOKEN="your_token"

# 3. Run initial deployment
./provision-dashboards.sh

# 4. Validate deployment
./validate-deployment.sh
```

### Scenario 2: Multi-Environment Setup
```bash
# 1. Configure environment-specific settings
cp config-templates/production.env config-templates/my-prod.env
# Edit my-prod.env with your settings

# 2. Deploy to production
./deploy-to-environment.sh production

# 3. Validate production deployment
GRAFANA_URL="https://grafana.prod.company.com" ./validate-deployment.sh --deep
```

### Scenario 3: Development Workflow
```bash
# 1. Quick development deployment
./deploy-to-environment.sh development

# 2. Test changes locally
# 3. Validate before promoting to staging
./validate-deployment.sh --quick
```

## Directory Structure

```
integration/grafana/
├── dashboards/                    # Dashboard JSON definitions
│   ├── network-upgrade-overview.json     # Main system overview
│   ├── platform-specific-metrics.json   # Platform-focused monitoring  
│   └── real-time-operations.json        # Live operational dashboard
├── config-templates/              # Environment configurations
│   ├── development.env
│   ├── staging.env
│   └── production.env
├── provision-dashboards.sh       # Automated provisioning script
├── deploy-to-environment.sh      # Environment-specific deployment
└── validate-deployment.sh        # Deployment validation
```

## Configuration

### InfluxDB Data Source
The dashboards require an InfluxDB v2 data source configured in Grafana:

- **Type**: InfluxDB (Flux)
- **URL**: `http://localhost:8086`
- **Organization**: `network-operations`
- **Token**: Your InfluxDB API token
- **Default Bucket**: `network-upgrade-metrics`

### Alert Notifications
Configure alert notifications in Grafana:

1. **Slack**: For real-time alerts
2. **Email**: For summary reports
3. **PagerDuty**: For critical failures

## Troubleshooting

### Dashboard Not Loading
```bash
# Check Grafana connectivity
curl -v $GRAFANA_URL/api/health

# Verify InfluxDB connection
curl -H "Authorization: Token $INFLUXDB_TOKEN" \
  $INFLUXDB_URL/api/v2/buckets
```

### No Data Displayed
- Verify InfluxDB bucket name matches configuration
- Check that metrics are being written by Ansible playbooks
- Confirm time range selector in dashboard

### Permission Errors
- Ensure Grafana API token has admin permissions
- Verify InfluxDB token has read access to bucket

## Advanced Configuration

### Custom Dashboards
To create custom dashboards:

1. Design dashboard in Grafana UI
2. Export JSON via Settings → JSON Model
3. Save to `dashboards/` directory
4. Update `provision-dashboards.sh` to include new dashboard

### Alert Thresholds
Customize alert thresholds in dashboard JSON:

```json
"alert": {
  "conditions": [
    {
      "evaluator": {
        "params": [90],
        "type": "gt"
      }
    }
  ]
}
```

## Related Documentation

- [Container Deployment Guide](../user-guides/container-deployment.md) - Deploy with Docker/Podman
- [Pre-Commit Setup](../testing/pre-commit-setup.md) - Quality assurance procedures
- [CLAUDE.md](../../CLAUDE.md) - Comprehensive project guide with configuration and troubleshooting
