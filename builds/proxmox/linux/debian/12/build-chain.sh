#!/usr/bin/env bash
set -euo pipefail

# Script: build-chain.sh
# Purpose: Orchestrate chained Packer builds for Debian 12 templates
# Usage: ./build-chain.sh [base|configured|all] [options]

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${SCRIPT_DIR}/base"
CONFIGURED_DIR="${SCRIPT_DIR}/configured"
COMMON_VARS="${SCRIPT_DIR}/common.auto.pkrvars.hcl"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Helper functions
print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_header() { echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${CYAN}  $1${NC}"; echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

# Function to check if Packer is installed
check_packer() {
    if ! command -v packer &> /dev/null; then
        print_error "Packer is not installed. Please install it first."
        exit 1
    fi
    print_info "Packer version: $(packer version)"
}

# Function to check if common vars file exists
check_common_vars() {
    if [ ! -f "$COMMON_VARS" ]; then
        print_error "Common variables file not found: $COMMON_VARS"
        print_info "Please create it with your Proxmox credentials."
        exit 1
    fi
    print_success "Common variables file found"
}

# Function to build base template
build_base() {
    print_header "Building Base Template (debian-12-base)"
    
    if [ ! -d "$BASE_DIR" ]; then
        print_error "Base directory not found: $BASE_DIR"
        exit 1
    fi
    
    cd "$BASE_DIR"
    print_info "Working directory: $BASE_DIR"
    
    # Initialize Packer
    print_info "Initializing Packer plugins..."
    packer init .
    
    # Validate configuration
    print_info "Validating Packer configuration..."
    packer validate -var-file="$COMMON_VARS" .
    
    # Build
    print_info "Building base template..."
    if packer build -var-file="$COMMON_VARS" -force .; then
        print_success "Base template built successfully!"
        return 0
    else
        print_error "Base template build failed!"
        return 1
    fi
}

# Function to build configured template
build_configured() {
    local ansible_type="${1:-base}"
    local vm_id="${2:-}"
    
    print_header "Building Configured Template (debian-12-${ansible_type})"
    
    if [ ! -d "$CONFIGURED_DIR" ]; then
        print_error "Configured directory not found: $CONFIGURED_DIR"
        exit 1
    fi
    
    cd "$CONFIGURED_DIR"
    print_info "Working directory: $CONFIGURED_DIR"
    
    # Initialize Packer
    print_info "Initializing Packer plugins..."
    packer init .
    
    # Build extra vars
    local extra_vars="-var ansible_host_type=${ansible_type}"
    if [ -n "$vm_id" ]; then
        extra_vars="$extra_vars -var vm_id_configured=${vm_id}"
    fi
    
    # Validate configuration
    print_info "Validating Packer configuration..."
    packer validate -var-file="$COMMON_VARS" $extra_vars .
    
    # Build
    print_info "Building configured template with Ansible role: ${ansible_type}..."
    if packer build -var-file="$COMMON_VARS" $extra_vars -force .; then
        print_success "Configured template built successfully!"
        return 0
    else
        print_error "Configured template build failed!"
        return 1
    fi
}

# Function to display usage
show_usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Commands:
  base                Build only the base template from ISO
  configured [TYPE]   Build configured template by cloning base
                      TYPE: base, docker, database, webserver, monitoring (default: base)
  all                 Build complete chain: base -> configured (base)
  
Options:
  --vm-id ID         Specify VM ID for configured build
  -h, --help         Show this help message

Examples:
  $0 base                           # Build base template only
  $0 configured docker              # Build docker template from base
  $0 configured database --vm-id 9100  # Build database template with specific VM ID
  $0 all                            # Build base and configured (base) templates

Build Chain Order:
  1. base       - Minimal Debian 12 installation from ISO (VM ID: 9000)
  2. configured - Clone base and apply Ansible provisioning

Template Names:
  debian-12-base           - Base template (from ISO)
  debian-12-<type>         - Configured templates (cloned + Ansible)

EOF
}

# Parse arguments
COMMAND="${1:-}"
ANSIBLE_TYPE="base"
VM_ID=""

case "$COMMAND" in
    base)
        shift
        ;;
    configured)
        shift
        ANSIBLE_TYPE="${1:-base}"
        shift || true
        while [[ $# -gt 0 ]]; do
            case $1 in
                --vm-id)
                    VM_ID="$2"
                    shift 2
                    ;;
                *)
                    print_error "Unknown option: $1"
                    show_usage
                    exit 1
                    ;;
            esac
        done
        ;;
    all)
        shift
        ;;
    -h|--help)
        show_usage
        exit 0
        ;;
    "")
        print_error "No command specified"
        show_usage
        exit 1
        ;;
    *)
        print_error "Unknown command: $COMMAND"
        show_usage
        exit 1
        ;;
esac

# Main execution
echo ""
print_header "Debian 12 Packer Build Chain"
echo ""

# Pre-flight checks
check_packer
check_common_vars
echo ""

# Execute builds based on command
case "$COMMAND" in
    base)
        build_base
        ;;
    configured)
        print_info "Ensuring base template exists before building configured..."
        build_configured "$ANSIBLE_TYPE" "$VM_ID"
        ;;
    all)
        print_info "Building complete chain..."
        if build_base; then
            echo ""
            sleep 5  # Give Proxmox time to finalize the template
            build_configured "$ANSIBLE_TYPE" "$VM_ID"
        else
            print_error "Build chain failed at base template"
            exit 1
        fi
        ;;
esac

# Summary
echo ""
print_header "Build Complete"
echo ""
print_success "All requested templates have been built!"
echo ""
print_info "Next steps:"
echo "  • Verify templates in Proxmox UI"
echo "  • Test cloning templates"
echo "  • Build additional configured types (docker, database, webserver, etc.)"
echo ""
