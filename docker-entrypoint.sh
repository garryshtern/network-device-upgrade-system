#!/bin/bash
# Network Device Upgrade System - Container Entrypoint
# Provides flexible execution modes for Ansible playbooks

set -euo pipefail

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

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
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
    ANSIBLE_INVENTORY  Inventory file (default: ${DEFAULT_INVENTORY})
    ANSIBLE_CONFIG     Path to ansible.cfg file
    ANSIBLE_VAULT_PASSWORD_FILE  Path to vault password file

    # Upgrade Configuration
    TARGET_HOSTS       Hosts to target (default: all)
    TARGET_FIRMWARE    Firmware version to install
    UPGRADE_PHASE      Phase: full, loading, installation, validation, rollback
    MAINTENANCE_WINDOW Set to 'true' for installation phase

    # SSH Key Authentication (Preferred)
    VAULT_CISCO_NXOS_SSH_KEY    SSH private key for Cisco NX-OS devices
    VAULT_CISCO_IOSXE_SSH_KEY   SSH private key for Cisco IOS-XE devices
    VAULT_OPENGEAR_SSH_KEY      SSH private key for Opengear devices
    VAULT_METAMAKO_SSH_KEY      SSH private key for Metamako devices

    # API Token Authentication (API-based platforms)
    VAULT_FORTIOS_API_TOKEN     API token for FortiOS devices
    VAULT_OPENGEAR_API_TOKEN    API token for Opengear REST API

    # Password Authentication (Fallback)
    VAULT_CISCO_NXOS_PASSWORD   Password for Cisco NX-OS devices
    VAULT_CISCO_IOSXE_PASSWORD  Password for Cisco IOS-XE devices
    VAULT_FORTIOS_PASSWORD      Password for FortiOS devices
    VAULT_OPENGEAR_PASSWORD     Password for Opengear devices
    VAULT_METAMAKO_PASSWORD     Password for Metamako devices

    # Username Configuration
    VAULT_CISCO_NXOS_USERNAME   Username for Cisco NX-OS devices
    VAULT_CISCO_IOSXE_USERNAME  Username for Cisco IOS-XE devices
    VAULT_FORTIOS_USERNAME      Username for FortiOS devices
    VAULT_OPENGEAR_USERNAME     Username for Opengear devices
    VAULT_METAMAKO_USERNAME     Username for Metamako devices

    # Additional Configuration
    VAULT_IMAGE_SERVER_USERNAME Username for firmware image server
    VAULT_IMAGE_SERVER_PASSWORD Password for firmware image server
    VAULT_SNMP_COMMUNITY        SNMP community string for monitoring

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
      ghcr.io/garryshtern/network-device-upgrade-system:latest dry-run

    # Execute actual upgrade (production)
    docker run --rm \\
      -e TARGET_FIRMWARE=9.3.12 -e TARGET_HOSTS=cisco-switch-01 \\
      -e UPGRADE_PHASE=loading -e MAINTENANCE_WINDOW=false \\
      ghcr.io/garryshtern/network-device-upgrade-system:latest run

    # SSH key authentication (recommended)
    docker run --rm \\
      -v ~/.ssh/id_rsa_cisco:/keys/cisco-key:ro \\
      -v ~/.ssh/id_rsa_opengear:/keys/opengear-key:ro \\
      -e VAULT_CISCO_NXOS_SSH_KEY=/keys/cisco-key \\
      -e VAULT_OPENGEAR_SSH_KEY=/keys/opengear-key \\
      -e TARGET_HOSTS=cisco-datacenter-switches \\
      ghcr.io/garryshtern/network-device-upgrade-system:latest dry-run

    # API token authentication (FortiOS/Opengear API)
    docker run --rm \\
      -e VAULT_FORTIOS_API_TOKEN="\$(cat ~/.secrets/fortios-token)" \\
      -e VAULT_OPENGEAR_API_TOKEN="\$(cat ~/.secrets/opengear-token)" \\
      -e TARGET_HOSTS=fortinet-firewalls \\
      ghcr.io/garryshtern/network-device-upgrade-system:latest dry-run

    # Run with custom inventory
    docker run --rm \\
      -v /path/to/inventory:/opt/inventory:ro \\
      -e ANSIBLE_INVENTORY=/opt/inventory/production.yml \\
      ghcr.io/garryshtern/network-device-upgrade-system:latest dry-run

    # Production deployment with all authentication methods
    docker run --rm \\
      -v /opt/secrets/ssh-keys:/keys:ro \\
      -v /opt/inventory:/opt/inventory:ro \\
      -e ANSIBLE_INVENTORY=/opt/inventory/production.yml \\
      -e TARGET_HOSTS=cisco-datacenter-switches \\
      -e TARGET_FIRMWARE=9.3.12 \\
      -e UPGRADE_PHASE=loading \\
      -e VAULT_CISCO_NXOS_SSH_KEY=/keys/cisco-nxos-key \\
      -e VAULT_CISCO_IOSXE_SSH_KEY=/keys/cisco-iosxe-key \\
      -e VAULT_FORTIOS_API_TOKEN="\$(cat /opt/secrets/fortios-api-token)" \\
      ghcr.io/garryshtern/network-device-upgrade-system:latest dry-run

    # Interactive shell for debugging
    docker run --rm -it \\
      ghcr.io/garryshtern/network-device-upgrade-system:latest shell

    # Run test suite
    docker run --rm \\
      ghcr.io/garryshtern/network-device-upgrade-system:latest test

PODMAN COMPATIBILITY (RHEL8/9):
    # Run with podman (rootless)
    podman run --rm -it \\
      ghcr.io/garryshtern/network-device-upgrade-system:latest syntax-check

    # Mount external inventory with podman (SELinux compatible)
    podman run --rm \\
      -v ./inventory:/opt/inventory:ro,Z \\
      -e ANSIBLE_INVENTORY=/opt/inventory/hosts.yml \\
      ghcr.io/garryshtern/network-device-upgrade-system:latest dry-run

    # SSH keys with podman (SELinux context)
    podman run --rm \\
      -v ~/.ssh/id_rsa_cisco:/keys/cisco-key:ro,Z \\
      -e VAULT_CISCO_NXOS_SSH_KEY=/keys/cisco-key \\
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
      -e VAULT_CISCO_NXOS_SSH_KEY=/keys/cisco-key \\
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

# Validate environment
validate_environment() {
    log "Validating container environment..."

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

    # Check Ansible collections with more robust validation
    local collections_check=false
    if ansible-galaxy collection list --collections-path ~/.ansible/collections &> /dev/null; then
        collections_check=true
    elif [[ -d ~/.ansible/collections ]] && [[ $(find ~/.ansible/collections -name "*.yml" -o -name "*.yaml" | wc -l) -gt 0 ]]; then
        warn "Collections list command failed but collections exist - proceeding with caution"
        collections_check=true
    fi

    if [[ "$collections_check" != "true" ]]; then
        error "Ansible collections not properly installed"
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

    # Verify Ansible configuration
    if [[ -n "${ANSIBLE_CONFIG}" ]] && [[ ! -f "${ANSIBLE_CONFIG}" ]]; then
        warn "ANSIBLE_CONFIG points to non-existent file: ${ANSIBLE_CONFIG}"
    fi

    success "Environment validation passed"
}

# Execute syntax check
run_syntax_check() {
    local playbook="${ANSIBLE_PLAYBOOK:-$DEFAULT_PLAYBOOK}"
    log "Running syntax check on: $playbook"
    
    ansible-playbook --syntax-check "$playbook"
    success "Syntax check completed successfully"
}

# Execute dry run (check mode)
run_dry_run() {
    local playbook="${ANSIBLE_PLAYBOOK:-$DEFAULT_PLAYBOOK}"
    local inventory="${ANSIBLE_INVENTORY:-$DEFAULT_INVENTORY}"
    
    log "Running dry run on: $playbook"
    log "Using inventory: $inventory"
    
    local extra_vars=""
    [[ -n "${TARGET_HOSTS:-}" ]] && extra_vars="$extra_vars target_hosts=${TARGET_HOSTS}"
    [[ -n "${TARGET_FIRMWARE:-}" ]] && extra_vars="$extra_vars target_firmware=${TARGET_FIRMWARE}"
    [[ -n "${UPGRADE_PHASE:-}" ]] && extra_vars="$extra_vars upgrade_phase=${UPGRADE_PHASE}"
    [[ -n "${MAINTENANCE_WINDOW:-}" ]] && extra_vars="$extra_vars maintenance_window=${MAINTENANCE_WINDOW}"
    
    ansible-playbook \
        --check --diff \
        -i "$inventory" \
        ${extra_vars:+--extra-vars "$extra_vars"} \
        "$playbook"
    
    success "Dry run completed successfully"
}

# Execute actual run
run_playbook() {
    local playbook="${ANSIBLE_PLAYBOOK:-$DEFAULT_PLAYBOOK}"
    local inventory="${ANSIBLE_INVENTORY:-$DEFAULT_INVENTORY}"
    
    warn "EXECUTING ACTUAL PLAYBOOK - CHANGES WILL BE MADE"
    log "Running playbook: $playbook"
    log "Using inventory: $inventory"
    
    local extra_vars=""
    [[ -n "${TARGET_HOSTS:-}" ]] && extra_vars="$extra_vars target_hosts=${TARGET_HOSTS}"
    [[ -n "${TARGET_FIRMWARE:-}" ]] && extra_vars="$extra_vars target_firmware=${TARGET_FIRMWARE}"
    [[ -n "${UPGRADE_PHASE:-}" ]] && extra_vars="$extra_vars upgrade_phase=${UPGRADE_PHASE}"
    [[ -n "${MAINTENANCE_WINDOW:-}" ]] && extra_vars="$extra_vars maintenance_window=${MAINTENANCE_WINDOW}"
    
    ansible-playbook \
        -i "$inventory" \
        ${extra_vars:+--extra-vars "$extra_vars"} \
        "$playbook"
    
    success "Playbook execution completed"
}

# Run test suite
run_tests() {
    log "Running comprehensive test suite..."
    
    if [[ -x "tests/run-all-tests.sh" ]]; then
        ./tests/run-all-tests.sh
    else
        error "Test runner not found or not executable"
        exit 1
    fi
    
    success "Test suite completed"
}

# Start interactive shell
start_shell() {
    log "Starting interactive shell..."
    log "Working directory: $(pwd)"
    log "Ansible version: $(ansible --version | head -1)"
    log "Collections installed:"
    ansible-galaxy collection list | head -10
    echo
    warn "You are now in the container shell. Type 'exit' to leave."
    
    exec /bin/bash
}

# Main execution logic
main() {
    local command="${1:-syntax-check}"
    
    # Handle help first
    if [[ "$command" == "help" ]] || [[ "$command" == "--help" ]] || [[ "$command" == "-h" ]]; then
        usage
        exit 0
    fi
    
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
            start_shell
            ;;
        *)
            error "Unknown command: $command"
            echo
            usage
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"