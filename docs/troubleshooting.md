# Troubleshooting Guide

Common issues and solutions for the Network Device Upgrade System.

---

## Custom Network OS Support

### Metamako MOS Connection Handling in Check Mode

**Problem:** `metamako.mos` network OS not recognized by `ansible.netcommon.network_cli` plugin
**Symptom:** `UNREACHABLE` errors when running playbooks in check mode (`--check`)
**Root Cause:** Connection plugin initializes BEFORE `pre_tasks` execute

#### Failed Approach ❌
```yaml
# This doesn't work - connection already established before pre_tasks run
- hosts: metamako_devices
  pre_tasks:
    - name: Override connection for unsupported network OS in check mode
      ansible.builtin.set_fact:
        ansible_connection: local
      when:
        - ansible_check_mode is defined
        - ansible_check_mode
```

#### Correct Solution ✅
Set `ansible_connection` at the **inventory level**, not in playbook vars:

```yaml
# inventory/hosts.yml or group_vars/metamako.yml
all:
  children:
    metamako_devices:
      hosts:
        metamako-switch-01:
          ansible_host: 192.168.1.100
      vars:
        # Set connection to local when check mode is active
        ansible_connection: "{{ 'local' if (ansible_check_mode | default(false)) else 'ansible.netcommon.network_cli' }}"
```

**Why this works:** Inventory variables are evaluated before connection establishment, unlike play-level `pre_tasks`.

#### Alternative: Conditional Connection in Inventory

```yaml
metamako_devices:
  vars:
    ansible_connection: local  # Always use local for check mode compatibility
    ansible_network_os: metamako.mos
```

**Related commits:**
- `f2c7561` - Set local connection for metamako in container test inventory
- `0f5f80c` - Add connection override for metamako.mos in check mode
- `8ac6d46` - Resolve container test failures from GitHub Actions

---

## Container Image Detection Issues

### Image Not Found in Parallel Tests

**Problem:** Container tests fail with "Failed to pull container image" even though image exists locally
**Symptom:** `docker pull` fails for locally-built test images
**Root Cause:** Race condition in parallel test execution where `grep` doesn't match image name

#### Solution ✅
Enhanced image detection with fallback methods:

```bash
# Check by name pattern AND by direct inspection
if docker images | grep -q "network-device-upgrade-system" || \
   docker image inspect "$CONTAINER_IMAGE" &>/dev/null; then
    echo "Container image found locally"
    return 0
fi

# Try pull, then retry detection (handles concurrent builds)
docker pull "$CONTAINER_IMAGE" 2>/dev/null || true
if docker image inspect "$CONTAINER_IMAGE" &>/dev/null; then
    echo "Image pull failed but image exists locally - continuing"
    return 0
fi
```

**Related commit:** `6e0eb28` - Improve container image detection

---

## SSH Key Privilege Drop Tests

### Test Failing on Documentation Check

**Problem:** SSH Key Privilege Drop tests fail with "setup_ssh_keys updated for copied keys" error
**Symptom:** Test looks for comment "keys already copied by root" that doesn't exist
**Root Cause:** Test validated documentation comments instead of actual functionality

#### Solution ✅
Check for functional implementation instead of comments:

```bash
# Before (checking for comment):
grep -A10 'setup_ssh_keys()' docker-entrypoint.sh | grep -q 'keys already copied by root'

# After (checking for functionality):
grep -A10 'setup_ssh_keys()' docker-entrypoint.sh | grep -q 'cisco_nxos_key\|cisco_iosxe_key\|opengear_key\|metamako_key'
```

**Related commit:** `eaab8f4` - Update SSH Key Privilege Drop test to check functionality

---

## Token File Permission Conflicts

### Mock Device Interaction Tests Failing

**Problem:** "Permission denied" when writing to token files in parallel tests
**Symptom:** Multiple test suites trying to create same token files simultaneously
**Root Cause:** First test creates tokens with 600 permissions, second test can't overwrite

#### Solution ✅
Check existence before creating tokens:

```bash
# Only create if doesn't exist (prevents overwrites)
if [[ ! -f "$MOCKUP_DIR/tokens/fortios-token" ]]; then
    echo "mock-fortios-api-token-12345678" > "$MOCKUP_DIR/tokens/fortios-token"
    chmod 600 "$MOCKUP_DIR/tokens/fortios-token"
fi
```

**Security Note:** Always maintain 600 permissions on API tokens (same as SSH keys)

**Related commit:** `d25d8fe` - Maintain 600 permissions for tokens, prevent overwrites

---

## Performance Optimization

### Container Tests Timing Out

**Problem:** Container test suite exceeding 20-minute timeout
**Symptom:** GitHub Actions workflow cancelled after 20 minutes
**Root Cause:** Sequential execution of 6 test suites with ~89 individual tests

#### Solution ✅
Parallel test execution with job control:

```bash
# Run up to 3 test suites concurrently
MAX_PARALLEL_JOBS=3
JOB_PIDS_LIST=()

run_test_suite_async() {
    local suite_name="$1"
    local test_script="$2"

    bash "$test_script" > "/tmp/container-test-${suite_name// /_}.log" 2>&1 &
    local pid=$!
    JOB_PIDS_LIST+=($pid)
}

# Wait for all jobs
for pid in "${JOB_PIDS_LIST[@]}"; do
    wait $pid || true
done
```

**Performance improvement:** 20+ minutes (timeout) → 18 minutes (success)

**Related commit:** `5906b38` - Implement parallel container test execution

---

## Build Workflow Issues

### Invalid Inventory Host in dry-run Test

**Problem:** Container build fails at "Test container functionality" step
**Symptom:** `TARGET_HOSTS validation failed. The following hosts are not defined: test-device`
**Root Cause:** Build workflow uses non-existent test host

#### Solution ✅
Use `localhost` which exists in default inventory:

```yaml
# .github/workflows/build-container.yml
docker run --rm \
  -e TARGET_FIRMWARE="test-firmware.bin" \
  -e TARGET_HOSTS="localhost" \  # Changed from "test-device"
  "$IMAGE_TAG" dry-run
```

**Related commit:** `1f345b5` - Use localhost in container build test

---

## Common Debugging Commands

### Check Ansible Inventory
```bash
ansible-inventory -i ansible-content/inventory/hosts.yml --list
ansible-inventory -i ansible-content/inventory/hosts.yml --graph
```

### Test Check Mode Locally
```bash
ansible-playbook --check --diff \
  ansible-content/playbooks/main-upgrade-workflow.yml \
  -i ansible-content/inventory/hosts.yml
```

### Validate Container Image
```bash
docker image inspect network-device-upgrade-system:test
docker run --rm network-device-upgrade-system:test syntax-check
```

### Debug Connection Issues
```bash
ansible all -m ping -i inventory/hosts.yml -vvv
ansible all -m setup -i inventory/hosts.yml --tree /tmp/facts
```

### Run Container Tests Locally
```bash
cd tests/container-tests
export CONTAINER_IMAGE="network-device-upgrade-system:test"
./run-all-container-tests-parallel.sh
```

---

## Getting Help

If you encounter issues not covered in this guide:

1. Check the [GitHub Issues](https://github.com/garryshtern/network-device-upgrade-system/issues)
2. Review [recent commits](https://github.com/garryshtern/network-device-upgrade-system/commits/main) for related fixes
3. Run tests with verbose output: `ansible-playbook -vvv`
4. Check container logs: `docker logs $(docker ps -lq)`
5. Review test artifacts in `tests/container-tests/results/`
