# SSH Key Privilege Drop Solution

## 🔐 Problem Statement

**Security Challenge:** Container SSH keys need to be mounted as `root:root 600` for security, but the container runs as user `ansible` (UID 1000) who cannot read root-owned files.

**Root Cause:**
- SSH keys mounted from host: `root:root 600` (secure)
- Container execution user: `ansible` (UID 1000) (secure)
- **Conflict:** ansible user cannot read root-owned SSH keys

## ✅ Clever Solution: Root-to-Ansible Privilege Drop

### Implementation Strategy

1. **Container starts as root** - Can read mounted SSH keys
2. **Root copies SSH keys** - To ansible-accessible location with proper ownership
3. **Privilege drop to ansible** - All subsequent operations run as ansible user
4. **Security maintained** - Best of both worlds

### Code Implementation

#### 1. Dockerfile Changes

```dockerfile
# Build process runs as ansible user (for security)
USER ansible
# ... install packages, collections, copy files ...

# Switch back to root for container startup
USER root
ENTRYPOINT ["./docker-entrypoint.sh"]
```

#### 2. Entrypoint Script Privilege Drop

```bash
handle_privilege_drop() {
    # If running as root, copy SSH keys and switch to ansible user
    if [[ $EUID -eq 0 ]]; then
        log "Running as root - handling SSH key setup and switching to ansible user"

        # Setup SSH keys as root (can read root-owned mounted keys)
        setup_ssh_keys_as_root

        # Switch to ansible user and re-exec this script
        log "Switching to ansible user and re-executing..."
        exec su ansible -c "$0 $(printf '%q ' "$@")"
    fi

    # If we reach here, we're running as ansible user - proceed normally
}
```

#### 3. Root SSH Key Copying

```bash
setup_ssh_keys_as_root() {
    local keys_dir="/home/ansible/.ssh"

    # Create .ssh directory for ansible user
    mkdir -p "$keys_dir"
    chmod 700 "$keys_dir"
    chown ansible:ansible "$keys_dir"

    # Copy each SSH key type if it exists
    copy_ssh_key_as_root "${CISCO_NXOS_SSH_KEY:-}" "$keys_dir/cisco_nxos_key"
    copy_ssh_key_as_root "${CISCO_IOSXE_SSH_KEY:-}" "$keys_dir/cisco_iosxe_key"
    copy_ssh_key_as_root "${OPENGEAR_SSH_KEY:-}" "$keys_dir/opengear_key"
    copy_ssh_key_as_root "${METAMAKO_SSH_KEY:-}" "$keys_dir/metamako_key"
}

copy_ssh_key_as_root() {
    local src_key="$1"
    local dest_key="$2"

    if [[ -n "$src_key" ]] && [[ -f "$src_key" ]]; then
        log "Copying SSH key: $src_key -> $dest_key"
        cp "$src_key" "$dest_key"
        chmod 600 "$dest_key"
        chown ansible:ansible "$dest_key"
    fi
}
```

#### 4. Updated SSH Key Usage

```bash
setup_ssh_keys() {
    local keys_dir="/home/ansible/.ssh"

    # Set internal SSH key variables to point to copied keys
    if [[ -n "${CISCO_NXOS_SSH_KEY:-}" ]] && [[ -f "$keys_dir/cisco_nxos_key" ]]; then
        export CISCO_NXOS_SSH_KEY_INTERNAL="$keys_dir/cisco_nxos_key"
    fi
    # ... similar for other platforms
}
```

### Execution Flow

```
1. Container starts as root
   ↓
2. handle_privilege_drop() called
   ↓
3. Root detects EUID=0
   ↓
4. setup_ssh_keys_as_root() executes
   ↓
5. SSH keys copied: /opt/keys/key → /home/ansible/.ssh/key
   ↓
6. Ownership changed: root:root → ansible:ansible
   ↓
7. exec su ansible -c "script args..."
   ↓
8. Script re-executes as ansible user
   ↓
9. handle_privilege_drop() called again
   ↓
10. EUID≠0, continues as ansible user
    ↓
11. main() executes all operations as ansible
```

## 🚀 Usage Examples

### Basic SSH Key Mounting

```bash
# Create SSH key
ssh-keygen -t rsa -b 2048 -f ./cisco-nxos-key -N ""

# Run container with SSH key
docker run --rm \
  -v ./cisco-nxos-key:/opt/keys/cisco-nxos-key:ro \
  -e CISCO_NXOS_SSH_KEY="/opt/keys/cisco-nxos-key" \
  -e TARGET_HOSTS="cisco-switch-01" \
  network-upgrade-system syntax-check
```

### Multiple Platform SSH Keys

```bash
docker run --rm \
  -v ./cisco-nxos-key:/opt/keys/cisco-nxos-key:ro \
  -v ./cisco-iosxe-key:/opt/keys/cisco-iosxe-key:ro \
  -v ./opengear-key:/opt/keys/opengear-key:ro \
  -e CISCO_NXOS_SSH_KEY="/opt/keys/cisco-nxos-key" \
  -e CISCO_IOSXE_SSH_KEY="/opt/keys/cisco-iosxe-key" \
  -e OPENGEAR_SSH_KEY="/opt/keys/opengear-key" \
  -e TARGET_HOSTS="all" \
  network-upgrade-system dry-run
```

## 🔒 Security Benefits

1. **Secure SSH Key Storage:** Keys remain `root:root 600` on host
2. **Non-root Execution:** All Ansible operations run as unprivileged user
3. **Minimal Privilege:** Root access only during initial key setup
4. **Clean Separation:** Build-time vs runtime privilege requirements
5. **Container Security:** Follows container security best practices

## ✅ Verification

The privilege drop mechanism ensures:

- ✅ SSH keys can be mounted with secure permissions
- ✅ Container starts as root for key access
- ✅ Keys are copied to ansible-accessible location
- ✅ All operations execute as ansible user
- ✅ Security maintained throughout process
- ✅ Compatible with RHEL/podman environments

## 🎯 Result

**Problem solved:** SSH keys work securely in containers with proper privilege separation and no security compromises.