#!/usr/bin/env bash
set -euo pipefail

# Script: proxmox-setup.sh
# Purpose: Create a least-privilege Packer user on Proxmox with API token
# Usage: ./proxmox-setup.sh [proxmox-host-or-ssh-alias] [output-file]

# Configuration
PACKER_USER="packer"
PACKER_ROLE="PVEPackerRole"
PACKER_TOKEN_NAME="packer-token"
PROXMOX_USER="${PROXMOX_USER:-root}"
SSH_CONFIG="${HOME}/.ssh/config"
DEFAULT_OUTPUT_FILE="variables.auto.pkrvars.hcl"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }

# Function to check if SSH config exists and has the host
check_ssh_config() {
    local host=$1
    if [ -f "$SSH_CONFIG" ]; then
        if grep -q "^Host ${host}$" "$SSH_CONFIG" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Function to list SSH config hosts
list_ssh_hosts() {
    if [ -f "$SSH_CONFIG" ]; then
        print_info "Available SSH hosts in ${SSH_CONFIG}:"
        grep "^Host " "$SSH_CONFIG" | awk '{print "  - " $2}' | grep -v "\*"
    fi
}

# Function to validate SSH connection
test_ssh_connection() {
    local ssh_target=$1
    print_info "Testing SSH connection to ${ssh_target}..."
    
    if ssh -o ConnectTimeout=5 -o BatchMode=yes "$ssh_target" "exit" 2>/dev/null; then
        print_success "SSH connection successful"
        return 0
    else
        print_error "SSH connection failed"
        print_warning "Please ensure:"
        echo "  1. SSH key authentication is configured"
        echo "  2. You have root access to the Proxmox host"
        echo "  3. The host is reachable"
        return 1
    fi
}

# Function to get Proxmox version
get_proxmox_version() {
    local ssh_target=$1
    ssh "$ssh_target" "pveversion" 2>/dev/null | head -n1 || echo "Unknown"
}

# Parse arguments
PROXMOX_HOST="${1:-}"
OUTPUT_FILE="${2:-$DEFAULT_OUTPUT_FILE}"

# Interactive mode if no host provided
if [ -z "$PROXMOX_HOST" ]; then
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║   Proxmox Packer User Setup                               ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Check if SSH config exists
    if [ -f "$SSH_CONFIG" ]; then
        print_info "SSH config file found: ${SSH_CONFIG}"
        list_ssh_hosts
        echo ""
        read -p "Enter Proxmox hostname or SSH config alias: " PROXMOX_HOST
    else
        print_warning "No SSH config found at ${SSH_CONFIG}"
        read -p "Enter Proxmox hostname or IP address: " PROXMOX_HOST
    fi
    
    if [ -z "$PROXMOX_HOST" ]; then
        print_error "No host provided. Exiting."
        exit 1
    fi
fi

# Determine SSH target
if check_ssh_config "$PROXMOX_HOST"; then
    print_success "Using SSH config alias: ${PROXMOX_HOST}"
    SSH_TARGET="$PROXMOX_HOST"
    # Try to extract the actual hostname from SSH config for the variables file
    PROXMOX_FQDN=$(ssh -G "$PROXMOX_HOST" | grep "^hostname " | awk '{print $2}')
else
    print_info "Using direct connection: ${PROXMOX_USER}@${PROXMOX_HOST}"
    SSH_TARGET="${PROXMOX_USER}@${PROXMOX_HOST}"
    PROXMOX_FQDN="$PROXMOX_HOST"
fi

# Test SSH connection
if ! test_ssh_connection "$SSH_TARGET"; then
    exit 1
fi

# Get Proxmox version
PROXMOX_VERSION=$(get_proxmox_version "$SSH_TARGET")
print_info "Proxmox Version: ${PROXMOX_VERSION}"
echo ""

# Confirm before proceeding
print_warning "This script will:"
echo "  1. Create a Packer role '${PACKER_ROLE}' with minimal required privileges"
echo "  2. Create a Packer user '${PACKER_USER}@pve'"
echo "  3. Generate an API token '${PACKER_TOKEN_NAME}'"
echo "  4. Write credentials to '${OUTPUT_FILE}'"
echo ""
read -p "Continue? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Operation cancelled."
    exit 0
fi

print_info "Creating Packer user on Proxmox host..."
echo ""

# SSH to Proxmox and create role, user, and API token
API_INFO=$(ssh "$SSH_TARGET" bash <<'EOFREMOTE'
set -euo pipefail

PACKER_USER="packer"
PACKER_ROLE="PVEPackerRole"
PACKER_TOKEN_NAME="packer-token"

# Create role with minimum required privileges
echo "[1/5] Creating/updating Packer role..."
if pveum role list | grep -q "^${PACKER_ROLE}"; then
    echo "  → Role '${PACKER_ROLE}' already exists, updating privileges..."
    pveum role modify $PACKER_ROLE -privs "\
VM.Config.Disk,\
VM.Config.CPU,\
VM.Config.Memory,\
Datastore.AllocateSpace,\
Sys.Modify,\
VM.Config.Options,\
VM.Allocate,\
VM.Audit,\
VM.Console,\
VM.Config.CDROM,\
VM.Config.Network,\
VM.PowerMgmt,\
VM.Config.HWType,\
VM.Monitor"
else
    pveum role add $PACKER_ROLE -privs "\
VM.Config.Disk,\
VM.Config.CPU,\
VM.Config.Memory,\
Datastore.AllocateSpace,\
Sys.Modify,\
VM.Config.Options,\
VM.Allocate,\
VM.Audit,\
VM.Console,\
VM.Config.CDROM,\
VM.Config.Network,\
VM.PowerMgmt,\
VM.Config.HWType,\
VM.Monitor"
    echo "  → Role '${PACKER_ROLE}' created"
fi

# Create user if it doesn't exist
echo "[2/5] Creating Packer user..."
if pveum user list | grep -q "^${PACKER_USER}@pve"; then
    echo "  → User '${PACKER_USER}@pve' already exists"
else
    pveum user add ${PACKER_USER}@pve --comment "Packer automation user - least privilege"
    echo "  → User '${PACKER_USER}@pve' created"
fi

# Assign role to user at root path
echo "[3/5] Assigning role to user..."
pveum aclmod / -user ${PACKER_USER}@pve -role $PACKER_ROLE
echo "  → Role '${PACKER_ROLE}' assigned to '${PACKER_USER}@pve' at path '/'"

# Check if token already exists and delete if necessary
echo "[4/5] Managing API token..."
if pveum user token list ${PACKER_USER}@pve 2>/dev/null | grep -q "${PACKER_TOKEN_NAME}"; then
    echo "  → Token '${PACKER_TOKEN_NAME}' already exists, recreating..."
    pveum user token remove ${PACKER_USER}@pve ${PACKER_TOKEN_NAME}
fi

# Create API token (privsep=0 means token has same privileges as user)
echo "[5/5] Creating new API token..."
TOKEN_OUTPUT=$(pveum user token add ${PACKER_USER}@pve ${PACKER_TOKEN_NAME} --privsep 0 2>&1)

# Extract the secret from output (handles different Proxmox versions)
API_SECRET=$(echo "$TOKEN_OUTPUT" | grep -oP '(?<=value:\s).*' || echo "$TOKEN_OUTPUT" | grep -oP '(?<=token: ).*' || echo "")

if [ -z "$API_SECRET" ]; then
    echo "ERROR: Failed to extract API secret from token creation"
    echo "Output was: $TOKEN_OUTPUT"
    exit 1
fi

# Output the credentials
echo "SUCCESS"
echo "API_TOKEN_ID=${PACKER_USER}@pve!${PACKER_TOKEN_NAME}"
echo "API_SECRET=${API_SECRET}"
EOFREMOTE
)

# Check if remote command was successful
if ! echo "$API_INFO" | grep -q "SUCCESS"; then
    print_error "Failed to create Packer user on Proxmox"
    echo "$API_INFO"
    exit 1
fi

# Parse the API info
API_TOKEN_ID=$(echo "$API_INFO" | grep "^API_TOKEN_ID=" | cut -d'=' -f2)
API_SECRET=$(echo "$API_INFO" | grep "^API_SECRET=" | cut -d'=' -f2)

if [ -z "$API_TOKEN_ID" ] || [ -z "$API_SECRET" ]; then
    print_error "Failed to extract API credentials"
    exit 1
fi

# Generate the Packer variables file
print_info "Generating Packer variables file..."
cat > "$OUTPUT_FILE" <<EOL
# Proxmox Configuration for Packer
# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
# Host: ${PROXMOX_FQDN}

proxmox_host = "${PROXMOX_FQDN}"
token_id     = "${API_TOKEN_ID}"
token_secret = "${API_SECRET}"

# Note: This file contains sensitive credentials
# Add to .gitignore: *.auto.pkrvars.hcl
EOL

# Set restrictive permissions on the output file
chmod 600 "$OUTPUT_FILE"

# Success summary
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║   Setup Complete!                                          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
print_success "Packer user created: ${PACKER_USER}@pve"
print_success "Packer role: ${PACKER_ROLE}"
print_success "API token: ${PACKER_TOKEN_NAME}"
print_success "Credentials written to: ${OUTPUT_FILE}"
echo ""
print_warning "IMPORTANT SECURITY NOTES:"
echo "  • The API secret cannot be retrieved again"
echo "  • Keep ${OUTPUT_FILE} secure (permissions: 600)"
echo "  • Add *.auto.pkrvars.hcl to .gitignore"
echo "  • Consider using GitHub Secrets for CI/CD"
echo ""
print_info "File contents:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat "$OUTPUT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_info "Test the configuration with:"
echo "  cd builds/linux/debian/13"
echo "  packer init ."
echo "  packer validate ."
echo ""