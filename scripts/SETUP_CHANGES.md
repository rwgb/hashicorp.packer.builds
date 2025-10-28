# Proxmox Setup Script Updates

## Overview
The `proxmox-setup.sh` script has been enhanced to create **both** a Packer user and an Ansible user with their respective API tokens and role-based permissions.

## What Changed

### 1. Dual User Creation
The script now creates two separate users:

| User | Purpose | Role | Privileges |
|------|---------|------|------------|
| `packer@pve` | VM/AMI building | PackerRole | Full VM management, creation, configuration |
| `ansible@pve` | Configuration management | AnsibleRole | Read-only access for inventory and monitoring |

### 2. Ansible Role Privileges
The new `AnsibleRole` has minimal read-only permissions:
- `VM.Audit` - View VM information
- `VM.Monitor` - Monitor VM status
- `VM.PowerMgmt` - Power management (start/stop VMs for configuration)
- `VM.Console` - Console access (for troubleshooting)
- `Datastore.Audit` - View datastore information
- `Sys.Audit` - View system information

This follows the principle of least privilege - Ansible only needs to **discover** and **configure** VMs, not create them.

### 3. Automatic Inventory Configuration
The script now:
1. Creates or updates `builds/proxmox/ansible/inventory.proxmox.yaml`
2. Automatically populates Ansible credentials
3. Sets correct URL, user, token_id, and token_secret
4. Sets file permissions to 600 for security

### 4. Enhanced Output
The script provides:
- Clear progress indicators for all 10 steps
- Separate sections for Packer and Ansible setup
- Summary of both user credentials
- Testing instructions for both Packer and Ansible

## Usage

### Basic Usage (Same as Before)
```bash
cd scripts
./proxmox-setup.sh
```

### With Arguments
```bash
# Use SSH config alias
./proxmox-setup.sh pve01

# Use IP address directly
./proxmox-setup.sh 192.168.1.161

# Non-interactive mode
./proxmox-setup.sh -y pve01

# Custom output file for Packer
./proxmox-setup.sh pve01 custom.pkrvars.hcl
```

## What It Creates

### For Packer
- **File**: `variables.auto.pkrvars.hcl` (or custom name)
- **Contents**: Proxmox host, Packer token ID, and secret
- **Permissions**: 600 (read/write for owner only)

### For Ansible
- **File**: `builds/proxmox/ansible/inventory.proxmox.yaml`
- **Contents**: Complete dynamic inventory configuration with Ansible credentials
- **Permissions**: 600 (read/write for owner only)

## Security Improvements

1. **Separate Credentials**: Packer and Ansible use different tokens
2. **Least Privilege**: Each user has only the permissions needed
3. **File Permissions**: Both credential files are set to 600
4. **No Privilege Separation**: Tokens inherit user permissions (privsep=0)

## Testing the Setup

### Test Packer
```bash
cd builds/proxmox/linux/debian/13
packer init .
packer validate .
```

### Test Ansible
```bash
cd builds/proxmox/ansible
ansible-inventory -i inventory.proxmox.yaml --list
ansible all -i inventory.proxmox.yaml -m ping
```

## Troubleshooting

### If Ansible authentication fails:
1. Verify the token in Proxmox UI: Datacenter → Permissions → API Tokens
2. Check that `ansible@pve!ansible-token` exists
3. Verify the AnsibleRole has correct permissions at path `/`
4. Try the curl test:
   ```bash
   curl -k "https://YOUR-PROXMOX:8006/api2/json/nodes" \
     -H "Authorization: PVEAPIToken=ansible@pve!ansible-token=YOUR-SECRET"
   ```

### If Packer authentication fails:
Same steps as above, but use `packer@pve!packer-token`

## Migration from Old Script

If you previously ran the old version:
1. Run the new script - it will update existing users
2. The Packer token will be recreated (old token invalidated)
3. New Ansible user and token will be created
4. Update your existing `inventory.proxmox.yaml` with new credentials

## Git Security

Add these to `.gitignore`:
```gitignore
# Packer credentials
*.auto.pkrvars.hcl
variables.auto.pkrvars.hcl

# Ansible credentials
builds/proxmox/ansible/inventory.proxmox.yaml
```

Or use environment variables instead:
```bash
# Packer
export PROXMOX_HOST="192.168.1.161"
export PROXMOX_TOKEN_ID="packer@pve!packer-token"
export PROXMOX_TOKEN_SECRET="your-secret"

# Ansible
export PROXMOX_URL="https://192.168.1.161:8006"
export PROXMOX_USER="ansible@pve"
export PROXMOX_TOKEN_ID="ansible-token"
export PROXMOX_TOKEN_SECRET="your-secret"
```

## Benefits

1. **Single Setup Process**: One script configures both Packer and Ansible
2. **Consistent Configuration**: Same Proxmox host for both tools
3. **Security**: Separate tokens with appropriate permissions
4. **Automation**: Ansible inventory is automatically configured
5. **Idempotent**: Safe to re-run; updates existing users/tokens

## Next Steps

After running the setup script:

1. **Test Packer**: Build a VM to verify Packer credentials
2. **Test Ansible**: List inventory to verify Ansible credentials
3. **Tag VMs**: Add tags like `docker`, `database`, `webserver` to your VMs
4. **Run Playbooks**: Use the ansible roles to configure your VMs
   ```bash
   cd builds/proxmox/ansible
   ansible-playbook -i inventory.proxmox.yaml playbook.yml --limit docker
   ```
