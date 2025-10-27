#!/bin/bash
# Network Device Upgrade System - Container Entrypoint
# Provides flexible execution modes for Ansible playbooks

set -euo pipefail

# Constants - Single source of truth for paths
readonly DEFAULT_BASE_PATH="/var/lib/network-upgrade"
readonly DEFAULT_FIRMWARE_PATH="${DEFAULT_BASE_PATH}/firmware"
readonly DEFAULT_BACKUP_PATH="${DEFAULT_BASE_PATH}/backups"

# Privilege drop mechanism for SSH key handling
# This must run BEFORE main() to handle root-to-ansible user switch
handle_privilege_drop() {
    # If we're running as root, copy SSH keys and switch to ansible user
    if [[ $EUID -eq 0 ]]; then
        log "Running as root - handling SSH key setup and switching to ansible user"

        # Setup SSH keys as root (can read root-owned mounted keys)
        setup_ssh_keys_as_root

        # Switch to ansible user and re-exec this script
        # Use sudo -E to preserve environment, and set PATH explicitly
        log "Switching to ansible user and re-executing..."
        exec sudo -E -u ansible env PATH="/home/ansible/.local/bin:$PATH" HOME="/home/ansible" "$0" "$@"
    fi

    # If we reach here, we're running as ansible user - proceed normally
}

# Copy SSH keys when running as root
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

    log "SSH keys copied and permissions set for ansible user"
}

# Helper function to copy individual SSH key
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

# Default values
DEFAULT_PLAYBOOK="ansible-content/playbooks/main-upgrade-workflow.yml"
DEFAULT_INVENTORY="ansible-content/inventory/hosts.yml"
DEFAULT_MODE="syntax-check"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function (output to stderr to avoid contaminating function return values)
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" >&2
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

# Display usage information
usage() {
    cat << EOF
Network Device Upgrade System - Container Usage

SYNOPSIS:
    docker run [docker-options] network-upgrade-system [COMMAND] [OPTIONS]

COMMANDS:
    syntax-check        Run Ansible syntax validation (default)
    dry-run            Execute playbook in check mode (no changes)
    run                Execute playbook (make actual changes)
    test               Run comprehensive test suite
    shell              Start interactive bash shell
    help               Show this help message

ENVIRONMENT VARIABLES:
    # Core Ansible Configuration
    ANSIBLE_PLAYBOOK   Playbook to execute (default: ${DEFAULT_PLAYBOOK})
    ANSIBLE_TAGS       Workflow steps to execute (e.g., step1, step5, step6)
                       Multiple tags: step1,step5 OR individual step with auto-dependencies
                       Supported: step1-step7, connectivity, version_check, space_check,
                                  image_upload, config_backup, pre_validation, install,
                                  reboot, post_validation
    INVENTORY_FILE     Inventory file path (default: ${DEFAULT_INVENTORY})
                       Note: Use INVENTORY_FILE (not ANSIBLE_INVENTORY) to avoid conflicts
    ANSIBLE_CONFIG     Path to ansible.cfg file
    ANSIBLE_VAULT_PASSWORD_FILE  Path to vault password file

    # Upgrade Configuration
    TARGET_HOSTS       Hosts to target (default: all)
    TARGET_FIRMWARE    Firmware version to install
    UPGRADE_PHASE      Phase: full, loading, installation, validation, rollback
    MAX_CONCURRENT     REQUIRED: Number of devices to upgrade in parallel (e.g., 5)
                       Note: Must be provided - 'serial' processed before group_vars
    MAINTENANCE_WINDOW Set to 'true' for installation phase

    # EPLD Upgrade Configuration (Cisco NX-OS)
    ENABLE_EPLD_UPGRADE      Enable EPLD upgrade (true/false)
    ALLOW_DISRUPTIVE_EPLD    Allow disruptive EPLD upgrade (true/false)
    EPLD_UPGRADE_TIMEOUT     EPLD upgrade timeout in seconds (default: 7200)
    TARGET_EPLD_IMAGE        EPLD firmware filename (e.g., n9000-epld.10.1.2.img)
    TARGET_EPLD_FIRMWARE     Alias for TARGET_EPLD_IMAGE (both accepted)

    # Multi-Step Upgrade (FortiOS)
    MULTI_STEP_UPGRADE_REQUIRED  Enable multi-step upgrade mode (true/false)
    UPGRADE_PATH                 Comma-separated upgrade path (e.g., "6.4.8,7.0.12,7.2.5")

    # Debug Configuration
    SHOW_DEBUG               Enable verbose debug output (true/false, default: false)
                            Enables comprehensive device facts dumps and debug tasks

    # SSH Key Authentication (Preferred)
    CISCO_NXOS_SSH_KEY          SSH private key for Cisco NX-OS devices
    CISCO_IOSXE_SSH_KEY         SSH private key for Cisco IOS-XE devices
    OPENGEAR_SSH_KEY            SSH private key for Opengear devices
    METAMAKO_SSH_KEY            SSH private key for Metamako devices

    # API Token Authentication (API-based platforms)
    FORTIOS_API_TOKEN           API token for FortiOS devices
    OPENGEAR_API_TOKEN          API token for Opengear REST API

    # Password Authentication (Fallback)
    CISCO_NXOS_PASSWORD         Password for Cisco NX-OS devices
    CISCO_IOSXE_PASSWORD        Password for Cisco IOS-XE devices
    FORTIOS_PASSWORD            Password for FortiOS devices
    OPENGEAR_PASSWORD           Password for Opengear devices
    METAMAKO_PASSWORD           Password for Metamako devices

    # Username Configuration
    CISCO_NXOS_USERNAME         Username for Cisco NX-OS devices
    CISCO_IOSXE_USERNAME        Username for Cisco IOS-XE devices
    FORTIOS_USERNAME            Username for FortiOS devices
    OPENGEAR_USERNAME           Username for Opengear devices
    METAMAKO_USERNAME           Username for Metamako devices

    # Additional Configuration
    IMAGE_SERVER_USERNAME       Username for firmware image server
    IMAGE_SERVER_PASSWORD       Password for firmware image server
    SNMP_COMMUNITY              SNMP community string for monitoring

    # Path Configuration
    NETWORK_UPGRADE_BASE_PATH   Base directory for all upgrade data (default: ${DEFAULT_BASE_PATH})
    FIRMWARE_BASE_PATH          Base directory for firmware images (default: ${DEFAULT_FIRMWARE_PATH})
    BACKUP_BASE_PATH            Base directory for configuration backups (default: ${DEFAULT_BACKUP_PATH})

EXAMPLES:
    # Syntax check (default)
    docker run --rm ghcr.io/garryshtern/network-device-upgrade-system:latest

    # Run syntax check on specific playbook
    docker run --rm \\
      -e ANSIBLE_PLAYBOOK=ansible-content/playbooks/health-check.yml \\
      ghcr.io/garryshtern/network-device-upgrade-system:latest syntax-check

    # Dry run upgrade workflow
    docker run --rm \\
      -e TARGET_FIRMWARE=9.3.12 -e TARGET_HOSTS=cisco-switch-01 \\
      -e MAX_CONCURRENT=5 \\
      ghcr.io/garryshtern/network-device-upgrade-system:latest dry-run

    # Execute actual upgrade (production)
    docker run --rm \\
      -e TARGET_FIRMWARE=9.3.12 -e TARGET_HOSTS=cisco-switch-01 \\
      -e MAX_CONCURRENT=5 -e UPGRADE_PHASE=loading -e MAINTENANCE_WINDOW=false \\
      ghcr.io/garryshtern/network-device-upgrade-system:latest run

    # Run individual workflow steps (with automatic dependency resolution)
    # Step 1: Connectivity check only
    docker run --rm \\
      -e ANSIBLE_TAGS=step1 \\
      -e TARGET_HOSTS=cisco-switch-01 \\
      -e MAX_CONCURRENT=5 \\
      ghcr.io/garryshtern/network-device-upgrade-system:latest dry-run

    # Step 5: Pre-upgrade validation (auto-runs steps 1-4 as prerequisites)
    docker run --rm \\
      -e ANSIBLE_TAGS=step5 \\
      -e TARGET_FIRMWARE=nxos.10.2.3.bin \\
      -e TARGET_HOSTS=cisco-switch-01 \\
      -e MAX_CONCURRENT=5 \\
      ghcr.io/garryshtern/network-device-upgrade-system:latest dry-run

    # Step 6: Firmware installation (auto-runs steps 1-5 as prerequisites)
    docker run --rm \\
      -e ANSIBLE_TAGS=step6 \\
      -e TARGET_FIRMWARE=nxos.10.2.3.bin \\
      -e TARGET_HOSTS=cisco-switch-01 \\
      -e MAX_CONCURRENT=5 \\
      -e MAINTENANCE_WINDOW=true \\
      ghcr.io/garryshtern/network-device-upgrade-system:latest run

    # Step 7: Post-upgrade validation (requires step5 baseline from previous run)
    docker run --rm \\
      -e ANSIBLE_TAGS=step7 \\
      -e TARGET_HOSTS=cisco-switch-01 \\
      -e MAX_CONCURRENT=5 \\
      ghcr.io/garryshtern/network-device-upgrade-system:latest run

    # SSH key authentication (recommended)
    docker run --rm \\
      -v ~/.ssh/id_rsa_cisco:/keys/cisco-key:ro \\
      -v ~/.ssh/id_rsa_opengear:/keys/opengear-key:ro \\
      -e CISCO_NXOS_SSH_KEY=/keys/cisco-key \\
      -e OPENGEAR_SSH_KEY=/keys/opengear-key \\
      -e TARGET_HOSTS=cisco-datacenter-switches \\
      -e MAX_CONCURRENT=5 \\
      ghcr.io/garryshtern/network-device-upgrade-system:latest dry-run

    # API token authentication (FortiOS/Opengear API)
    docker run --rm \\
      -e FORTIOS_API_TOKEN="\$(cat ~/.secrets/fortios-token)" \\
      -e OPENGEAR_API_TOKEN="\$(cat ~/.secrets/opengear-token)" \\
      -e TARGET_HOSTS=fortinet-firewalls \\
      -e MAX_CONCURRENT=5 \\
      ghcr.io/garryshtern/network-device-upgrade-system:latest dry-run

    # Run with custom inventory
    docker run --rm \\
      -v /path/to/inventory:/opt/inventory:ro \\
      -e INVENTORY_FILE=/opt/inventory/production.yml \\
      -e MAX_CONCURRENT=5 \\
      ghcr.io/garryshtern/network-device-upgrade-system:latest dry-run

    # Production deployment with all authentication methods
    docker run --rm \\
      -v /opt/secrets/ssh-keys:/keys:ro \\
      -v /opt/inventory:/opt/inventory:ro \\
      -e INVENTORY_FILE=/opt/inventory/production.yml \\
      -e TARGET_HOSTS=cisco-datacenter-switches \\
      -e TARGET_FIRMWARE=9.3.12 \\
      -e MAX_CONCURRENT=5 \\
      -e UPGRADE_PHASE=loading \\
      -e CISCO_NXOS_SSH_KEY=/keys/cisco-nxos-key \\
      -e CISCO_IOSXE_SSH_KEY=/keys/cisco-iosxe-key \\
      -e FORTIOS_API_TOKEN="\$(cat /opt/secrets/fortios-api-token)" \\
      ghcr.io/garryshtern/network-device-upgrade-system:latest dry-run

    # Interactive shell for debugging
    docker run --rm -it \\
      ghcr.io/garryshtern/network-device-upgrade-system:latest shell

    # Run test suite
    docker run --rm \\
      ghcr.io/garryshtern/network-device-upgrade-system:latest test

    # Enable debug output with verbose Ansible display
    docker run --rm \\
      -e SHOW_DEBUG=true \\
      -e TARGET_HOSTS=cisco-switch-01 \\
      -e TARGET_FIRMWARE=nxos64-cs.10.4.5.M.bin \\
      -e MAX_CONCURRENT=5 \\
      ghcr.io/garryshtern/network-device-upgrade-system:latest dry-run

PODMAN COMPATIBILITY (RHEL8/9):
    # Run with podman (rootless)
    podman run --rm -it \\
      ghcr.io/garryshtern/network-device-upgrade-system:latest syntax-check

    # Mount external inventory with podman (SELinux compatible)
    podman run --rm \\
      -v ./inventory:/opt/inventory:ro,Z \\
      -e INVENTORY_FILE=/opt/inventory/hosts.yml \\
      ghcr.io/garryshtern/network-device-upgrade-system:latest dry-run

    # SSH keys with podman (SELinux context)
    podman run --rm \\
      -v ~/.ssh/id_rsa_cisco:/keys/cisco-key:ro,Z \\
      -e CISCO_NXOS_SSH_KEY=/keys/cisco-key \\
      ghcr.io/garryshtern/network-device-upgrade-system:latest dry-run

AUTHENTICATION PRIORITY ORDER:
    1. SSH Keys (Preferred for SSH-based platforms)
       - Cisco NX-OS, IOS-XE, Metamako MOS, Opengear SSH
    2. API Tokens (Preferred for API-based platforms)
       - FortiOS API, Opengear REST API
    3. Username/Password (Fallback when keys/tokens unavailable)

PLATFORM SUPPORT:
    ✓ Cisco NX-OS (SSH + SSH Key authentication)
    ✓ Cisco IOS-XE (SSH + SSH Key authentication)
    ✓ FortiOS (HTTPS API + API Token authentication)
    ✓ Opengear (SSH + REST API + SSH Key/API Token authentication)
    ✓ Metamako MOS (SSH + SSH Key authentication)

UPGRADE PHASES:
    - full: Complete upgrade workflow (default)
    - loading: Firmware transfer and validation only
    - installation: Firmware installation and reboot
    - validation: Post-upgrade validation checks
    - rollback: Rollback to previous firmware version

TROUBLESHOOTING:
    # Check container environment
    docker run --rm -it \\
      ghcr.io/garryshtern/network-device-upgrade-system:latest shell

    # Validate SSH key permissions (must be 600)
    ls -la ~/.ssh/id_rsa_cisco
    chmod 600 ~/.ssh/id_rsa_cisco

    # Test connectivity without changes
    docker run --rm \\
      -v ~/.ssh/id_rsa_cisco:/keys/cisco-key:ro \\
      -e CISCO_NXOS_SSH_KEY=/keys/cisco-key \\
      -e TARGET_HOSTS=test-device \\
      ghcr.io/garryshtern/network-device-upgrade-system:latest dry-run

    # View detailed Ansible output
    docker run --rm \\
      -e ANSIBLE_VERBOSITY=2 \\
      ghcr.io/garryshtern/network-device-upgrade-system:latest dry-run

SECURITY BEST PRACTICES:
    - Container runs as non-root user 'ansible' (UID 1000)
    - Compatible with rootless podman on RHEL8/9
    - Always use read-only mounts (:ro) for SSH keys and inventory
    - Set SSH key permissions to 600 before mounting
    - Store API tokens in external secret management systems
    - Use different SSH keys per platform/environment
    - Regularly rotate SSH keys and API tokens
    - Never log or print SSH keys or API tokens
    - Use SELinux context (:Z) with podman for proper labeling
    - Mount vault password files securely with appropriate permissions

DOCUMENTATION:
    For detailed platform-specific configuration, see:
    https://github.com/garryshtern/network-device-upgrade-system/tree/main/docs

EOF
}

# Validate environment (old version - removed, see line 686 for current implementation with TARGET_HOSTS validation)

# Execute syntax check (old version - removed, see line 715 for current implementation)

# Setup SSH key variables (keys already copied by root process)
setup_ssh_keys() {
    local keys_dir="/home/ansible/.ssh"

    # Set internal SSH key variables to point to copied keys
    if [[ -n "${CISCO_NXOS_SSH_KEY:-}" ]] && [[ -f "$keys_dir/cisco_nxos_key" ]]; then
        export CISCO_NXOS_SSH_KEY_INTERNAL="$keys_dir/cisco_nxos_key"
    fi

    if [[ -n "${CISCO_IOSXE_SSH_KEY:-}" ]] && [[ -f "$keys_dir/cisco_iosxe_key" ]]; then
        export CISCO_IOSXE_SSH_KEY_INTERNAL="$keys_dir/cisco_iosxe_key"
    fi

    if [[ -n "${OPENGEAR_SSH_KEY:-}" ]] && [[ -f "$keys_dir/opengear_key" ]]; then
        export OPENGEAR_SSH_KEY_INTERNAL="$keys_dir/opengear_key"
    fi

    if [[ -n "${METAMAKO_SSH_KEY:-}" ]] && [[ -f "$keys_dir/metamako_key" ]]; then
        export METAMAKO_SSH_KEY_INTERNAL="$keys_dir/metamako_key"
    fi
}

# Build authentication and configuration options
build_ansible_options() {
    local ansible_opts=""
    local extra_vars=""

    # Setup SSH keys first
    setup_ssh_keys

    # Add tags if specified
    if [[ -n "${ANSIBLE_TAGS:-}" ]]; then
        ansible_opts="$ansible_opts --tags ${ANSIBLE_TAGS}"
        log "Workflow tags: ${ANSIBLE_TAGS}"
    fi

    # Authentication: SSH Keys (highest priority)
    if [[ -n "${CISCO_NXOS_SSH_KEY_INTERNAL:-}" ]]; then
        extra_vars="$extra_vars vault_cisco_nxos_ssh_key=${CISCO_NXOS_SSH_KEY_INTERNAL}"
    fi

    if [[ -n "${CISCO_IOSXE_SSH_KEY_INTERNAL:-}" ]]; then
        extra_vars="$extra_vars vault_cisco_iosxe_ssh_key=${CISCO_IOSXE_SSH_KEY_INTERNAL}"
    fi

    if [[ -n "${OPENGEAR_SSH_KEY_INTERNAL:-}" ]]; then
        extra_vars="$extra_vars vault_opengear_ssh_key=${OPENGEAR_SSH_KEY_INTERNAL}"
    fi

    if [[ -n "${METAMAKO_SSH_KEY_INTERNAL:-}" ]]; then
        extra_vars="$extra_vars vault_metamako_ssh_key=${METAMAKO_SSH_KEY_INTERNAL}"
    fi

    # Authentication: API Tokens
    if [[ -n "${FORTIOS_API_TOKEN:-}" ]]; then
        extra_vars="$extra_vars vault_fortios_api_token=${FORTIOS_API_TOKEN}"
    fi

    if [[ -n "${OPENGEAR_API_TOKEN:-}" ]]; then
        extra_vars="$extra_vars vault_opengear_api_token=${OPENGEAR_API_TOKEN}"
    fi

    # Authentication: Usernames and Passwords (fallback)
    if [[ -n "${CISCO_NXOS_USERNAME:-}" ]]; then
        extra_vars="$extra_vars vault_cisco_nxos_username=${CISCO_NXOS_USERNAME}"
    fi
    if [[ -n "${CISCO_NXOS_PASSWORD:-}" ]]; then
        extra_vars="$extra_vars vault_cisco_nxos_password=${CISCO_NXOS_PASSWORD}"
    fi

    if [[ -n "${CISCO_IOSXE_USERNAME:-}" ]]; then
        extra_vars="$extra_vars vault_cisco_iosxe_username=${CISCO_IOSXE_USERNAME}"
    fi
    if [[ -n "${CISCO_IOSXE_PASSWORD:-}" ]]; then
        extra_vars="$extra_vars vault_cisco_iosxe_password=${CISCO_IOSXE_PASSWORD}"
    fi

    if [[ -n "${FORTIOS_USERNAME:-}" ]]; then
        extra_vars="$extra_vars vault_fortios_username=${FORTIOS_USERNAME}"
    fi
    if [[ -n "${FORTIOS_PASSWORD:-}" ]]; then
        extra_vars="$extra_vars vault_fortios_password=${FORTIOS_PASSWORD}"
    fi

    if [[ -n "${OPENGEAR_USERNAME:-}" ]]; then
        extra_vars="$extra_vars vault_opengear_username=${OPENGEAR_USERNAME}"
    fi
    if [[ -n "${OPENGEAR_PASSWORD:-}" ]]; then
        extra_vars="$extra_vars vault_opengear_password=${OPENGEAR_PASSWORD}"
    fi

    if [[ -n "${METAMAKO_USERNAME:-}" ]]; then
        extra_vars="$extra_vars vault_metamako_username=${METAMAKO_USERNAME}"
    fi
    if [[ -n "${METAMAKO_PASSWORD:-}" ]]; then
        extra_vars="$extra_vars vault_metamako_password=${METAMAKO_PASSWORD}"
    fi

    # Image server authentication
    if [[ -n "${IMAGE_SERVER_USERNAME:-}" ]]; then
        extra_vars="$extra_vars vault_image_server_username=${IMAGE_SERVER_USERNAME}"
    fi
    if [[ -n "${IMAGE_SERVER_PASSWORD:-}" ]]; then
        extra_vars="$extra_vars vault_image_server_password=${IMAGE_SERVER_PASSWORD}"
    fi

    # SNMP Configuration
    if [[ -n "${SNMP_COMMUNITY:-}" ]]; then
        extra_vars="$extra_vars vault_snmp_community=${SNMP_COMMUNITY}"
    fi

    # Core upgrade variables
    [[ -n "${TARGET_HOSTS:-}" ]] && extra_vars="$extra_vars target_hosts=${TARGET_HOSTS}"
    [[ -n "${TARGET_FIRMWARE:-}" ]] && extra_vars="$extra_vars target_firmware=${TARGET_FIRMWARE}"
    [[ -n "${UPGRADE_PHASE:-}" ]] && extra_vars="$extra_vars upgrade_phase=${UPGRADE_PHASE}"

    # Serial execution limit (REQUIRED - processed before group_vars)
    [[ -n "${MAX_CONCURRENT:-}" ]] && extra_vars="$extra_vars max_concurrent=${MAX_CONCURRENT}"

    # Maintenance window (default: false in group_vars)
    # Only set if explicitly set to true (safety feature)
    if [[ "${MAINTENANCE_WINDOW:-false}" == "true" ]]; then
        extra_vars="$extra_vars maintenance_window=true"
    fi

    # Storage configuration
    if [[ -n "${REQUIRED_SPACE_GB:-}" ]]; then
        extra_vars="$extra_vars required_space_gb=${REQUIRED_SPACE_GB}"
    fi

    # EPLD upgrade configuration (default: false in group_vars)
    # Only set if explicitly set to true
    if [[ "${ENABLE_EPLD_UPGRADE:-false}" == "true" ]]; then
        extra_vars="$extra_vars enable_epld_upgrade=true"
    fi
    if [[ "${ALLOW_DISRUPTIVE_EPLD:-false}" == "true" ]]; then
        extra_vars="$extra_vars allow_disruptive_epld=true"
    fi
    if [[ -n "${EPLD_UPGRADE_TIMEOUT:-}" ]]; then
        extra_vars="$extra_vars epld_upgrade_timeout=${EPLD_UPGRADE_TIMEOUT}"
    fi
    # Accept both TARGET_EPLD_IMAGE and TARGET_EPLD_FIRMWARE (TARGET_EPLD_IMAGE takes precedence)
    local target_epld_image="${TARGET_EPLD_IMAGE:-${TARGET_EPLD_FIRMWARE:-}}"
    if [[ -n "$target_epld_image" ]]; then
        extra_vars="$extra_vars target_epld_image=${target_epld_image}"
    fi

    # Multi-step upgrade (FortiOS - default: false in group_vars/fortios.yml)
    # Only set if explicitly set to true
    if [[ "${MULTI_STEP_UPGRADE_REQUIRED:-false}" == "true" ]]; then
        extra_vars="$extra_vars multi_step_upgrade_required=true"
    fi
    if [[ -n "${UPGRADE_PATH:-}" ]]; then
        extra_vars="$extra_vars upgrade_path=${UPGRADE_PATH}"
    fi

    # Debug configuration (default: false in group_vars/all.yml)
    # Only override if explicitly set to true
    if [[ "${SHOW_DEBUG:-false}" == "true" ]]; then
        extra_vars="$extra_vars show_debug=true"
        log "Debug mode enabled: show_debug=true"
    fi

    # Base path and derived paths
    if [[ -n "${NETWORK_UPGRADE_BASE_PATH:-}" ]]; then
        extra_vars="$extra_vars network_upgrade_base_path=${NETWORK_UPGRADE_BASE_PATH}"
    fi
    if [[ -n "${FIRMWARE_BASE_PATH:-}" ]]; then
        extra_vars="$extra_vars firmware_base_path=${FIRMWARE_BASE_PATH}"
    fi
    if [[ -n "${BACKUP_BASE_PATH:-}" ]]; then
        extra_vars="$extra_vars backup_base_path=${BACKUP_BASE_PATH}"
    fi

    # Ansible configuration
    # Always set ANSIBLE_CONFIG to ensure proper paths and group_vars discovery
    if [[ -z "${ANSIBLE_CONFIG:-}" ]]; then
        export ANSIBLE_CONFIG="ansible-content/ansible.cfg"
    fi

    if [[ -n "${ANSIBLE_VAULT_PASSWORD_FILE:-}" ]]; then
        ansible_opts="$ansible_opts --vault-password-file ${ANSIBLE_VAULT_PASSWORD_FILE}"
    fi

    # Set verbosity if requested
    if [[ -n "${ANSIBLE_VERBOSITY:-}" ]]; then
        case "${ANSIBLE_VERBOSITY}" in
            1) ansible_opts="$ansible_opts -v" ;;
            2) ansible_opts="$ansible_opts -vv" ;;
            3) ansible_opts="$ansible_opts -vvv" ;;
            4) ansible_opts="$ansible_opts -vvvv" ;;
        esac
    fi

    # Override path variables with container-specific defaults
    # All other defaults come from group_vars/all.yml loaded via -e @file
    if [[ ! "$extra_vars" =~ network_upgrade_base_path ]]; then
        extra_vars="network_upgrade_base_path=${DEFAULT_BASE_PATH} ${extra_vars}"
    fi
    if [[ ! "$extra_vars" =~ firmware_base_path ]]; then
        extra_vars="firmware_base_path=${DEFAULT_FIRMWARE_PATH} ${extra_vars}"
    fi
    if [[ ! "$extra_vars" =~ backup_base_path ]]; then
        extra_vars="backup_base_path=${DEFAULT_BACKUP_PATH} ${extra_vars}"
    fi

    echo "$ansible_opts|$extra_vars"
}

# Setup inventory - create symlink to custom inventory if provided
setup_inventory() {
    local ansible_inventory_dir="ansible-content/inventory"
    local ansible_inventory="${ansible_inventory_dir}/hosts.yml"

    # If user provided INVENTORY_FILE, symlink it to hosts.yml
    if [[ -n "${INVENTORY_FILE:-}" ]]; then
        log "Creating symlink for custom inventory"
        log "  Source: ${INVENTORY_FILE}"
        log "  Target: ${ansible_inventory}"

        # Validate user inventory exists
        if [[ ! -f "${INVENTORY_FILE}" ]]; then
            error "Inventory file not found: ${INVENTORY_FILE}"
            error "Make sure to mount your inventory file to the container"
            error "Example: -v /path/to/inventory.yml:/opt/inventory/hosts.yml:ro"
            error "Then specify it with: -e INVENTORY_FILE=/opt/inventory/hosts.yml"
            exit 1
        fi

        # Remove existing symlink/file if it exists
        rm -f "${ansible_inventory}" 2>/dev/null || true

        # Create symlink
        if ln -sf "${INVENTORY_FILE}" "${ansible_inventory}" 2>/dev/null; then
            log "  Symlink created successfully"
        else
            error "Failed to create inventory symlink"
            exit 1
        fi
    else
        log "Using default inventory: ${ansible_inventory}"
    fi
}

# Common function to execute ansible-playbook with shared logic
execute_ansible_playbook() {
    local mode="$1"  # "syntax-check", "dry-run", or "run"
    local playbook="${ANSIBLE_PLAYBOOK:-$DEFAULT_PLAYBOOK}"

    # Use ansible-content/inventory directory with explicit config
    # This ensures group_vars is discovered in the inventory directory
    local ansible_inventory_dir="ansible-content/inventory"
    local ansible_inventory="${ansible_inventory_dir}/hosts.yml"

    # Mode-specific logging
    case "$mode" in
        syntax-check)
            log "Running syntax check on: $playbook"
            ;;
        dry-run)
            log "Running dry run on: $playbook"
            ;;
        run)
            warn "EXECUTING ACTUAL PLAYBOOK - CHANGES WILL BE MADE"
            log "Running playbook: $playbook"
            ;;
    esac

    # Build authentication and configuration
    local opts_and_vars
    opts_and_vars=$(build_ansible_options)
    local ansible_opts="${opts_and_vars%|*}"
    local extra_vars="${opts_and_vars#*|}"

    # Add mode-specific extra vars
    if [[ "$mode" == "syntax-check" ]]; then
        if [[ ! "$extra_vars" =~ target_hosts ]]; then
            extra_vars="target_hosts=localhost ${extra_vars}"
        fi
        if [[ ! "$extra_vars" =~ target_firmware ]]; then
            extra_vars="target_firmware=test.bin ${extra_vars}"
        fi
        if [[ ! "$extra_vars" =~ max_concurrent ]]; then
            extra_vars="max_concurrent=5 ${extra_vars}"
        fi
    else
        # For dry-run and run modes, max_concurrent is REQUIRED
        if [[ ! "$extra_vars" =~ max_concurrent ]]; then
            error "max_concurrent is REQUIRED for playbook execution"
            error "The 'serial' keyword is processed before group_vars are loaded"
            error "You must provide max_concurrent as an extra variable:"
            error "  Example: -e MAX_CONCURRENT=5"
            exit 1
        fi
    fi

    log "Extra variables: $extra_vars"

    # Debug: Show key authentication variables
    if [[ "$extra_vars" =~ vault_cisco_nxos_username=([^[:space:]]+) ]]; then
        log "DEBUG: CISCO_NXOS_USERNAME is set to: ${BASH_REMATCH[1]}"
    else
        warn "DEBUG: CISCO_NXOS_USERNAME is NOT set in extra_vars"
    fi

    # Execute ansible-playbook with mode-specific flags
    # Using ansible-content/inventory/hosts.yml ensures group_vars/all.yml is discovered
    # group_vars must be in same directory as inventory file for Ansible to find it
    case "$mode" in
        syntax-check)
            ansible-playbook \
                --syntax-check \
                -i "$ansible_inventory" \
                ${ansible_opts} \
                ${extra_vars:+--extra-vars "$extra_vars"} \
                "$playbook"
            success "Syntax check completed successfully"
            ;;
        dry-run)
            ansible-playbook \
                --check --diff \
                -i "$ansible_inventory" \
                ${ansible_opts} \
                ${extra_vars:+--extra-vars "$extra_vars"} \
                "$playbook"
            success "Dry run completed successfully"
            ;;
        run)
            ansible-playbook \
                -i "$ansible_inventory" \
                ${ansible_opts} \
                ${extra_vars:+--extra-vars "$extra_vars"} \
                "$playbook"
            success "Playbook execution completed"
            ;;
    esac
}

# Execute dry run (check mode)
run_dry_run() {
    execute_ansible_playbook "dry-run"
}

# Execute actual run
run_playbook() {
    execute_ansible_playbook "run"
}

# Run test suite (old version - removed, see line 741 for current implementation)

# Start interactive shell or execute command
start_shell() {
    # If -c flag is provided, execute the command
    if [[ $# -gt 1 && "$2" == "-c" ]]; then
        shift 2  # Remove 'shell' and '-c' from arguments
        log "Executing shell command: $*"
        exec /bin/bash -c "$*"
    # If other arguments provided, execute them directly
    elif [[ $# -gt 1 ]]; then
        shift  # Remove 'shell' from arguments
        log "Executing command: $*"
        exec "$@"
    else
        log "Starting interactive shell..."
        log "Working directory: $(pwd)"
        log "Ansible version: $(ansible --version | head -1)"
        log "Collections installed:"
        ansible-galaxy collection list | head -10
        echo
        warn "You are now in the container shell. Type 'exit' to leave."

        exec /bin/bash
    fi
}

# Validate TARGET_HOSTS against inventory
validate_target_hosts() {
    local inventory="${INVENTORY_FILE:-$DEFAULT_INVENTORY}"
    local target_hosts="${TARGET_HOSTS:-}"

    # If no TARGET_HOSTS specified, validation passes
    if [[ -z "$target_hosts" ]]; then
        return 0
    fi

    # If TARGET_HOSTS is 'all', validation passes
    if [[ "$target_hosts" == "all" ]]; then
        return 0
    fi

    # Check if inventory file exists
    if [[ ! -f "$inventory" ]]; then
        error "TARGET_HOSTS specified but inventory file not found: $inventory"
        error "When using TARGET_HOSTS, you MUST mount an inventory file."
        error "Example: -v /path/to/inventory.yml:/opt/inventory/hosts.yml:ro"
        error "         -e INVENTORY_FILE=/opt/inventory/hosts.yml"
        return 1
    fi

    log "Validating TARGET_HOSTS against inventory: $inventory"

    # Split TARGET_HOSTS by comma and validate each host
    IFS=',' read -ra hosts <<< "$target_hosts"
    local validation_failed=false
    local missing_hosts=()

    for host in "${hosts[@]}"; do
        # Trim whitespace
        host=$(echo "$host" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # Skip empty hosts
        if [[ -z "$host" ]]; then
            continue
        fi

        # Check if host exists in inventory using ansible-inventory
        if ! ansible-inventory -i "$inventory" --list 2>/dev/null | grep -q "\"$host\""; then
            missing_hosts+=("$host")
            validation_failed=true
        fi
    done

    if [[ "$validation_failed" == true ]]; then
        error "TARGET_HOSTS validation failed. The following hosts are not defined in inventory:"
        for missing_host in "${missing_hosts[@]}"; do
            error "  - $missing_host"
        done
        error "Please ensure all target hosts are defined in your inventory file: $inventory"
        error "You can check your inventory with: ansible-inventory -i $inventory --list"
        return 1
    fi

    success "TARGET_HOSTS validation passed. All hosts found in inventory."
    return 0
}

# Validate environment and dependencies
validate_environment() {
    log "Validating environment..."

    # Check Ansible installation
    if ! command -v ansible-playbook &> /dev/null; then
        error "Ansible not found in container"
        exit 1
    fi

    # Check ansible-galaxy command
    if ! command -v ansible-galaxy &> /dev/null; then
        error "ansible-galaxy command not found in container"
        exit 1
    fi

    # Verify working directory structure
    if [[ ! -d "ansible-content" ]]; then
        error "Ansible content directory not found"
        exit 1
    fi

    if [[ ! -d "ansible-content/playbooks" ]]; then
        error "Ansible playbooks directory not found"
        exit 1
    fi

    # Check for main playbook
    if [[ ! -f "${DEFAULT_PLAYBOOK}" ]]; then
        error "Default playbook not found: ${DEFAULT_PLAYBOOK}"
        exit 1
    fi

    # Validate TARGET_HOSTS against inventory
    if ! validate_target_hosts; then
        exit 1
    fi

    success "Environment validation completed"
}

# Execute syntax check
run_syntax_check() {
    execute_ansible_playbook "syntax-check"
}

# Run comprehensive test suite
run_tests() {
    log "Running comprehensive test suite..."

    # Check if test runner exists
    if [[ -f "/opt/app/tests/run-all-tests.sh" ]]; then
        log "Executing test runner: /opt/app/tests/run-all-tests.sh"
        /opt/app/tests/run-all-tests.sh
    else
        warn "Test runner not found. Running basic validation tests..."

        # Basic validation tests
        log "Testing Ansible installation..."
        ansible --version

        log "Testing Ansible collections..."
        ansible-galaxy collection list

        log "Testing syntax check..."
        run_syntax_check

        success "Basic validation tests completed"
    fi
}

# Main execution logic
main() {
    local command="${1:-syntax-check}"

    # Handle help first
    if [[ "$command" == "help" ]] || [[ "$command" == "--help" ]] || [[ "$command" == "-h" ]]; then
        usage
        exit 0
    fi

    # Setup inventory (create symlink if custom inventory provided)
    # Must be done BEFORE validate_environment which checks TARGET_HOSTS against inventory
    setup_inventory

    # Validate environment
    validate_environment

    # Execute command
    case "$command" in
        "syntax-check")
            run_syntax_check
            ;;
        "dry-run")
            run_dry_run
            ;;
        "run")
            run_playbook
            ;;
        "test")
            run_tests
            ;;
        "shell")
            start_shell "$@"
            ;;
        *)
            error "Unknown command: $command"
            echo
            usage
            exit 1
            ;;
    esac
}

# Handle privilege drop (root -> ansible user) before main execution
handle_privilege_drop "$@"

# Execute main function with all arguments
main "$@"