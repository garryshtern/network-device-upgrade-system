# Deployment Directory Structure

This directory contains all deployment-related files organized by service for the Network Device Upgrade Management System.

## 📁 Directory Organization

### `system/` - Base System Setup
- **`setup-system.sh`** - Core system configuration and dependencies
- **`setup-ssl.sh`** - SSL certificate configuration
- **`configs/`** - System-level configuration files

### `services/` - Service-Specific Deployments

#### `services/awx/` - AWX Automation Platform
- **`setup-awx.sh`** - AWX installation and configuration
- **`job-templates.yml`** - AWX job template definitions
- **`workflow-templates.yml`** - AWX workflow template definitions
- **`inventories.yml`** - AWX inventory configurations
- **`job-templates/`** - Individual job template files

#### `services/netbox/` - NetBox IPAM & DCIM
- **`setup-netbox.sh`** - NetBox installation and configuration
- **`dynamic-inventory.py`** - Ansible dynamic inventory script
- **`sync-scripts/`** - Device and firmware synchronization scripts

#### `services/grafana/` - Visualization & Dashboards
- **`deploy-to-environment.sh`** - Environment-specific deployment
- **`dashboards/`** - Grafana dashboard JSON definitions
- **`config-templates/`** - Environment configuration templates
- **`provision-dashboards.sh`** - Dashboard provisioning automation

#### `services/telegraf/` - Metrics Collection
- **`configure-telegraf.sh`** - Telegraf setup and configuration
- **`telegraf.conf`** - Telegraf configuration file

#### `services/redis/` - Caching & Job Queue
- **`configure-redis.sh`** - Redis installation and configuration

### `scripts/` - General Deployment Scripts
- **`create-services.sh`** - Service creation and management
- **`backup-scripts.sh`** - System backup automation
- **`health-check.sh`** - System health monitoring
- **`metrics-export.sh`** - Metrics export utilities

## 🚀 Deployment Order

1. **System Setup**: Run `system/setup-system.sh` and `system/setup-ssl.sh`
2. **Core Services**: Deploy Redis, NetBox, and Telegraf
3. **Automation Platform**: Deploy AWX with job templates
4. **Monitoring**: Deploy Grafana dashboards and configure metrics
5. **Integration**: Configure service integrations and dynamic inventory

## 🔧 Service Dependencies

```
setup-system.sh
├── redis/configure-redis.sh
├── netbox/setup-netbox.sh
│   └── netbox/sync-scripts/
├── telegraf/configure-telegraf.sh
├── awx/setup-awx.sh
│   ├── awx/job-templates.yml
│   ├── awx/workflow-templates.yml
│   └── awx/inventories.yml
└── grafana/deploy-to-environment.sh
    └── grafana/dashboards/
```

## 📖 Usage

Each service directory is self-contained with its setup script and all related configuration files. This organization makes it easy to:

- **Deploy individual services** independently
- **Understand service dependencies** at a glance
- **Maintain and update** specific components
- **Scale deployment** to different environments

For detailed deployment instructions, see the main project documentation.