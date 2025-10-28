#!/usr/bin/env bash
set -euo pipefail

# Script: proxmox-setup.sh
# Purpose: Create least-privilege Packer and Ansible users on Proxmox with API tokens
# Usage: ./proxmox-setup.sh [OPTIONS] [proxmox-host-or-ssh-alias] [output-file]

# Configuration
PACKER_USER="packer"
PACKER_ROLE="PackerRole"
PACKER_TOKEN_NAME="packer-token"
ANSIBLE_USER="ansible"
ANSIBLE_ROLE="AnsibleRole"
ANSIBLE_TOKEN_NAME="ansible-token"
PROXMOX_USER="${PROXMOX_USER:-root}"
SSH_CONFIG="${HOME}/.ssh/config"
DEFAULT_OUTPUT_FILE="variables.auto.pkrvars.hcl"
NON_INTERACTIVE=false

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
PROXMOX_HOST=""
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -y|--yes|--non-interactive)
            NON_INTERACTIVE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS] [proxmox-host] [output-file]"
            echo ""
            echo "Options:"
            echo "  -y, --yes, --non-interactive    Skip confirmation prompt"
            echo "  -h, --help                      Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                              # Interactive mode"
            echo "  $0 pve01                       # Use SSH config alias"
            echo "  $0 192.168.1.100               # Use IP address"
            echo "  $0 -y pve01                    # Non-interactive mode"
            echo "  $0 pve01 custom.pkrvars.hcl    # Custom output file"
            exit 0
            ;;
        *)
            if [ -z "$PROXMOX_HOST" ]; then
                PROXMOX_HOST="$1"
            elif [ -z "$OUTPUT_FILE" ]; then
                OUTPUT_FILE="$1"
            else
                print_error "Too many arguments: $1"
                exit 1
            fi
            shift
            ;;
    esac
done

# Set default output file if not provided
OUTPUT_FILE="${OUTPUT_FILE:-$DEFAULT_OUTPUT_FILE}"

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
echo "  2. Create a Packer user '${PACKER_USER}@pve' with API token"
echo "  3. Create an Ansible role '${ANSIBLE_ROLE}' with read-only privileges"
echo "  4. Create an Ansible user '${ANSIBLE_USER}@pve' with API token"
echo "  5. Write Packer credentials to '${OUTPUT_FILE}'"
echo "  6. Write Ansible credentials to 'builds/proxmox/ansible/inventory.proxmox.yaml'"
echo ""

# Check for non-interactive mode or prompt user
if [ "$NON_INTERACTIVE" = true ]; then
    print_info "Running in non-interactive mode, proceeding automatically..."
else
    read -p "Continue? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Operation cancelled."
        exit 0
    fi
fi

print_info "Creating Packer and Ansible users on Proxmox host..."
echo ""

# SSH to Proxmox and create roles, users, and API tokens
set +e  # Temporarily disable exit on error to capture output
API_INFO=$(ssh "$SSH_TARGET" bash <<'EOFREMOTE'
set -euo pipefail

PACKER_USER="packer"
PACKER_ROLE="PackerRole"
PACKER_TOKEN_NAME="packer-token"
ANSIBLE_USER="ansible"
ANSIBLE_ROLE="AnsibleRole"
ANSIBLE_TOKEN_NAME="ansible-token"

echo "════════════════════════════════════════════════════════════"
echo "  PACKER USER SETUP"
echo "════════════════════════════════════════════════════════════"

# Create Packer role with minimum required privileges
echo "[1/10] Creating/updating Packer role..."
if pveum role list | awk '{print $2}' | grep -q "^${PACKER_ROLE}$"; then
    echo "  → Role '${PACKER_ROLE}' already exists, updating privileges..."
    pveum role modify $PACKER_ROLE -privs "\
VM.Config.Disk,\
VM.Config.CPU,\
VM.Config.Memory,\
VM.Config.Cloudinit,\
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
VM.Monitor,\
SDN.Use"
else
    pveum role add $PACKER_ROLE -privs "\
VM.Config.Disk,\
VM.Config.CPU,\
VM.Config.Memory,\
VM.Config.Cloudinit,\
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
VM.Monitor,\
SDN.Use"
    echo "  → Role '${PACKER_ROLE}' created"
fi

# Create Packer user if it doesn't exist
echo "[2/10] Creating Packer user..."
if pveum user list | awk '{print $2}' | grep -q "^${PACKER_USER}@pve$"; then
    echo "  → User '${PACKER_USER}@pve' already exists"
else
    pveum user add ${PACKER_USER}@pve --comment "Packer automation user - least privilege"
    echo "  → User '${PACKER_USER}@pve' created"
fi

# Assign Packer role to user at root path
echo "[3/10] Assigning Packer role to user..."
pveum aclmod / -user ${PACKER_USER}@pve -role $PACKER_ROLE
echo "  → Role '${PACKER_ROLE}' assigned to '${PACKER_USER}@pve' at path '/'"

# Check if Packer token already exists and delete if necessary
echo "[4/10] Managing Packer API token..."
if pveum user token list ${PACKER_USER}@pve 2>/dev/null | awk '{print $2}' | grep -q "^${PACKER_TOKEN_NAME}$"; then
    echo "  → Token '${PACKER_TOKEN_NAME}' already exists, recreating..."
    pveum user token remove ${PACKER_USER}@pve ${PACKER_TOKEN_NAME}
fi

# Create Packer API token (privsep=0 means token has same privileges as user)
echo "[5/10] Creating new Packer API token..."
PACKER_TOKEN_OUTPUT=$(pveum user token add ${PACKER_USER}@pve ${PACKER_TOKEN_NAME} --privsep 0 2>&1)

# Extract the secret from output
PACKER_API_SECRET=$(echo "$PACKER_TOKEN_OUTPUT" | awk -F'│' '$2 ~ /^ value[ \t]*$/ {gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3}' 2>/dev/null || \
                    echo "$PACKER_TOKEN_OUTPUT" | grep -oP '(?<=value:\s).*' 2>/dev/null || \
                    echo "$PACKER_TOKEN_OUTPUT" | grep -oP '(?<=token: ).*' 2>/dev/null || \
                    echo "")

if [ -z "$PACKER_API_SECRET" ]; then
    echo "ERROR: Failed to extract Packer API secret"
    echo "Output was: $PACKER_TOKEN_OUTPUT"
    exit 1
fi
echo "  → Packer API token created successfully"

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  ANSIBLE USER SETUP"
echo "════════════════════════════════════════════════════════════"

# Create Ansible role with read-only + VM management privileges
echo "[6/10] Creating/updating Ansible role..."
if pveum role list | awk '{print $2}' | grep -q "^${ANSIBLE_ROLE}$"; then
    echo "  → Role '${ANSIBLE_ROLE}' already exists, updating privileges..."
    pveum role modify $ANSIBLE_ROLE -privs "\
VM.Audit,\
VM.Monitor,\
VM.PowerMgmt,\
VM.Console,\
Datastore.Audit,\
Sys.Audit"
else
    pveum role add $ANSIBLE_ROLE -privs "\
VM.Audit,\
VM.Monitor,\
VM.PowerMgmt,\
VM.Console,\
Datastore.Audit,\
Sys.Audit"
    echo "  → Role '${ANSIBLE_ROLE}' created"
fi

# Create Ansible user if it doesn't exist
echo "[7/10] Creating Ansible user..."
if pveum user list | awk '{print $2}' | grep -q "^${ANSIBLE_USER}@pve$"; then
    echo "  → User '${ANSIBLE_USER}@pve' already exists"
else
    pveum user add ${ANSIBLE_USER}@pve --comment "Ansible automation user - read-only access"
    echo "  → User '${ANSIBLE_USER}@pve' created"
fi

# Assign Ansible role to user at root path
echo "[8/10] Assigning Ansible role to user..."
pveum aclmod / -user ${ANSIBLE_USER}@pve -role $ANSIBLE_ROLE
echo "  → Role '${ANSIBLE_ROLE}' assigned to '${ANSIBLE_USER}@pve' at path '/'"

# Check if Ansible token already exists and delete if necessary
echo "[9/10] Managing Ansible API token..."
if pveum user token list ${ANSIBLE_USER}@pve 2>/dev/null | awk '{print $2}' | grep -q "^${ANSIBLE_TOKEN_NAME}$"; then
    echo "  → Token '${ANSIBLE_TOKEN_NAME}' already exists, recreating..."
    pveum user token remove ${ANSIBLE_USER}@pve ${ANSIBLE_TOKEN_NAME}
fi

# Create Ansible API token (privsep=0 means token has same privileges as user)
echo "[10/10] Creating new Ansible API token..."
ANSIBLE_TOKEN_OUTPUT=$(pveum user token add ${ANSIBLE_USER}@pve ${ANSIBLE_TOKEN_NAME} --privsep 0 2>&1)

# Extract the secret from output
ANSIBLE_API_SECRET=$(echo "$ANSIBLE_TOKEN_OUTPUT" | awk -F'│' '$2 ~ /^ value[ \t]*$/ {gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3}' 2>/dev/null || \
                     echo "$ANSIBLE_TOKEN_OUTPUT" | grep -oP '(?<=value:\s).*' 2>/dev/null || \
                     echo "$ANSIBLE_TOKEN_OUTPUT" | grep -oP '(?<=token: ).*' 2>/dev/null || \
                     echo "")

if [ -z "$ANSIBLE_API_SECRET" ]; then
    echo "ERROR: Failed to extract Ansible API secret"
    echo "Output was: $ANSIBLE_TOKEN_OUTPUT"
    exit 1
fi
echo "  → Ansible API token created successfully"

echo ""
echo "════════════════════════════════════════════════════════════"

# Output the credentials
echo "SUCCESS"
echo "PACKER_API_TOKEN_ID=${PACKER_USER}@pve!${PACKER_TOKEN_NAME}"
echo "PACKER_API_SECRET=${PACKER_API_SECRET}"
echo "ANSIBLE_API_TOKEN_ID=${ANSIBLE_USER}@pve!${ANSIBLE_TOKEN_NAME}"
echo "ANSIBLE_API_SECRET=${ANSIBLE_API_SECRET}"
EOFREMOTE
)
SSH_EXIT_CODE=$?
set -e  # Re-enable exit on error

# Check SSH exit code
if [ $SSH_EXIT_CODE -ne 0 ]; then
    print_error "Remote command failed with exit code: $SSH_EXIT_CODE"
    print_error "Output:"
    echo "$API_INFO"
    exit 1
fi

# Check if remote command was successful
if ! echo "$API_INFO" | grep -q "SUCCESS"; then
    print_error "Failed to create Packer user on Proxmox"
    echo "$API_INFO"
    exit 1
fi

# Parse the API info
PACKER_API_TOKEN_ID=$(echo "$API_INFO" | grep "^PACKER_API_TOKEN_ID=" | cut -d'=' -f2)
PACKER_API_SECRET=$(echo "$API_INFO" | grep "^PACKER_API_SECRET=" | cut -d'=' -f2)
ANSIBLE_API_TOKEN_ID=$(echo "$API_INFO" | grep "^ANSIBLE_API_TOKEN_ID=" | cut -d'=' -f2)
ANSIBLE_API_SECRET=$(echo "$API_INFO" | grep "^ANSIBLE_API_SECRET=" | cut -d'=' -f2)

if [ -z "$PACKER_API_TOKEN_ID" ] || [ -z "$PACKER_API_SECRET" ]; then
    print_error "Failed to extract Packer API credentials"
    exit 1
fi

if [ -z "$ANSIBLE_API_TOKEN_ID" ] || [ -z "$ANSIBLE_API_SECRET" ]; then
    print_error "Failed to extract Ansible API credentials"
    exit 1
fi

# Generate the Packer variables file
print_info "Generating Packer variables file..."
cat > "$OUTPUT_FILE" <<EOL
# Proxmox Configuration for Packer
# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
# Host: ${PROXMOX_FQDN}

proxmox_host = "${PROXMOX_FQDN}"
token_id     = "${PACKER_API_TOKEN_ID}"
token_secret = "${PACKER_API_SECRET}"

# Note: This file contains sensitive credentials
# Add to .gitignore: *.auto.pkrvars.hcl
EOL

# Set restrictive permissions on the output file
chmod 600 "$OUTPUT_FILE"

# Determine the Ansible inventory file path (relative to script location)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_INVENTORY="${SCRIPT_DIR}/../builds/proxmox/ansible/inventory.proxmox.yaml"

# Update Ansible inventory file if it exists
if [ -f "$ANSIBLE_INVENTORY" ]; then
    print_info "Updating Ansible inventory file..."
    
    # Use awk to update the credentials while preserving the rest of the file
    awk -v url="https://${PROXMOX_FQDN}:8006" \
        -v user="${ANSIBLE_USER}@pve" \
        -v token_id="${ANSIBLE_TOKEN_NAME}" \
        -v token_secret="${ANSIBLE_API_SECRET}" '
    /^url:/ { print "url: " url; next }
    /^user:/ { print "user: " user; next }
    /^token_id:/ { print "token_id: " token_id; next }
    /^token_secret:/ { print "token_secret: " token_secret; next }
    { print }
    ' "$ANSIBLE_INVENTORY" > "${ANSIBLE_INVENTORY}.tmp"
    
    mv "${ANSIBLE_INVENTORY}.tmp" "$ANSIBLE_INVENTORY"
    chmod 600 "$ANSIBLE_INVENTORY"
    print_success "Ansible inventory updated: ${ANSIBLE_INVENTORY}"
else
    print_warning "Ansible inventory not found at: ${ANSIBLE_INVENTORY}"
    print_info "Creating new Ansible inventory file..."
    
    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$ANSIBLE_INVENTORY")"
    
    # Create new inventory file
    cat > "$ANSIBLE_INVENTORY" <<EOL
---
# Proxmox Dynamic Inventory Configuration
# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
# Documentation: https://docs.ansible.com/ansible/latest/collections/community/general/proxmox_inventory.html

plugin: community.general.proxmox

# Proxmox API Connection
url: https://${PROXMOX_FQDN}:8006

# Authentication using API token
user: ${ANSIBLE_USER}@pve
token_id: ${ANSIBLE_TOKEN_NAME}
token_secret: ${ANSIBLE_API_SECRET}

# SSL certificate validation (set to false for self-signed certs)
validate_certs: false

# Retrieve facts about VMs/containers
want_facts: true

# Group VMs by various attributes
compose:
  # Use the IP address from network config
  ansible_host: proxmox_ipconfig0.ip | default(proxmox_net0.ip) | default(proxmox_net0.hwaddr)

# Create groups based on Proxmox tags
keyed_groups:
  - key: proxmox_tags_parsed
    separator: ""
    prefix: tag

# Create custom groups
groups:
  docker: "'docker' in (proxmox_tags_parsed|list)"
  database: "'database' in (proxmox_tags_parsed|list)"
  webserver: "'webserver' in (proxmox_tags_parsed|list)"
  production: "'prod' in (proxmox_tags_parsed|list)"
  development: "'dev' in (proxmox_tags_parsed|list)"
EOL
    chmod 600 "$ANSIBLE_INVENTORY"
    print_success "Ansible inventory created: ${ANSIBLE_INVENTORY}"
fi

# Success summary
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║   Setup Complete!                                          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
print_success "Packer user created: ${PACKER_USER}@pve"
print_success "Packer role: ${PACKER_ROLE}"
print_success "Packer API token: ${PACKER_TOKEN_NAME}"
print_success "Packer credentials written to: ${OUTPUT_FILE}"
echo ""
print_success "Ansible user created: ${ANSIBLE_USER}@pve"
print_success "Ansible role: ${ANSIBLE_ROLE}"
print_success "Ansible API token: ${ANSIBLE_TOKEN_NAME}"
if [ -f "$ANSIBLE_INVENTORY" ]; then
    print_success "Ansible credentials written to: ${ANSIBLE_INVENTORY}"
fi
echo ""
print_warning "IMPORTANT SECURITY NOTES:"
echo "  • The API secrets cannot be retrieved again"
echo "  • Keep ${OUTPUT_FILE} secure (permissions: 600)"
if [ -f "$ANSIBLE_INVENTORY" ]; then
    echo "  • Keep ${ANSIBLE_INVENTORY} secure (permissions: 600)"
fi
echo "  • Add *.auto.pkrvars.hcl to .gitignore"
echo "  • Add inventory.proxmox.yaml to .gitignore (contains secrets)"
echo "  • Consider using environment variables for production"
echo ""
print_info "Packer configuration file:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat "$OUTPUT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_info "Test Packer configuration with:"
echo "  cd builds/proxmox/linux/debian/13"
echo "  packer init ."
echo "  packer validate ."
echo ""
if [ -f "$ANSIBLE_INVENTORY" ]; then
    print_info "Test Ansible inventory with:"
    echo "  cd builds/proxmox/ansible"
    echo "  ansible-inventory -i inventory.proxmox.yaml --list"
    echo "  ansible all -i inventory.proxmox.yaml -m ping"
    echo ""
fi
print_info "User Privileges Summary:"
echo "  Packer: VM creation, configuration, and management"
echo "  Ansible: Read-only access for inventory discovery and monitoring"
echo ""