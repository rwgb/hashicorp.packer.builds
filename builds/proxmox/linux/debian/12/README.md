# Debian 12 Chained Packer Builds

This directory contains a refactored, modular Packer build system for creating Debian 12 templates in Proxmox using a chained build approach.

## Architecture Overview

The build system is organized into layers:

```
debian/12/
├── base/              # Foundation: ISO-based build
├── configured/        # Layer 1: Ansible-provisioned templates
├── common.auto.pkrvars.hcl  # Shared configuration
└── build-chain.sh     # Orchestration script
```

### Build Chain Flow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. BASE TEMPLATE (debian-12-base)                          │
│    Source: proxmox-iso (Debian 12 ISO)                     │
│    VM ID: 9000                                              │
│    Purpose: Minimal OS installation                         │
│    Provisioning: Kickstart only                            │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. CONFIGURED TEMPLATES (debian-12-*)                      │
│    Source: proxmox-clone (clones base template)            │
│    VM ID: 9100+ (customizable)                             │
│    Purpose: Role-specific configurations                    │
│    Provisioning: Ansible roles                             │
│                                                             │
│    Available types:                                         │
│    • base       - Additional base hardening                │
│    • docker     - Docker host configuration                │
│    • database   - Database server setup                    │
│    • webserver  - Web server configuration                 │
│    • monitoring - Monitoring stack                         │
└─────────────────────────────────────────────────────────────┘
```

## Directory Structure

### base/
Foundation template built from Debian ISO.

**Files:**
- `build.pkr.hcl` - Build configuration
- `sources.pkr.hcl` - proxmox-iso source definition
- `variables.pkr.hcl` - Variable definitions
- `data/ks.pkrtpl.hcl` - Kickstart preseed template

**Features:**
- Minimal Debian 12 installation
- Partitioning with LVM
- SSH key authentication
- QEMU guest agent
- Cloud-init support
- Base security hardening

**Build Time:** ~15-20 minutes

### configured/
Layered templates that clone the base and apply specific configurations.

**Files:**
- `build.pkr.hcl` - Build configuration with Ansible provisioner
- `sources.pkr.hcl` - proxmox-clone source definition
- `variables.pkr.hcl` - Variable definitions

**Features:**
- Clones base template (fast)
- Applies Ansible roles based on type
- Customizable per host type
- Maintains base template integrity

**Build Time:** ~5-10 minutes per type

## Quick Start

### Prerequisites

1. **Packer installed** (>= 1.9.0)
   ```bash
   brew install packer  # macOS
   ```

2. **Proxmox credentials configured**
   Copy the example file and edit with your settings:
   ```bash
   cp common.auto.pkrvars.hcl.example common.auto.pkrvars.hcl
   vim common.auto.pkrvars.hcl
   ```
   Fill in your actual values:
   ```hcl
   proxmox_host = "your-proxmox-host"
   token_id     = "packer@pve!packer-token"
   token_secret = "your-api-secret"
   node         = "your-node-name"
   ```

3. **Debian 12 ISO uploaded to Proxmox**
   Upload to `local:iso/debian-12.iso` or update `iso_file` variable

4. **Ansible playbooks configured** (for configured builds)
   Ensure `../../../ansible/playbook.yml` exists

### Building Templates

#### Build Only Base Template
```bash
./build-chain.sh base
```

This creates `debian-12-base` template (VM ID 9000).

#### Build Configured Template
```bash
# Build with default (base) configuration
./build-chain.sh configured

# Build specific type
./build-chain.sh configured docker
./build-chain.sh configured database
./build-chain.sh configured webserver

# Build with custom VM ID
./build-chain.sh configured docker --vm-id 9101
```

#### Build Complete Chain
```bash
./build-chain.sh all
```

This builds: base → configured (base)

### Manual Builds

If you prefer to build manually:

```bash
# Base template
cd base/
packer init .
packer validate -var-file=../common.auto.pkrvars.hcl .
packer build -var-file=../common.auto.pkrvars.hcl .

# Configured template
cd ../configured/
packer init .
packer validate -var-file=../common.auto.pkrvars.hcl -var ansible_host_type=docker .
packer build -var-file=../common.auto.pkrvars.hcl -var ansible_host_type=docker .
```

## Configuration

### Example Files

Example configuration files are provided for reference. Copy and customize them:

```bash
# Main configuration (required)
cp common.auto.pkrvars.hcl.example common.auto.pkrvars.hcl
vim common.auto.pkrvars.hcl

# Optional: Base-specific overrides
cp base/base.auto.pkrvars.hcl.example base/base.auto.pkrvars.hcl

# Optional: Configured-specific overrides
cp configured/configured.auto.pkrvars.hcl.example configured/configured.auto.pkrvars.hcl
```

**Note:** Files ending in `.example` are safe to commit. Actual `.auto.pkrvars.hcl` files are gitignored.

### Common Variables (`common.auto.pkrvars.hcl`)

Shared across all builds:

```hcl
# Proxmox connection
proxmox_host = "192.168.1.100"
token_id     = "packer@pve!packer-token"
token_secret = "your-secret-here"
node         = "pve"
pool         = ""

# Storage
storage_pool            = "local-lvm"
cloud_init_storage_pool = "local-lvm"

# Network
network_bridge = "vmbr0"

# Build credentials
username = "packer"
password = "packer"

# Guest OS
guest_os_language = "en_US"
guest_os_keyboard = "us"
guest_os_timezone = "UTC"
```

### Base-Specific Variables

Override in `base/` builds:

```bash
packer build \
  -var-file=../common.auto.pkrvars.hcl \
  -var vm_id_base=9000 \
  -var disk_size_base="20G" \
  .
```

### Configured-Specific Variables

Override in `configured/` builds:

```bash
packer build \
  -var-file=../common.auto.pkrvars.hcl \
  -var ansible_host_type=docker \
  -var vm_id_configured=9101 \
  -var clone_template="debian-12-base" \
  .
```

## Ansible Integration

The `configured` builds use Ansible for provisioning. The playbook should support different host types:

```yaml
# ansible/playbook.yml
- hosts: all
  become: yes
  vars:
    host_type: "{{ host_type | default('base') }}"
  roles:
    - common
    - role: docker
      when: host_type == "docker"
    - role: database
      when: host_type == "database"
    - role: webserver
      when: host_type == "webserver"
```

## Template Naming Convention

| Template Name | VM ID | Source | Purpose |
|--------------|-------|---------|----------|
| `debian-12-base` | 9000 | ISO | Foundation template |
| `debian-12-base` (configured) | 9100 | Clone | Base + hardening |
| `debian-12-docker` | 9101 | Clone | Docker host |
| `debian-12-database` | 9102 | Clone | Database server |
| `debian-12-webserver` | 9103 | Clone | Web server |
| `debian-12-monitoring` | 9104 | Clone | Monitoring stack |

## Benefits of Chained Builds

1. **Faster Iteration**
   - Base template built once from ISO (~20 min)
   - Subsequent builds clone base (~5 min)
   - No need to reinstall OS for each variant

2. **Consistency**
   - All templates share same base OS installation
   - Ensures uniform security posture
   - Simplified maintenance

3. **Modularity**
   - Each layer has single responsibility
   - Easy to add new configured types
   - Clear separation of concerns

4. **Resource Efficiency**
   - Templates share base disk (if using linked clones)
   - Faster builds = less Proxmox load
   - Easier to test changes

## Troubleshooting

### Base Build Issues

**Problem:** ISO checksum mismatch
```bash
# Update checksum in base/variables.pkr.hcl or override:
packer build -var iso_checksum="sha256:actual-checksum" .
```

**Problem:** SSH timeout during base build
- Increase `ssh_timeout` in base/sources.pkr.hcl
- Check network connectivity to VM
- Verify kickstart preseed is working

### Configured Build Issues

**Problem:** Template not found
```bash
# Verify base template exists in Proxmox
# Check template name matches clone_template variable
packer build -var clone_template="actual-template-name" .
```

**Problem:** Ansible provisioner fails
- Verify SSH key authentication works
- Check Ansible playbook path
- Ensure `host_type` variable is passed correctly
- Review Ansible logs in build output

### Common Issues

**Problem:** Permission errors
- Verify Packer user has correct Proxmox privileges
- Check token hasn't expired
- Ensure resource pool exists (or set to "")

**Problem:** VM ID conflicts
- Use `-var vm_id_configured=XXXX` to specify unique ID
- Or set to `null` for auto-assignment

## Advanced Usage

### Creating Custom Configured Types

1. Update Ansible playbook with new role
2. Build configured template:
   ```bash
   ./build-chain.sh configured my-custom-type --vm-id 9110
   ```

### Parallel Builds

Build multiple configured types simultaneously:

```bash
cd configured/
packer build -parallel-builds=3 \
  -var-file=../common.auto.pkrvars.hcl \
  -var ansible_host_type=docker -var vm_id_configured=9101 . &
packer build -parallel-builds=3 \
  -var-file=../common.auto.pkrvars.hcl \
  -var ansible_host_type=database -var vm_id_configured=9102 . &
packer build -parallel-builds=3 \
  -var-file=../common.auto.pkrvars.hcl \
  -var ansible_host_type=webserver -var vm_id_configured=9103 . &
wait
```

### CI/CD Integration

Example GitHub Actions workflow:

```yaml
name: Build Templates
on: [push]
jobs:
  build-base:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build base template
        run: cd builds/proxmox/linux/debian/12 && ./build-chain.sh base
  
  build-configured:
    needs: build-base
    strategy:
      matrix:
        type: [docker, database, webserver]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build ${{ matrix.type }} template
        run: cd builds/proxmox/linux/debian/12 && ./build-chain.sh configured ${{ matrix.type }}
```

## Maintenance

### Updating Base Template

When you need to update the base OS:

1. Build new base template
2. Rebuild configured templates that depend on it
3. Test new templates
4. Remove old templates

```bash
./build-chain.sh base
./build-chain.sh configured docker
./build-chain.sh configured database
# etc.
```

### Version Control

Manifests are saved with timestamps in `*/manifests/` directories:
- Track build versions
- Reference build metadata
- Audit trail for changes

## Security Considerations

1. **Credentials**
   - Never commit `common.auto.pkrvars.hcl` with real credentials
   - Use `.gitignore` for `*.auto.pkrvars.hcl`
   - Consider using Vault or environment variables in CI/CD

2. **Templates**
   - Base template should be hardened
   - Disable unnecessary services
   - Apply security patches regularly

3. **SSH Keys**
   - Packer generates ephemeral SSH keys per build
   - Remove build SSH keys in final provisioning step
   - Use cloud-init for production deployments

## Support

For issues or questions:
- Check Proxmox logs: `/var/log/pve/tasks/`
- Review Packer logs with `-debug` flag
- Verify Ansible playbook independently

## License

See main repository LICENSE file.
