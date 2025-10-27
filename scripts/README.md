# Packer Utility Scripts

This directory contains helper scripts for managing Packer builds and Proxmox infrastructure.

## proxmox-setup.sh

Automated script to create a least-privilege Packer user on Proxmox VE with API token authentication.

### Features

- 🔐 **Least-privilege access** - Creates role with minimal required permissions
- 🔑 **API token authentication** - No password storage needed
- 🎯 **SSH config aware** - Detects and uses SSH config aliases
- ✅ **Idempotent** - Safe to run multiple times
- 📝 **Auto-generates variables file** - Creates `variables.auto.pkrvars.hcl`
- 🔒 **Secure by default** - Sets restrictive file permissions (600)

### Prerequisites

- SSH access to Proxmox host as root
- SSH key authentication configured
- Proxmox VE 6.x or later

### Usage

#### Interactive Mode (Recommended)

```bash
./scripts/proxmox-setup.sh
```

The script will:
1. Check for SSH config file (`~/.ssh/config`)
2. List available SSH hosts if config exists
3. Prompt for Proxmox hostname or SSH alias
4. Test SSH connection
5. Display what will be created
6. Ask for confirmation before proceeding

#### Direct Mode

```bash
# Using SSH config alias
./scripts/proxmox-setup.sh pve01

# Using hostname/IP directly
./scripts/proxmox-setup.sh 192.168.1.100

# Specify custom output file
./scripts/proxmox-setup.sh pve01 my-custom-vars.pkrvars.hcl
```

### What It Creates

1. **Proxmox Role**: `PackerRole`
   - VM.Config.Disk
   - VM.Config.CPU
   - VM.Config.Memory
   - VM.Config.Cloudinit
   - Datastore.AllocateSpace
   - Sys.Modify
   - VM.Config.Options
   - VM.Allocate
   - VM.Audit
   - VM.Console
   - VM.Config.CDROM
   - VM.Config.Network
   - VM.PowerMgmt
   - VM.Config.HWType
   - VM.Monitor
   - SDN.Use (required for SDN-enabled networks)

2. **Proxmox User**: `packer@pve`
   - Assigned the `PackerRole`
   - No password (API token only)

3. **API Token**: `packer@pve!packer-token`
   - Privilege separation disabled (inherits user permissions)
   - Full access to role capabilities

4. **Variables File**: `variables.auto.pkrvars.hcl`
   ```hcl
   proxmox_host = "your-proxmox-host"
   token_id     = "packer@pve!packer-token"
   token_secret = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
   ```

### SSH Config Example

To use SSH config aliases, add to `~/.ssh/config`:

```ssh-config
Host pve01
    HostName 192.168.1.100
    User root
    IdentityFile ~/.ssh/id_ed25519
    
Host pve02
    HostName proxmox.example.com
    User root
    Port 2222
    IdentityFile ~/.ssh/proxmox_key
```

Then run:
```bash
./scripts/proxmox-setup.sh pve01
```

### Testing the Configuration

After running the script:

```bash
# Navigate to a build directory
cd builds/linux/debian/13

# Initialize Packer
packer init .

# Validate configuration
packer validate .

# Run a build
packer build .
```

### Security Best Practices

1. **Never commit the variables file**
   ```bash
   # Already in .gitignore
   echo "*.auto.pkrvars.hcl" >> .gitignore
   ```

2. **Use GitHub Secrets for CI/CD**
   - `PROXMOX_HOST`: Proxmox hostname/IP
   - `TOKEN_ID`: The API token ID
   - `TOKEN_SECRET`: The API token secret

3. **Rotate tokens periodically**
   ```bash
   # Re-run the script to recreate the token
   ./scripts/proxmox-setup.sh your-host
   ```

4. **Limit token scope if possible**
   - The script creates tokens at root path (`/`)
   - For production, consider scoping to specific pools/datastores

### Troubleshooting

#### SSH Connection Failed

```bash
# Test SSH manually
ssh root@your-proxmox-host "pveversion"

# Check SSH key authentication
ssh-add -l

# Test with verbose output
ssh -v root@your-proxmox-host
```

#### Permission Denied on Proxmox

- Ensure you're connecting as root
- Check that root SSH login is enabled in `/etc/ssh/sshd_config`
- Verify SSH key is in `/root/.ssh/authorized_keys`

#### Token Creation Failed

- Check Proxmox version: `pveversion`
- Ensure pveum command is available
- Verify you have root access

#### Variables File Not Working

```bash
# Check file permissions
ls -la variables.auto.pkrvars.hcl

# Validate syntax
packer validate .

# Use explicit -var-file flag
packer build -var-file=variables.auto.pkrvars.hcl .
```

### Manual Cleanup

To remove the Packer user from Proxmox:

```bash
ssh root@your-proxmox-host

# Remove token
pveum user token remove packer@pve packer-token

# Remove user
pveum user delete packer@pve

# Optionally remove role (if no other users use it)
pveum role delete PackerRole
```

### Environment Variables

The script respects these environment variables:

- `PROXMOX_USER`: SSH user (default: `root`)

Example:
```bash
PROXMOX_USER=admin ./scripts/proxmox-setup.sh pve01
```

## Contributing

When modifying scripts:
1. Test on a non-production Proxmox instance
2. Ensure idempotency (safe to run multiple times)
3. Add error handling for edge cases
4. Update this README with any new features
