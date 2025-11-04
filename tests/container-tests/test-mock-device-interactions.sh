#!/bin/bash
# Mock Device Interaction Testing
# Tests container interactions with mock devices simulating real network scenarios

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
# Source common test library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.."; pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/test-common.sh"

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.."; pwd)"
MOCKUP_DIR="$SCRIPT_DIR/mockups"
CONTAINER_IMAGE="${CONTAINER_IMAGE:-ghcr.io/garryshtern/network-device-upgrade-system:latest}"

# Test results tracking
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
