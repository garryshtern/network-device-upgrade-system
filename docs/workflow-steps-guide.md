# Network Device Upgrade Workflow Steps Guide

## Quick Overview

The upgrade workflow has **7 independent steps** that can be run in any combination. Each step automatically includes only the dependencies it needs.

```
Step 1: Connectivity ✓
Step 2: Version Check (optional)
Step 3: Space Check (optional)
Step 4: Upload Image + Backup Config (optional)
Step 5: Pre-Upgrade Validation (optional, creates baseline)
Step 6: Install Firmware + Reboot (the actual upgrade)
Step 7: Post-Upgrade Validation (requires step 5 baseline)
```

---

## The 7 Steps Explained

### Step 1: Connectivity Check
**What it does:** Verifies SSH/NETCONF connection to devices
**Dependencies:** None (can run standalone)
**Command:** `ansible-playbook main-upgrade-workflow.yml --tags step1 -e target_hosts=mydevice -e max_concurrent=5`
**When to use:** To test if devices are reachable

---

### Step 2: Version Check
**What it does:** Checks current firmware version and verifies firmware file exists
**Dependencies:** Step 1 (auto-included)
**Command:** `ansible-playbook main-upgrade-workflow.yml --tags step2 -e target_hosts=mydevice -e target_firmware=fw.bin -e max_concurrent=5`
**When to use:** Before upgrading, to verify you have the right firmware file

---

### Step 3: Space Check
**What it does:** Verifies sufficient disk space (auto-cleans old images if needed)
**Dependencies:** Steps 1-2 (auto-included)
**Command:** `ansible-playbook main-upgrade-workflow.yml --tags step3 -e target_hosts=mydevice -e target_firmware=fw.bin -e max_concurrent=5`
**When to use:** To ensure devices have room for new firmware before uploading

---

### Step 4: Upload Image + Backup Config
**What it does:**
- Stages firmware image on device
- Backs up running configuration
**Dependencies:** Steps 1-3 (auto-included)
**Command:** `ansible-playbook main-upgrade-workflow.yml --tags step4 -e target_hosts=mydevice -e target_firmware=fw.bin -e max_concurrent=5`
**When to use:** To prepare devices before the actual upgrade (recommended for safety)

---

### Step 5: Pre-Upgrade Validation
**What it does:**
- Gathers comprehensive network state (BGP, interfaces, routes, etc.)
- Validates network is healthy
- **Saves baseline file for later comparison**
**Dependencies:** Step 1 only (auto-included)
**Command:** `ansible-playbook main-upgrade-workflow.yml --tags step5 -e target_hosts=mydevice -e max_concurrent=5`
**When to use:** **ALWAYS run this before step 6 if you want to validate after upgrade**
**Note:** Creates baseline file needed for step 7

---

### Step 6: Install Firmware + Reboot
**What it does:**
- Installs new firmware
- Reboots device
**Dependencies:** Step 1 only (auto-included)
**Command:** `ansible-playbook main-upgrade-workflow.yml --tags step6 -e target_hosts=mydevice -e target_firmware=fw.bin -e max_concurrent=5 -e maintenance_window=true`
**⚠️ Safety flag:** Requires `maintenance_window=true` (prevents accidental reboots)
**When to use:** The actual firmware upgrade step

---

### Step 7: Post-Upgrade Validation
**What it does:**
- Gathers network state after upgrade
- **Compares to step 5 baseline**
- Detects any unexpected network changes
**Dependencies:** Step 1 only (auto-included)
**Command:** `ansible-playbook main-upgrade-workflow.yml --tags step7 -e target_hosts=mydevice -e max_concurrent=5`
**⚠️ Critical requirement:** Baseline file from step 5 must exist
**When to use:** After step 6, to validate upgrade didn't break anything

---

## Common Workflows

### 1. **Safe Full Upgrade** (Recommended)
```bash
# Step 1: Validate devices are reachable
ansible-playbook main-upgrade-workflow.yml --tags step5 \
  -e target_hosts=prod-switches \
  -e target_firmware=nxos.10.3.3.bin \
  -e max_concurrent=5

# Step 2: Upload firmware and backup config
ansible-playbook main-upgrade-workflow.yml --tags step4 \
  -e target_hosts=prod-switches \
  -e target_firmware=nxos.10.3.3.bin \
  -e max_concurrent=5

# Step 3: Install firmware (during maintenance window)
ansible-playbook main-upgrade-workflow.yml --tags step6 \
  -e target_hosts=prod-switches \
  -e target_firmware=nxos.10.3.3.bin \
  -e max_concurrent=5 \
  -e maintenance_window=true

# Step 4: Validate everything still works
ansible-playbook main-upgrade-workflow.yml --tags step7 \
  -e target_hosts=prod-switches \
  -e max_concurrent=5
```

### 2. **Quick Full Upgrade** (Less safe)
```bash
ansible-playbook main-upgrade-workflow.yml --tags step6 \
  -e target_hosts=prod-switches \
  -e target_firmware=nxos.10.3.3.bin \
  -e max_concurrent=5 \
  -e maintenance_window=true
```
⚠️ No pre-validation baseline, can't compare post-upgrade state

### 3. **Just Check Connectivity**
```bash
ansible-playbook main-upgrade-workflow.yml --tags step1 \
  -e target_hosts=prod-switches \
  -e max_concurrent=5
```

### 4. **Pre-Upgrade Validation Only**
```bash
ansible-playbook main-upgrade-workflow.yml --tags step5 \
  -e target_hosts=prod-switches \
  -e max_concurrent=5
```
Useful for: Planning, generating baseline before scheduled upgrade

### 5. **Check If Device Already Upgraded**
```bash
ansible-playbook main-upgrade-workflow.yml --tags step2 \
  -e target_hosts=prod-switches \
  -e target_firmware=nxos.10.3.3.bin \
  -e max_concurrent=5
```

### 6. **Emergency Upgrade** (No pre-checks)
```bash
ansible-playbook main-upgrade-workflow.yml --tags step6 \
  -e target_hosts=prod-switches \
  -e target_firmware=nxos.10.3.3.bin \
  -e max_concurrent=5 \
  -e maintenance_window=true
```
⚠️ Use only when devices are already prepared

---

## Step Dependencies at a Glance

| Step | What it needs | What it provides |
|------|---------------|------------------|
| **Step 1** | Nothing | Device connectivity |
| **Step 2** | Step 1 | Current version confirmation |
| **Step 3** | Steps 1-2 | Space confirmation |
| **Step 4** | Steps 1-3 | Firmware staged, config backup |
| **Step 5** | Step 1 | Network baseline saved |
| **Step 6** | Step 1 | Firmware installed, reboot done |
| **Step 7** | Step 1 + baseline file from step 5 | Validation results |

---

## Key Rules

### ✅ DO:
- **Run step 5 before step 6** if you want post-upgrade validation
- **Use `maintenance_window=true`** when running step 6 (prevents accidents)
- **Run step 7 after step 6** to verify the upgrade worked
- Run steps in any order you want (except step 7 needs step 5 baseline)

### ❌ DON'T:
- Run step 7 without first running step 5 (baseline won't exist)
- Run step 6 without `maintenance_window=true` flag
- Assume devices are ready without running step 5

---

## Required Variables by Step

```
All steps:
  - target_hosts     (device group or hostname)
  - max_concurrent   (number of parallel devices)

Step 2-7:
  - target_firmware  (for version check and upload)

Step 6:
  - maintenance_window=true  (REQUIRED for safety)

Container only:
  - SSH keys or API tokens (for authentication)
```

---

## Troubleshooting

### "Post-upgrade validation failed - baseline missing"
→ You didn't run step 5 before step 6. Run step 5 next time.

### "Device rebooted but step 6 failed"
→ Device rebooted successfully but validation after reboot failed. Use step 7 to check current state.

### "step 7 shows network changes"
→ Firmware upgrade caused network state changes. Review the detailed comparison results.

### "Step 4 fails on upload"
→ Device may not have space. Run step 3 to check and clean if needed.

---

## Container Usage

Same steps, but with Docker/Podman:

```bash
docker run --rm \
  -e TARGET_HOSTS=prod-switch-01 \
  -e TARGET_FIRMWARE=nxos.10.3.3.bin \
  -e MAX_CONCURRENT=5 \
  -e MAINTENANCE_WINDOW=true \
  ghcr.io/garryshtern/network-device-upgrade-system:latest run
```

See [container-deployment.md](container-deployment.md) for full container documentation.

---

## More Help

- **Step details**: See individual step files in `ansible-content/playbooks/steps/`
- **EPLD upgrades**: See [platform-specific guides](platform-guides/)
- **Authentication**: See [authentication.md](authentication.md)
- **Troubleshooting**: See [troubleshooting.md](troubleshooting.md)
