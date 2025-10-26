# Network Device Upgrade Management System

A complete AWX-based network device upgrade management system designed for managing firmware upgrades across 1000+ heterogeneous network devices with comprehensive validation, security, and monitoring.

## Overview

This system provides automated firmware upgrade capabilities for:
- **Cisco NX-OS** (Nexus Switches) with ISSU support
- **Cisco IOS-XE** (Enterprise Routers/Switches) with Install Mode  
- **Metamako MOS** (Ultra-Low Latency Switches) with Application Management
- **Opengear** (Console Servers/Smart PDUs) with multi-architecture support
- **FortiOS** (Fortinet Firewalls) with HA coordination

**Status**: Production ready for all platforms. See [Platform Implementation Status](docs/platform-implementation-status.md) for detailed status.

## Key Features

### ✅ **Phase-Separated Upgrade Process**
- **Phase 1**: Image Loading (business hours safe)
- **Phase 2**: Image Installation (maintenance window)
- Complete rollback capabilities

### 🔒 **Maximum Security Compliance**
- **Server-Initiated PUSH Transfers Only** - All firmware pushed from upgrade server to devices
- **Zero Device-Initiated Operations** - No device-to-server connections for firmware retrieval
- **SSH Key Authentication Priority** - SSH keys preferred over password authentication
- **SHA512 Hash Verification** - Complete integrity validation for all firmware images
- **Cryptographic Signature Verification** - Where supported by platform
- **Complete Security Audit Trail** - All operations logged and verified

### 📊 **Advanced Validation**
- Pre/post upgrade network state comparison
- BGP, BFD, IGMP/multicast, routing validation
- IPSec tunnel and VPN connectivity validation
- Interface optics and transceiver health monitoring  
- Protocol convergence timing with baseline comparison

### 🚀 **Enterprise Integration**
- Native systemd service deployment (AWX and NetBox)
- Pre-existing NetBox integration
- InfluxDB v2 metrics integration
- ✅ **Complete Grafana dashboard automation** with multi-environment support
- ✅ **Real-time operational monitoring** with 15-second refresh dashboards
- Existing monitoring system integration

## Quick Start

### System Installation

```bash
# 1. Install base system
./install/setup-system.sh

# 2. Setup AWX with native services
./install/setup-awx.sh

# 3. Setup NetBox with native services
./install/setup-netbox.sh

# 4. Configure monitoring integration
./install/configure-telegraf.sh

# 5. Set up SSL certificates
./install/setup-ssl.sh

# 6. Start all services
./install/create-services.sh

# 7. Deploy Grafana dashboards
cd integration/grafana
export INFLUXDB_TOKEN="your_token_here"
./provision-dashboards.sh
```

### Workflow Execution

**Single Entry Point**: All upgrade operations use `main-upgrade-workflow.yml` with tag-based execution.

```bash
# Health check (connectivity validation) - STEP 1
ansible-playbook ansible-content/playbooks/main-upgrade-workflow.yml --tags step1 \
  -e target_hosts=mydevice -e max_concurrent=5

# Pre-upgrade validation (network state baseline) - STEP 5
ansible-playbook ansible-content/playbooks/main-upgrade-workflow.yml --tags step5 \
  -e target_hosts=mydevice -e target_firmware=fw.bin -e max_concurrent=5

# Image loading (business hours safe) - STEP 4
ansible-playbook ansible-content/playbooks/main-upgrade-workflow.yml --tags step4 \
  -e target_hosts=mydevice -e target_firmware=fw.bin -e max_concurrent=5

# Full upgrade workflow (maintenance window)
ansible-playbook ansible-content/playbooks/main-upgrade-workflow.yml \
  -e target_hosts=mydevice -e target_firmware=fw.bin \
  -e max_concurrent=5 -e maintenance_window=true
```

**Container Usage** (Docker/Podman):
```bash
# Health check using container
docker run --rm -v $(pwd)/inventory:/inventory \
  ghcr.io/garryshtern/network-device-upgrade-system:latest \
  playbook main-upgrade-workflow.yml --tags step1 \
  -e target_hosts=mydevice -e max_concurrent=5

# Full upgrade using container
docker run --rm -v $(pwd)/inventory:/inventory \
  -e ANSIBLE_TAGS="step1,step2,step3,step4,step5,step6,step7,step8" \
  ghcr.io/garryshtern/network-device-upgrade-system:latest \
  playbook main-upgrade-workflow.yml \
  -e target_hosts=mydevice -e target_firmware=fw.bin \
  -e max_concurrent=5 -e maintenance_window=true
```

**Deprecated Playbooks**: Individual playbooks have been consolidated into the main workflow:
- `health-check.yml` → Use `--tags step1` instead
- `network-validation.yml` → Use `--tags step5` (pre-upgrade) or `--tags step7` (post-upgrade)
- `image-loading.yml` → Use `--tags step4` instead
- `image-installation.yml` → Use `--tags step6` instead

**Standalone Operational Playbooks** (still separate):
- `emergency-rollback.yml` - Emergency rollback procedures
- `compliance-audit.yml` - Security and compliance auditing
- `config-backup.yml` - Configuration backup operations

## 🧪 Testing Framework

**Comprehensive testing capabilities for Mac/Linux development without physical devices:**

### 📊 **Current Test Results** (Updated: October 1, 2025)
- **✅ Syntax Validation: 100% CLEAN** - All 69+ Ansible files pass syntax checks
- **✅ Security Validation: 100% COMPLIANT** - All secure transfer tests pass (10/10)
- **✅ Test Suite Pass Rate: 100%** - All 23 test suites passing cleanly ✅
- **✅ Container Integration: SUCCESS** - Multi-architecture images (amd64/arm64) available
- **✅ Molecule Testing: 5/9 ROLES** - Critical roles configured with Docker testing
- **✅ Container Tests: OPTIMIZED** - Parallel execution in 18 minutes (6 test suites)

### 🚀 **Quick Testing**
```bash
# Syntax validation (100% clean)
ansible-playbook --syntax-check ansible-content/playbooks/main-upgrade-workflow.yml \
  -e target_hosts=localhost -e target_firmware=test.bin \
  -e maintenance_window=true -e max_concurrent=1

# Mock device testing (all 5 platforms)
ansible-playbook -i tests/mock-inventories/all-platforms.yml --check \
  ansible-content/playbooks/main-upgrade-workflow.yml \
  -e target_hosts=all -e target_firmware=test.bin \
  -e maintenance_window=true -e max_concurrent=5

# Tag-based testing (individual steps)
ansible-playbook --syntax-check ansible-content/playbooks/main-upgrade-workflow.yml \
  --tags step1 -e target_hosts=localhost -e max_concurrent=1

# Complete test suite
./tests/run-all-tests.sh

# Molecule testing (requires Docker)
cd tests/molecule-tests && molecule test

# Container testing (production ready)
docker run --rm ghcr.io/garryshtern/network-device-upgrade-system:latest
podman run --rm ghcr.io/garryshtern/network-device-upgrade-system:latest
```

### ✅ **Testing Categories - FULLY IMPLEMENTED**
- **Mock Inventory Testing** - Simulated device testing for all platforms ✅
- **Variable Validation** - Requirements and constraint validation ✅ 
- **Template Rendering** - Jinja2 template testing without connections ✅
- **Workflow Logic** - Decision path and conditional testing ✅
- **Error Handling** - Error condition and recovery validation ✅
- **Integration Testing** - Complete workflow with mock devices ✅
- **Performance Testing** - Execution time and resource measurement ✅
- **Molecule Testing** - Container-based advanced testing ✅
- **Platform-Specific Testing** - Vendor-specific comprehensive testing ✅
- **YAML/JSON Validation** - File syntax and structure validation ✅
- **CI/CD Integration** - GitHub Actions automated testing ✅

**See comprehensive guide**: [Testing Framework Guide](docs/testing-framework-guide.md)

## 📚 Documentation

**Complete documentation with architectural diagrams and implementation guides:**

- **[📖 Documentation Hub](docs/README.md)** - Start here for comprehensive guides
- **[⚙️ Installation Guide](docs/installation-guide.md)** - Step-by-step deployment  
- **[🔄 Workflow Guide](docs/upgrade-workflow-guide.md)** - Upgrade process and safety mechanisms
- **[🏗️ Platform Guide](docs/platform-implementation-status.md)** - Technical implementation details
- **[📊 Implementation Status](docs/platform-implementation-status.md)** - Current completion analysis
- **[🧪 Testing Framework Guide](docs/testing-framework-guide.md)** - Comprehensive testing without physical devices
- **[🧪 Molecule Testing Guide](docs/molecule-testing-guide.md)** - Role-specific container testing

## Architecture

### System Overview

```mermaid
graph TD
    A[AWX Services<br/>Job Control<br/>systemd] --> B[Ansible Engine<br/>Playbook Execution<br/>Role-Based]
    B --> C[Network Devices<br/>1000+ Supported<br/>Multi-Vendor]
    
    D[NetBox<br/>Inventory DB<br/>Pre-existing] --> B
    E[Telegraf<br/>Metrics Agent<br/>Collection] --> F[InfluxDB v2<br/>Time Series<br/>Existing]
    
    C --> F
    F --> H[Grafana<br/>Dashboards<br/>Existing]
    
    C -.-> I[Cisco NX-OS]
    C -.-> J[Cisco IOS-XE]  
    C -.-> K[FortiOS]
    C -.-> L[Metamako MOS]
    C -.-> M[Opengear]
    
    style A fill:#e1f5fe
    style C fill:#f3e5f5
    style F fill:#e8f5e8
    style H fill:#fff3e0
```

**Alternative System Flow:**

| Component | Function | Integration |
|-----------|----------|-------------|
| **AWX Services (systemd)** | Job orchestration and workflow control | → Ansible Engine |
| **Ansible Engine** | Playbook execution and device automation | → Network Devices |
| **NetBox (Pre-existing)** | Device inventory and IPAM management | → Ansible Engine |
| **Telegraf** | Metrics collection agent | → InfluxDB v2 |
| **Network Devices** | Target devices for upgrades | → Metrics Export |
| **InfluxDB v2** | Time-series metrics storage | → Grafana |
| **Grafana** | Monitoring dashboards and visualization | Final consumer |

### Component Interaction Flow

```mermaid
flowchart TD
    U[User Request] --> A[AWX Web UI]
    A --> B[Job Templates]
    B --> C[Workflows]
    
    B --> D[Dynamic Inventory]
    D --> E[NetBox<br/>Device Data<br/>Variables]
    C --> F[Ansible Execution]
    D --> F
    
    F --> G[Network Devices]
    G --> H[Metrics Collection]
    H --> I[InfluxDB]
    I --> J[Grafana<br/>Dashboards]
    
    subgraph "Job Templates"
        B1[Health Check]
        B2[Image Load]
        B3[Validation]
    end
    
    subgraph "Workflows"  
        C1[Phase 1: Load]
        C2[Phase 2: Install]
        C3[Phase 3: Verify]
    end
    
    style U fill:#ffeb3b
    style G fill:#f3e5f5
    style I fill:#e8f5e8
    style J fill:#fff3e0
```

**Simplified Data Flow:**

1. **User Request** → AWX Web Interface
2. **AWX** → Executes Ansible playbooks  
3. **Ansible** → Connects to network devices via SSH/API
4. **NetBox** → Provides device inventory to Ansible
5. **Network Devices** → Export metrics during operations
6. **Telegraf** → Collects metrics and sends to InfluxDB
7. **InfluxDB** → Stores time-series data for Grafana
8. **Grafana** → Displays dashboards and reports to users

## Resource Requirements

### Minimum System Requirements
- **OS**: RHEL/CentOS 8+ or Ubuntu 20.04+
- **CPU**: 4 cores minimum
- **RAM**: 8GB minimum
- **Storage**: 100GB+ for firmware and logs
- **Network**: Reliable connectivity to all managed devices

### Software Requirements
- **Python**: 3.13 with pip
- **Ansible**: 11.9.0 (ansible-core 2.19.1) - *Latest stable version*
- **Git**: Latest stable version

### Supported Platforms
- **Single Server Deployment**: No clustering required
- **Container-based AWX**: Podman/Docker container deployment
- **Pre-existing NetBox**: Uses existing NetBox installation
- **SystemD User Services**: Native Linux user service management for base components

## Directory Structure

```
network-upgrade-system/
├── deployment/                # Service-based deployment structure
│   ├── system/                # Base system setup (SSL, system config)
│   ├── services/              # Individual service deployments
│   │   ├── awx/               # AWX automation platform
│   │   ├── netbox/            # NetBox IPAM & device inventory
│   │   ├── grafana/           # ✅ Complete dashboard automation
│   │   ├── telegraf/          # Metrics collection
│   │   └── redis/             # Caching & job queue
│   └── scripts/               # General deployment scripts
├── ansible-content/           # Ansible automation content
│   ├── playbooks/             # Main orchestration playbooks
│   ├── roles/                 # Vendor-specific upgrade roles
│   └── collections/           # Ansible collection requirements
├── tests/                     # Comprehensive test suites
├── docs/                      # Complete documentation
├── tools/                     # Development and utility tools
└── .claude/                   # Claude Code commands and workflows
```

## Workflow Execution Modes

The system uses **`main-upgrade-workflow.yml`** as the single entry point for all upgrade operations. Individual steps can be executed using Ansible tags, with automatic dependency resolution.

### Available Execution Tags

| Tag | Step Name | Description | Dependencies | Safe During Business Hours |
|-----|-----------|-------------|--------------|---------------------------|
| `step1` | Health Check | Initial connectivity validation | None | ✅ Yes |
| `step2` | Hash Verification | SHA512 firmware integrity check | None | ✅ Yes |
| `step3` | Pre-Upgrade Backup | Configuration backup before changes | step1 | ✅ Yes |
| `step4` | Image Loading | Transfer firmware to device (PHASE 1) | step1, step2 | ✅ Yes |
| `step5` | Pre-Upgrade Validation | Network state baseline capture | step1 | ✅ Yes |
| `step6` | Image Installation | Install firmware and reboot (PHASE 2) | step4 | ⚠️ Maintenance Window |
| `step7` | Post-Upgrade Validation | Network state verification | step6 | ⚠️ Maintenance Window |
| `step8` | Metric Publishing | Send results to InfluxDB | step7 | ⚠️ Maintenance Window |

### Execution Examples

**Individual Step Execution:**
```bash
# Run only health check (STEP 1)
ansible-playbook ansible-content/playbooks/main-upgrade-workflow.yml \
  --tags step1 \
  -e target_hosts=mydevice \
  -e max_concurrent=5

# Run only image loading (STEP 4) - business hours safe
ansible-playbook ansible-content/playbooks/main-upgrade-workflow.yml \
  --tags step4 \
  -e target_hosts=mydevice \
  -e target_firmware=nxos-10.3.5.bin \
  -e max_concurrent=5
```

**Multiple Step Execution:**
```bash
# Run PHASE 1: Health check + backup + image loading
ansible-playbook ansible-content/playbooks/main-upgrade-workflow.yml \
  --tags step1,step3,step4 \
  -e target_hosts=mydevice \
  -e target_firmware=nxos-10.3.5.bin \
  -e max_concurrent=5

# Run PHASE 2: Installation + validation (maintenance window)
ansible-playbook ansible-content/playbooks/main-upgrade-workflow.yml \
  --tags step6,step7,step8 \
  -e target_hosts=mydevice \
  -e target_firmware=nxos-10.3.5.bin \
  -e maintenance_window=true \
  -e max_concurrent=5
```

**Full Workflow Execution:**
```bash
# Execute all steps (complete upgrade)
ansible-playbook ansible-content/playbooks/main-upgrade-workflow.yml \
  -e target_hosts=mydevice \
  -e target_firmware=nxos-10.3.5.bin \
  -e maintenance_window=true \
  -e max_concurrent=5
```

### Required Variables by Execution Mode

| Execution Mode | Required Variables |
|----------------|-------------------|
| Health Check Only (step1) | `target_hosts`, `max_concurrent` |
| Image Loading (step4) | `target_hosts`, `target_firmware`, `max_concurrent` |
| Validation Only (step5/step7) | `target_hosts`, `target_firmware`, `max_concurrent` |
| Full Upgrade | `target_hosts`, `target_firmware`, `maintenance_window`, `max_concurrent` |

### Automatic Dependency Resolution

The workflow automatically handles dependencies between steps:
- **STEP 4** (Image Loading) requires **STEP 2** (Hash Verification) to pass first
- **STEP 6** (Image Installation) requires **STEP 4** (Image Loading) to complete
- **STEP 7** (Post-Validation) requires **STEP 6** (Installation) to finish
- **STEP 8** (Metrics) requires **STEP 7** (Validation) to complete

**Example**: Running `--tags step6` will automatically verify that step4 (image loading) was completed successfully.

### Playbook Migration Guide

For users migrating from legacy individual playbooks:

| Legacy Playbook | New Command |
|----------------|-------------|
| `health-check.yml` | `main-upgrade-workflow.yml --tags step1` |
| `network-validation.yml` (pre) | `main-upgrade-workflow.yml --tags step5` |
| `network-validation.yml` (post) | `main-upgrade-workflow.yml --tags step7` |
| `image-loading.yml` | `main-upgrade-workflow.yml --tags step4` |
| `image-installation.yml` | `main-upgrade-workflow.yml --tags step6` |

**Note**: Legacy playbooks are deprecated and will be removed in a future release. Migrate to tag-based execution.

## Support

For technical support and questions:
- Check the [Installation Guide](docs/installation-guide.md) troubleshooting section
- Review platform-specific procedures in [Platform Implementation Guide](docs/platform-implementation-status.md)
- Examine log files in `$HOME/.local/share/network-upgrade/logs/`
- Use the built-in health check: `./scripts/system-health.sh`

## License

This project is licensed under the MIT License - see the LICENSE file for details.