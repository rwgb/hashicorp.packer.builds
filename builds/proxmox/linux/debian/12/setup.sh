#!/usr/bin/env bash
set -euo pipefail

# Script: setup.sh
# Purpose: Initialize configuration files from examples
# Usage: ./setup.sh

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Debian 12 Packer Build - Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Function to copy if not exists
copy_if_not_exists() {
    local src=$1
    local dest=$2
    local desc=$3
    
    if [ -f "$dest" ]; then
        print_warning "$desc already exists: $dest"
        return 0
    fi
    
    if [ ! -f "$src" ]; then
        print_warning "Example file not found: $src"
        return 1
    fi
    
    cp "$src" "$dest"
    print_success "Created $desc: $dest"
    return 0
}

# Copy main configuration
print_info "Setting up configuration files..."
echo ""

copy_if_not_exists \
    "${SCRIPT_DIR}/common.auto.pkrvars.hcl.example" \
    "${SCRIPT_DIR}/common.auto.pkrvars.hcl" \
    "Common configuration"

copy_if_not_exists \
    "${SCRIPT_DIR}/variables.auto.pkrvars.hcl.example" \
    "${SCRIPT_DIR}/variables.auto.pkrvars.hcl" \
    "Legacy variables file"

copy_if_not_exists \
    "${SCRIPT_DIR}/base/base.auto.pkrvars.hcl.example" \
    "${SCRIPT_DIR}/base/base.auto.pkrvars.hcl" \
    "Base configuration"

copy_if_not_exists \
    "${SCRIPT_DIR}/configured/configured.auto.pkrvars.hcl.example" \
    "${SCRIPT_DIR}/configured/configured.auto.pkrvars.hcl" \
    "Configured configuration"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_info "Setup complete!"
echo ""
print_warning "IMPORTANT: Edit the following file with your Proxmox credentials:"
echo "  ${SCRIPT_DIR}/common.auto.pkrvars.hcl"
echo ""
print_info "Required settings:"
echo "  • proxmox_host   - Your Proxmox server address"
echo "  • token_id       - API token ID (user@pve!token-name)"
echo "  • token_secret   - API token secret"
echo "  • node           - Proxmox node name"
echo ""
print_info "Then run:"
echo "  ./build-chain.sh base      # Build base template"
echo "  ./build-chain.sh configured docker  # Build configured template"
echo ""
print_info "For more information, see README.md"
echo ""
