# Grafana Dashboard Deployment Guide

## Quick Start

### 1. Environment Setup
```bash
# Set required environment variables
export INFLUXDB_TOKEN="your_influxdb_token_here"
export GRAFANA_URL="http://localhost:3000"
export GRAFANA_ADMIN_USER="admin"
export GRAFANA_ADMIN_PASS="admin"

# Optional: InfluxDB configuration
export INFLUXDB_URL="http://localhost:8086"
export INFLUXDB_ORG="network-operations"
export INFLUXDB_BUCKET="network-upgrade-metrics"
```

### 2. Basic Deployment
```bash
cd integration/grafana/
chmod +x *.sh
./provision-dashboards.sh
```

### 3. Environment-Specific Deployment
```bash
# Development environment
./deploy-to-environment.sh development

# Production environment  
./deploy-to-environment.sh production

# Staging environment
./deploy-to-environment.sh staging
```

### 4. Validation
```bash
# Quick validation
./validate-deployment.sh --quick

# Comprehensive validation
./validate-deployment.sh --deep
```

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

# 2. Test changes
./validate-deployment.sh --verbose

# 3. Redeploy after dashboard modifications
./deploy-to-environment.sh development --force
```

### Scenario 4: CI/CD Integration
```bash
#!/bin/bash
# Example CI/CD pipeline step

# Load environment-specific configuration
source config-templates/${DEPLOYMENT_ENV}.env

# Deploy dashboards
./deploy-to-environment.sh ${DEPLOYMENT_ENV} --force

# Validate deployment
./validate-deployment.sh --quick

# Report status
echo "Dashboard deployment completed for ${DEPLOYMENT_ENV}"
```

## Configuration Management

### Environment Variables
Core variables required for all deployments:
```bash
# Grafana
GRAFANA_URL="https://grafana.company.com"
GRAFANA_ADMIN_USER="admin"
GRAFANA_ADMIN_PASS="secure_password"

# InfluxDB  
INFLUXDB_URL="https://influxdb.company.com:8086"
INFLUXDB_TOKEN="your_access_token"
INFLUXDB_ORG="network-operations"
INFLUXDB_BUCKET="network-upgrade-metrics"
```

### Custom Configuration
Create custom configuration files:
```bash
# Copy template
cp config-templates/production.env config-templates/my-custom.env

# Edit configuration
vim config-templates/my-custom.env

# Deploy with custom configuration
./deploy-to-environment.sh custom --config-file config-templates/my-custom.env
```

### Security Configuration
For production deployments:
```bash
# Use secure secret management
export GRAFANA_ADMIN_PASS="$(cat /etc/secrets/grafana-password)"
export INFLUXDB_TOKEN="$(kubectl get secret influxdb-token -o jsonpath='{.data.token}' | base64 -d)"

# Enable TLS validation
export REQUIRE_TLS="true"
export VERIFY_SSL_CERTS="true"
```

## Troubleshooting

### Common Issues

**Authentication Failures**
```bash
# Test Grafana authentication
curl -u "admin:admin" "http://localhost:3000/api/user"

# Check credentials
echo "User: $GRAFANA_ADMIN_USER"
echo "URL: $GRAFANA_URL"
```

**Data Source Issues**  
```bash
# Test InfluxDB connectivity
curl -H "Authorization: Token $INFLUXDB_TOKEN" "$INFLUXDB_URL/health"

# Verify InfluxDB configuration
influx auth list --token $INFLUXDB_TOKEN
```

**Dashboard Import Failures**
```bash
# Validate dashboard JSON
jq . dashboards/network-upgrade-overview.json

# Check Grafana version compatibility
curl "$GRAFANA_URL/api/frontend/settings" | jq .buildInfo.version
```

**Permission Issues**
```bash
# Make scripts executable
chmod +x *.sh

# Check file permissions
ls -la *.sh
```

### Debug Mode
Enable verbose output for troubleshooting:
```bash
# Verbose provisioning
DEBUG=1 ./provision-dashboards.sh

# Verbose validation
./validate-deployment.sh --verbose

# Dry run deployment
./deploy-to-environment.sh production --dry-run
```

### Log Analysis
Check application logs:
```bash
# Grafana logs (Docker)
docker logs grafana

# InfluxDB logs (Docker)
docker logs influxdb

# System logs
journalctl -u grafana-server
```

## Advanced Usage

### Dashboard Customization
Modify dashboards for your environment:
```bash
# Edit dashboard JSON
vim dashboards/network-upgrade-overview.json

# Validate changes
jq . dashboards/network-upgrade-overview.json

# Deploy updated dashboard
./deploy-to-environment.sh development
```

### Automated Deployment
Set up automated deployment:
```bash
#!/bin/bash
# automated-deploy.sh

set -e

ENVIRONMENTS=("development" "staging" "production")

for env in "${ENVIRONMENTS[@]}"; do
    echo "Deploying to $env..."
    ./deploy-to-environment.sh $env --force
    
    echo "Validating $env..."
    ./validate-deployment.sh --quick
    
    echo "$env deployment completed"
done
```

### Monitoring Deployment Health
Continuous monitoring of dashboard health:
```bash
#!/bin/bash
# health-monitor.sh

while true; do
    if ./validate-deployment.sh --quick > /dev/null 2>&1; then
        echo "$(date): Dashboard health OK"
    else
        echo "$(date): Dashboard health FAILED"
        # Send alert
    fi
    sleep 300  # Check every 5 minutes
done
```

### Integration with External Tools

**Ansible Integration**
```yaml
- name: Deploy Grafana Dashboards
  shell: ./provision-dashboards.sh
  args:
    chdir: /path/to/integration/grafana
  environment:
    GRAFANA_URL: "{{ grafana_url }}"
    INFLUXDB_TOKEN: "{{ influxdb_token }}"
```

**Terraform Integration**
```hcl
resource "null_resource" "grafana_dashboards" {
  provisioner "local-exec" {
    command = "./provision-dashboards.sh"
    working_dir = "${path.module}/integration/grafana"
    
    environment = {
      GRAFANA_URL = var.grafana_url
      INFLUXDB_TOKEN = var.influxdb_token
    }
  }
}
```

**Kubernetes Job**
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: grafana-dashboard-deployment
spec:
  template:
    spec:
      containers:
      - name: dashboard-deployer
        image: network-upgrade-system:latest
        command: ["./integration/grafana/provision-dashboards.sh"]
        env:
        - name: GRAFANA_URL
          value: "http://grafana:3000"
        - name: INFLUXDB_TOKEN
          valueFrom:
            secretKeyRef:
              name: influxdb-token
              key: token
      restartPolicy: OnFailure
```

## Best Practices

### Development
- Use development environment for testing dashboard changes
- Validate JSON syntax before deployment
- Test with representative data
- Version control all dashboard configurations

### Staging  
- Mirror production configuration as closely as possible
- Perform comprehensive validation before production deployment
- Test alert configurations
- Validate performance under load

### Production
- Use secure credential management
- Enable comprehensive monitoring and alerting
- Implement automated backup of dashboard configurations
- Document all customizations and changes
- Use blue-green deployment strategies for critical updates

### Security
- Rotate access tokens regularly
- Use least-privilege access principles
- Enable audit logging for all dashboard changes
- Secure network communication with TLS
- Regular security assessments of monitoring infrastructure

## Maintenance

### Regular Tasks
```bash
# Weekly: Validate deployment health
./validate-deployment.sh --deep

# Monthly: Update dashboard configurations
git pull origin main
./deploy-to-environment.sh production

# Quarterly: Review and optimize dashboard performance
# - Analyze query performance
# - Review data retention policies  
# - Update alert thresholds based on operational experience
```

### Updates and Upgrades
```bash
# Update dashboard configurations
git pull origin main

# Backup existing dashboards (optional)
mkdir -p backups/$(date +%Y%m%d)
curl -s -b /tmp/cookies.txt "$GRAFANA_URL/api/search?type=dash-db" | \
  jq -r '.[].uid' | \
  while read uid; do
    curl -s -b /tmp/cookies.txt "$GRAFANA_URL/api/dashboards/uid/$uid" > "backups/$(date +%Y%m%d)/$uid.json"
  done

# Deploy updates
./deploy-to-environment.sh production

# Validate deployment
./validate-deployment.sh --deep
```

This deployment guide provides comprehensive instructions for deploying and maintaining the Grafana dashboard system for the Network Device Upgrade Management System.