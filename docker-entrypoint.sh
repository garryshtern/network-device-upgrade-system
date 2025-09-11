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
    ANSIBLE_PLAYBOOK   Playbook to execute (default: ${DEFAULT_PLAYBOOK})
    ANSIBLE_INVENTORY  Inventory file (default: ${DEFAULT_INVENTORY})
    TARGET_HOSTS       Hosts to target (default: all)
    TARGET_FIRMWARE    Firmware version to install
    UPGRADE_PHASE      Phase: full, loading, installation, validation, rollback
    MAINTENANCE_WINDOW Set to 'true' for installation phase
    ANSIBLE_VAULT_PASSWORD_FILE  Path to vault password file

EXAMPLES:
    # Syntax check (default)
    docker run network-upgrade-system

    # Run syntax check on specific playbook
    docker run -e ANSIBLE_PLAYBOOK=ansible-content/playbooks/health-check.yml \\
               network-upgrade-system syntax-check

    # Dry run upgrade workflow
    docker run -e TARGET_FIRMWARE=9.3.12 -e TARGET_HOSTS=cisco-switch-01 \\
               network-upgrade-system dry-run

    # Execute actual upgrade (production)
    docker run -e TARGET_FIRMWARE=9.3.12 -e TARGET_HOSTS=cisco-switch-01 \\
               -e UPGRADE_PHASE=loading -e MAINTENANCE_WINDOW=false \\
               network-upgrade-system run

    # Run with custom inventory
    docker run -v /path/to/inventory:/opt/inventory:ro \\
               -e ANSIBLE_INVENTORY=/opt/inventory/production.yml \\
               network-upgrade-system dry-run

    # Interactive shell for debugging
    docker run -it network-upgrade-system shell

    # Run test suite
    docker run network-upgrade-system test

PODMAN COMPATIBILITY (RHEL8/9):
    # Run with podman (rootless)
    podman run --rm -it network-upgrade-system syntax-check

    # Mount external inventory with podman
    podman run --rm -v ./inventory:/opt/inventory:Z \\
               -e ANSIBLE_INVENTORY=/opt/inventory/hosts.yml \\
               network-upgrade-system dry-run

SECURITY NOTES:
    - Container runs as non-root user 'ansible' (UID 1000)
    - Compatible with rootless podman on RHEL8/9
    - Mount vault password files securely with appropriate permissions
    - Use read-only mounts for inventory files when possible

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
    
    # Check Ansible collections
    if ! ansible-galaxy collection list --collections-path ~/.ansible/collections &> /dev/null; then
        warn "Ansible collections check failed, attempting basic validation..."
        # Try alternative check
        if [[ ! -d ~/.ansible/collections ]]; then
            error "Ansible collections directory not found"
            exit 1
        fi
        warn "Collections directory exists but list command failed - proceeding with caution"
    fi
    
    # Verify working directory
    if [[ ! -d "ansible-content" ]]; then
        error "Ansible content directory not found"
        exit 1
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