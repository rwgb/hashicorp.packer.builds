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

# Packer Build Scripts

This directory contains utility scripts for managing Packer builds in this repository.

## buildManager.py

A comprehensive Python script for managing Packer builds with granular control over source selection and variable management.

### Features

- 🔍 **Auto-discovery**: Automatically discovers all Packer builds in the repository
- 🎯 **Granular control**: Select specific sources from multi-source builds
- 📝 **Variable management**: Support for custom variables files
- 🎨 **Interactive mode**: User-friendly menu-driven interface
- ✅ **Validation**: Validate configurations before building
- 🚀 **Flexible execution**: CLI and interactive modes

### Installation

The script requires Python 3.6+ (no external dependencies).

```bash
chmod +x scripts/buildManager.py
```

### Usage Examples

#### List All Available Builds

```bash
python3 scripts/buildManager.py --list
```

Output:
```
Available Packer Builds:

📦 PROXMOX
  └─ linux
      1. debian_linux_12
         Path: proxmox/linux/debian/12
         Sources: proxmox-iso.debian_12_base
         ✓ Has variables.auto.pkrvars.hcl
      2. debian_linux_13
         Path: proxmox/linux/debian/13
         Sources: proxmox-iso.debian_13_base
```

#### Interactive Mode

Run without arguments for an interactive menu:

```bash
python3 scripts/buildManager.py
```

#### Build Specific OS

```bash
# Build Debian 12
python3 scripts/buildManager.py --os debian-12

# Build Windows Server 2019
python3 scripts/buildManager.py --os windows-server-2019
```

#### Build Specific Source

Perfect for builds with multiple sources (e.g., ISO vs Clone):

```bash
# Build only the ISO source
python3 scripts/buildManager.py --source proxmox-iso.windows_server_2k19_data_center_base

# Build only the clone source
python3 scripts/buildManager.py --source proxmox-clone.windows_server_2k19_data_center_base
```

#### Use Custom Variables File

```bash
python3 scripts/buildManager.py --os debian-12 --vars /path/to/custom.auto.pkrvars.hcl
```

#### Validate Only (No Build)

```bash
python3 scripts/buildManager.py --os debian-12 --validate-only
```

#### Initialize Packer Plugins

```bash
# Initialize once
python3 scripts/buildManager.py --os debian-12 --init-only

# Force re-initialization (upgrade plugins)
python3 scripts/buildManager.py --os debian-12 --force-init
```

#### Dry Run

See what commands would be executed without actually running them:

```bash
python3 scripts/buildManager.py --os debian-12 --dry-run
```

#### Pass Additional Packer Arguments

```bash
# Pass extra arguments to packer build
python3 scripts/buildManager.py --os debian-12 -- -on-error=ask -parallel-builds=2
```

### Command-Line Options

| Option | Description |
|--------|-------------|
| `--list`, `-l` | List all available builds |
| `--os OS` | Build specific OS (e.g., 'debian-12', 'windows-server-2019') |
| `--source SOURCE`, `-s` | Build specific source (e.g., 'proxmox-iso.debian_12_base') |
| `--vars FILE`, `-v` | Path to custom variables.auto.pkrvars.hcl file |
| `--validate-only` | Only validate, don't build |
| `--init-only` | Only initialize (packer init) |
| `--force-init` | Force re-initialization (packer init -upgrade) |
| `--dry-run` | Show commands without executing |
| `--repo-root PATH` | Repository root path (auto-detected if not specified) |
| `--help`, `-h` | Show help message |

### How It Works

1. **Auto-Discovery**: Scans `builds/` directory for all Packer configurations
2. **Source Parsing**: Extracts available sources from `sources.pkr.hcl` files
3. **Variable Detection**: Automatically uses `variables.auto.pkrvars.hcl` if present
4. **Execution**: Runs packer commands in the correct build directory

### Advanced Examples

#### CI/CD Integration

```bash
# Validate all builds
for os in debian-12 debian-13 windows-server-2019 windows-server-2022; do
    python3 scripts/buildManager.py --os "$os" --validate-only || exit 1
done

# Build with secrets from environment
python3 scripts/buildManager.py --os debian-12 \
    --vars "$SECRETS_DIR/production.auto.pkrvars.hcl"
```

#### Multi-Source Builds

For Windows Server builds that have both ISO and clone sources:

```bash
# Build fresh from ISO (slower, clean)
python3 scripts/buildManager.py --source proxmox-iso.windows_server_2k22_data_center_base

# Build from existing template clone (faster)
python3 scripts/buildManager.py --source proxmox-clone.windows_server_2k22_data_center_base
```

### Error Handling

The script provides clear, colored output for:
- ✅ Success (green)
- ⚠️  Warnings (yellow)
- ❌ Errors (red)
- ℹ️  Info (blue/cyan)

### Repository Structure

The script expects this structure:

```
builds/
├── {provider}/          # e.g., proxmox, aws, azure
│   ├── {os_type}/       # e.g., linux, windows
│   │   └── {distro}/    # e.g., debian, ubuntu, server
│   │       └── {version}/
│   │           ├── build.pkr.hcl
│   │           ├── sources.pkr.hcl
│   │           └── variables.auto.pkrvars.hcl  # optional
```

## proxmox-setup.sh

Automated script for creating a least-privilege Packer user on Proxmox VE.

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
