# Network Device Upgrade Workflow Steps Guide

## Quick Overview

The upgrade workflow has **8 independent steps** with a streamlined dependency model. Each step depends directly only on STEP 1 (connectivity), while the main workflow orchestrates additional dependencies through tag-based execution.

```
Step 1: Connectivity ✓ (no dependencies)
Step 2: Version Check (depends on step1 directly; steps 1-2 via tags)
Step 3: Space Check (depends on step1 directly; steps 1-3 via tags)
Step 4: Image Upload (depends on step1 directly; steps 1-4 via tags)
Step 5: Config Backup and Pre-Upgrade Validation (depends on step1 directly; steps 1-5 via tags, creates baseline)
Step 6: Install Firmware + Reboot (depends on step1 directly; steps 1-6 via tags)
Step 7: Post-Upgrade Validation (depends on step1 directly; steps 1-7 via tags, requires step 5 baseline)
Step 8: Emergency Rollback (depends on step1 directly; triggered by step7 or manual)
```

---

## The 8 Steps Explained

### Step 1: Connectivity Check
**What it does:** Verifies SSH/NETCONF connection to devices
**Dependencies:** None (can run standalone)
**Command:** `ansible-playbook main-upgrade-workflow.yml --tags step1 -e target_hosts=mydevice -e max_concurrent=5`
**When to use:** To test if devices are reachable

---

### Step 2: Version Check
**What it does:** Checks current firmware version and verifies firmware file exists
**Dependencies:** Step 1 (directly); Steps 1-2 (orchestrated by main workflow tags)
**Command:** `ansible-playbook main-upgrade-workflow.yml --tags step2 -e target_hosts=mydevice -e target_firmware=fw.bin -e max_concurrent=5`
**When to use:** Before upgrading, to verify you have the right firmware file

---

### Step 3: Space Check
**What it does:** Verifies sufficient disk space (auto-cleans old images if needed)
**Dependencies:** Step 1 (directly); Steps 1-3 (orchestrated by main workflow tags)
**Command:** `ansible-playbook main-upgrade-workflow.yml --tags step3 -e target_hosts=mydevice -e target_firmware=fw.bin -e max_concurrent=5`
**When to use:** To ensure devices have room for new firmware before uploading

---

### Step 4: Image Upload
**What it does:**
- Uploads firmware image to devices
- Verifies SHA512 hash after upload (mandatory)
**Dependencies:** Step 1 (directly); Steps 1-4 (orchestrated by main workflow tags)
**Command:** `ansible-playbook main-upgrade-workflow.yml --tags step4 -e target_hosts=mydevice -e target_firmware=fw.bin -e max_concurrent=5`
**When to use:** To stage firmware and verify integrity before pre-upgrade validation

---

### Step 5: Config Backup and Pre-Upgrade Validation
**What it does:**
- Backs up running configuration
- Gathers comprehensive network state (interfaces, routing, ARP, BGP, multicast, BFD, etc.)
- Captures pre-upgrade baseline for post-upgrade comparison
- **Saves baseline file for later comparison**
**Dependencies:** Step 1 (directly); Steps 1-5 (orchestrated by main workflow tags)
**Command:** `ansible-playbook main-upgrade-workflow.yml --tags step5 -e target_hosts=mydevice -e max_concurrent=5`
**When to use:** **ALWAYS run this before step 6 if you want to validate after upgrade**
**Note:** Creates baseline file needed for step 7

---

### Step 6: Install Firmware + Reboot
**What it does:**
- Installs new firmware
- Reboots device
**Dependencies:** Step 1 (directly); Steps 1-6 (orchestrated by main workflow tags)
**Command:** `ansible-playbook main-upgrade-workflow.yml --tags step6 -e target_hosts=mydevice -e target_firmware=fw.bin -e max_concurrent=5 -e maintenance_window=true`
**⚠️ Safety flag:** Requires `maintenance_window=true` (prevents accidental reboots)
**When to use:** The actual firmware upgrade step

---

### Step 7: Post-Upgrade Validation
**What it does:**
- Gathers network state after upgrade
- **Compares to step 5 baseline**
- Detects any unexpected network changes
**Dependencies:** Step 1 (directly); Steps 1-7 (orchestrated by main workflow tags)
**Command:** `ansible-playbook main-upgrade-workflow.yml --tags step7 -e target_hosts=mydevice -e max_concurrent=5`
**⚠️ Critical requirement:** Baseline file from step 5 must exist
**When to use:** After step 6, to validate upgrade didn't break anything

---

### Step 8: Emergency Rollback
**What it does:**
- Restores device to previous firmware
- Restores previous configuration
- Provides automatic recovery from failed upgrades
**Dependencies:** Step 1 (directly); Triggered by Step 7 rescue block or manual invocation
**Command:** `ansible-playbook main-upgrade-workflow.yml --tags step8 -e target_hosts=mydevice -e max_concurrent=5`
**⚠️ Safety note:** Can cause service interruption during rollback
**When to use:** Automatically triggered by step 7 validation failures, or manually for emergency recovery

---

## Common Workflows

### 1. **Safe Full Upgrade** (Recommended)
```bash
# Step 1: Connectivity check
ansible-playbook main-upgrade-workflow.yml --tags step1 \
  -e target_hosts=prod-switches \
  -e max_concurrent=5

# Step 2: Version check
ansible-playbook main-upgrade-workflow.yml --tags step2 \
  -e target_hosts=prod-switches \
  -e target_firmware=nxos.10.3.3.bin \
  -e max_concurrent=5

# Step 3: Space check
ansible-playbook main-upgrade-workflow.yml --tags step3 \
  -e target_hosts=prod-switches \
  -e target_firmware=nxos.10.3.3.bin \
  -e max_concurrent=5

# Step 4: Upload firmware
ansible-playbook main-upgrade-workflow.yml --tags step4 \
  -e target_hosts=prod-switches \
  -e target_firmware=nxos.10.3.3.bin \
  -e max_concurrent=5

# Step 5: Pre-upgrade validation and config backup
ansible-playbook main-upgrade-workflow.yml --tags step5 \
  -e target_hosts=prod-switches \
  -e target_firmware=nxos.10.3.3.bin \
  -e max_concurrent=5

# Step 6: Install firmware (during maintenance window)
ansible-playbook main-upgrade-workflow.yml --tags step6 \
  -e target_hosts=prod-switches \
  -e target_firmware=nxos.10.3.3.bin \
  -e max_concurrent=5 \
  -e maintenance_window=true

# Step 7: Post-upgrade validation
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

**New Dependency Model**: Each step depends directly only on STEP 1. Additional dependencies are managed by the main workflow through tag-based execution.

| Step | Direct Dependency | Orchestrated Dependencies (via tags) | What it provides |
|------|-------------------|-------------------------------------|------------------|
| **Step 1** | None | None | Device connectivity |
| **Step 2** | Step 1 only | Steps 1-2 (main workflow) | Current version confirmation |
| **Step 3** | Step 1 only | Steps 1-3 (main workflow) | Space confirmation |
| **Step 4** | Step 1 only | Steps 1-4 (main workflow) | Firmware staged, config backup |
| **Step 5** | Step 1 only | Steps 1-5 (main workflow) | Network baseline saved |
| **Step 6** | Step 1 only | Steps 1-6 (main workflow) | Firmware installed, reboot done |
| **Step 7** | Step 1 only | Steps 1-7 (main workflow) | Validation results, comparison |
| **Step 8** | Step 1 only | Triggered by Step 7 or manual | Emergency recovery completed |

---

## Key Rules

### ✅ DO:
- **Run step 5 before step 6** if you want post-upgrade validation
- **Use `maintenance_window=true`** when running step 6 (prevents accidents)
- **Run step 7 after step 6** to verify the upgrade worked
- **Let main workflow manage dependencies** via tags (don't worry about nested includes)
- Run steps in any order you want (main workflow ensures proper execution)

### ❌ DON'T:
- Run step 7 without first running step 5 (baseline won't exist)
- Run step 6 without `maintenance_window=true` flag
- Assume devices are ready without running step 5
- Manually manage step dependencies (let the main workflow handle it)

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
