# Proxmox Dynamic Inventory - Current Status

## ✅ Fixed Issues

1. **Plugin name corrected**: Changed from `community.proxmox.proxmox` (doesn't exist) to `community.general.proxmox` (correct)
2. **Authentication parameters fixed**: Changed from `token_name/token_value` to `token_id/token_secret` (correct parameters)
3. **Required URL added**: Added `url` parameter pointing to Proxmox server
4. **Automated Setup Available**: Run `scripts/proxmox-setup.sh` to automatically create Ansible user and configure credentials

## � Quick Setup (Recommended)

The easiest way to configure authentication is to use the automated setup script:

```bash
cd scripts
./proxmox-setup.sh
```

This will:
- Create both `packer@pve` and `ansible@pve` users
- Generate API tokens with appropriate permissions
- Automatically update `builds/proxmox/ansible/inventory.proxmox.yaml`
- Set correct file permissions (600)

See `scripts/SETUP_CHANGES.md` for detailed information.

## 🔍 Manual Setup (If Needed)

The inventory file now parses correctly, but authentication is failing with:
```
401 Client Error: No ticket
```

This is a Proxmox API authentication issue, not an Ansible syntax issue.

## 🛠️ What You Need to Do

### 1. Verify Proxmox URL
Update the `url` in `inventory.proxmox.yaml`:
```yaml
url: http://YOUR-PROXMOX-SERVER:8006
```
Current placeholder: `http://192.168.1.161:8006`

### 2. Check Token Format
The current configuration uses:
```yaml
user: packer@pve
token_id: packer-token
token_secret: 5fb402ca-fa04-4c9c-8355-6974e7b6254b
```

**Verify this matches your actual Proxmox API token:**
- Go to Proxmox UI → Datacenter → Permissions → API Tokens
- Find the token (should show as `packer@pve!packer-token`)
- Verify the secret matches

### 3. Token Permissions
The "401 No ticket" error often indicates insufficient permissions. Your token needs:

**Option A: Use existing user permissions (easier)**
- When creating the token, **uncheck "Privilege Separation"**
- The token will inherit all permissions from the user `packer@pve`
- Requires the user `packer@pve` to have at least `PVEAuditor` role

**Option B: Grant explicit permissions (more secure)**
- Keep "Privilege Separation" enabled
- Grant the token these permissions:
  - Path: `/`
  - Role: `PVEAuditor` (read-only access to all resources)

### 4. Test Token with curl
Before testing with Ansible, verify the token works with Proxmox API:

```bash
# Set your values
PROXMOX_URL="http://192.168.1.161:8006"
TOKEN_ID="packer@pve!packer-token"
TOKEN_SECRET="5fb402ca-fa04-4c9c-8355-6974e7b6254b"

# Test API access
curl -k "${PROXMOX_URL}/api2/json/nodes" \
  -H "Authorization: PVEAPIToken=${TOKEN_ID}=${TOKEN_SECRET}"
```

Expected response:
- **Success**: JSON with list of nodes
- **401 Unauthorized**: Token is invalid or lacks permissions
- **Connection refused**: URL is wrong or Proxmox is not running

### 5. Alternative: Use Password Authentication (for testing)

If token auth continues to fail, try password auth to isolate the issue:

```yaml
plugin: community.general.proxmox
url: http://192.168.1.161:8006
user: packer@pve
password: your-password-here
validate_certs: false
```

If password auth works but token auth doesn't, the issue is definitely with token permissions.

## 📝 Next Steps

1. Fix the Proxmox URL
2. Verify/fix token permissions in Proxmox UI
3. Test with the curl command above
4. Re-test: `ansible-inventory -i inventory.proxmox.yaml --list`
5. Once working, commit the changes

## 🔗 Related Files

- `inventory.proxmox.yaml` - Main inventory configuration
- `PROXMOX_INVENTORY.md` - Complete setup documentation  
- `README.md` - Ansible playbook overview

## ⚠️ Security Note

The current `inventory.proxmox.yaml` has credentials in plaintext. For production:

1. Use environment variables:
   ```bash
   export PROXMOX_URL="http://your-server:8006"
   export PROXMOX_USER="packer@pve"
   export PROXMOX_TOKEN_ID="packer-token"
   export PROXMOX_TOKEN_SECRET="your-secret"
   ```

2. Remove credentials from the YAML file:
   ```yaml
   plugin: community.general.proxmox
   # url, user, token_id, token_secret will be read from environment
   validate_certs: false
   want_facts: true
   ```

3. Add `inventory.proxmox.yaml` to `.gitignore` if it contains secrets
