# GitHub Copilot Instructions for hashicorp.packer.builds

## Repository Overview

This repository contains HashiCorp Packer configurations for building virtual machine templates and Amazon Machine Images (AMIs) across multiple platforms (Proxmox VE and AWS) and operating systems (Linux and Windows).

## Project Structure

```
builds/
├── proxmox/
│   ├── linux/
│   │   └── debian/
│   │       ├── 12/  # Bookworm
│   │       │   ├── base/         # VM 9000 - Foundation template (proxmox-iso)
│   │       │   ├── hardened/     # VM 9001-9004 - Security-focused (proxmox-clone)
│   │       │   └── minimal/      # VM 9005-9008 - Lightweight (proxmox-clone)
│   │       └── 13/  # Trixie (proxmox-iso)
│   └── windows/
│       ├── desktop/
│       │   ├── 10/
│       │   │   ├── base/         # VM 9020 (proxmox-iso)
│       │   │   └── minimal/      # VM 9021 (proxmox-clone)
│       │   └── 11/
│       │       └── base/         # VM 9023 (proxmox-iso with UEFI)
│       └── server/
│           ├── 2019/
│           │   ├── base/         # VM 9010 (proxmox-iso)
│           │   ├── minimal/      # VM 9011 (proxmox-clone)
│           │   └── hardened/     # VM 9012 (proxmox-clone)
│           └── 2022/
│               └── base/         # VM 9013 (proxmox-iso)
├── aws/
│   ├── linux/
│   │   ├── debian/
│   │   └── ubuntu/
│   └── windows/
│       ├── desktop/
│       └── server/
scripts/
├── buildManager.py
├── install-eset-agent.ps1
├── windows-init.ps1
└── windows-prepare.ps1
.github/
└── workflows/
    ├── build-all.yml              # (DISABLED) Matrix builds
    ├── build-windows-base.yml     # Windows Server 2019 & Windows 10 base
    └── test-debian12-build.yml    # Debian 12 base + hardened variants
```

## Core Technologies

### Packer Configuration
- **Version**: >= 1.9.4
- **Format**: HCL2 (HashiCorp Configuration Language)
- **File Structure**: Each build directory contains:
  - `build.pkr.hcl` - Build definitions, provisioners, post-processors
  - `sources.pkr.hcl` - Builder configurations (proxmox-iso, proxmox-clone)
  - `variables.pkr.hcl` - Variable definitions
  - `data/` - Template files (autounattend.xml, kickstart, cloud-init)
  - `manifests/` - Build output metadata (JSON)

### Required Plugins
- **proxmox** (>= 1.1.3) - Proxmox VE integration
- **windows-update** (>= 0.14.3) - Windows Update automation
- **git** (>= 0.4.3) - Git metadata in templates
- **sshkey** (>= 1.0.1) - SSH key generation for Linux builds

### Builders
- **proxmox-iso**: Builds from ISO images (base templates)
- **proxmox-clone**: Clones existing VMs (derived templates)
- **amazon-ebs**: AWS AMI builds

## Development Patterns

### 1. Linux Build Workflow (Debian 12 Example)

**Base Template** (VM 9000):
```hcl
// Use proxmox-iso builder
source "proxmox-iso" "debian_12_base" {
  iso_url          = "https://cdimage.debian.org/debian-cd/12.9.0/amd64/iso-cd/debian-12.9.0-amd64-netinst.iso"
  iso_checksum     = "sha512:..."
  boot_command     = ["<esc><wait>auto url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg<enter>"]
  http_content     = local.source_content  # Kickstart config
  ssh_username     = var.username
  ssh_private_key_file = local.build_key
}
```

**Hardened/Minimal Templates** (VM 9001-9008):
```hcl
// Use proxmox-clone builder
source "proxmox-clone" "debian_12_hardened_apache" {
  clone_vm_id = 9000  # Clone from base
  vm_id       = 9001
  vm_name     = "debian12-hardened-apache"
}

build {
  sources = ["source.proxmox-clone.debian_12_hardened_apache"]
  
  provisioner "ansible-local" {
    playbook_file = "../../ansible/site.yml"
    extra_arguments = ["--tags", "apache,hardened"]
  }
}
```

### 2. Windows Build Workflow

**Base Template with UEFI** (Windows 11):
```hcl
source "proxmox-iso" "windows_11_base" {
  bios                = "ovmf"  # UEFI firmware
  machine             = "q35"   # Modern chipset
  efi_config {
    efi_storage_pool  = var.disk_storage_pool
    efi_type          = "4m"
    pre_enrolled_keys = true
  }
  boot_iso {
    type         = "ide"  # IDE for better UEFI compatibility
    iso_file     = "local:iso/windows-11-25H2.iso"
  }
  boot                = "order=scsi0;ide2"  # Disk first, then CD
  winrm_username      = "Administrator"
  winrm_timeout       = "120m"
}
```

**Windows Provisioners**:
```hcl
// ESET Protect Agent installation
provisioner "file" {
  source      = "../../scripts/install_config.ini"
  destination = "C:\\Windows\\Temp\\install_config.ini"
}

provisioner "powershell" {
  elevated_user     = "Administrator"
  elevated_password = var.password
  scripts           = ["../../scripts/install-eset-agent.ps1"]
}

// Windows Updates
provisioner "windows-update" {
  search_criteria = "IsInstalled=0"
  update_limit    = 25
}

// Sysprep
provisioner "powershell" {
  elevated_user     = "Administrator"
  elevated_password = var.password
  inline = [
    "C:\\Windows\\System32\\Sysprep\\sysprep.exe /generalize /oobe /shutdown /quiet /unattend:C:\\Windows\\Temp\\unattend.xml"
  ]
}
```

### 3. Git Metadata Integration

All templates include build metadata:
```hcl
data "git-commit" "build" {
  path = "${path.root}/../../../../"
}

locals {
  build_by          = "Built by: Hashicorp Packer ${packer.version}"
  build_date        = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
  build_version     = try(data.git-commit.build.hash, env("GITHUB_SHA"), "unknown")
  git_author        = try(data.git-commit.build.author, env("GITHUB_ACTOR"), "unknown")
  git_committer     = try(data.git-commit.build.committer, env("GITHUB_ACTOR"), "unknown")
  git_timestamp     = try(data.git-commit.build.timestamp, timestamp(), "unknown")
}

source "proxmox-iso" "example" {
  template_description = <<-EOT
    Version: ${local.build_version}
    Built on: ${local.build_date}
    Author: ${local.git_author}
    Committer: ${local.git_committer}
    Commit Date: ${local.git_timestamp}
    ${local.build_by}
  EOT
}
```

### 4. Variable Management

**Common Variables**:
```hcl
// Proxmox connection
variable "proxmox_host" {
  type        = string
  description = "IP address or resolvable hostname of the proxmox host"
}

variable "token_id" {
  type        = string
  description = "API Token ID in $username@pve!$token_id format"
}

variable "token_secret" {
  type        = string
  description = "The API token secret"
  sensitive   = true
}

// Build credentials
variable "username" {
  type        = string
  description = "Build username for SSH/WinRM connections"
  default     = "Administrator"  # Windows
  # default   = "ansible"        # Linux
}

variable "password" {
  type        = string
  description = "Build password"
  sensitive   = true
}
```

**Passing Variables**:
```bash
# CLI
packer build \
  -var="proxmox_host=192.168.1.160" \
  -var="token_id=build@pve!packer" \
  -var="token_secret=xxx" \
  .

# Variable file (recommended)
# Create local.auto.pkrvars.hcl
proxmox_host = "192.168.1.160"
token_id     = "build@pve!packer"
token_secret = "xxx"
```

## CI/CD Workflows

### GitHub Actions Secrets
Required secrets for workflows:
- `PROXMOX_HOST` - Proxmox server IP/hostname
- `PROXMOX_TOKEN_ID` - API token ID
- `PROXMOX_TOKEN_SECRET` - API token secret
- `PROXMOX_NODE` - Node name (e.g., "hades")
- `PROXMOX_POOL` - Resource pool (e.g., "packer_builds")
- `PROXMOX_ISO_STORAGE` - ISO storage pool (default: "local")
- `PROXMOX_DISK_STORAGE` - Disk storage pool (default: "local-lvm")
- `PROXMOX_CLOUDINIT_STORAGE` - Cloud-init storage (Linux only)

### Workflow Patterns

**Manual Trigger** (workflow_dispatch):
```yaml
name: Build Windows Base Templates
on:
  workflow_dispatch:

jobs:
  build-windows-server-2019-base:
    runs-on: self-hosted
    timeout-minutes: 180
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-packer@main
      - run: packer init .
        working-directory: builds/proxmox/windows/server/2019/base
      - run: packer validate .
        working-directory: builds/proxmox/windows/server/2019/base
        env:
          PKR_VAR_proxmox_host: ${{ secrets.PROXMOX_HOST }}
          PKR_VAR_token_id: ${{ secrets.PROXMOX_TOKEN_ID }}
          PKR_VAR_token_secret: ${{ secrets.PROXMOX_TOKEN_SECRET }}
      - run: packer build -timestamp-ui .
```

## Common Patterns & Best Practices

### 1. Template Files (.pkrtpl.hcl)
Windows AutoUnattend:
```hcl
<?xml version="1.0" encoding="UTF-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
   <settings pass="oobeSystem">
      <component name="Microsoft-Windows-Shell-Setup">
         <AutoLogon>
            <Password>
               <Value>${password}</Value>
               <PlainText>true</PlainText>
            </Password>
            <Enabled>true</Enabled>
            <Username>Administrator</Username>
            <!-- LogonCount removed for indefinite autologon -->
         </AutoLogon>
      </component>
   </settings>
</unattend>
```

Linux Kickstart:
```hcl
# Use templatefile() function
locals {
  source_content = {
    "/ks.cfg" = templatefile("${abspath(path.root)}/data/ks.pkrtpl.hcl", {
      username   = var.username
      password   = bcrypt(var.password)
      build_key  = data.sshkey.install.private_key_path
    })
  }
}
```

### 2. Build Commands

```bash
# Initialize (download plugins)
packer init .

# Validate configuration
packer validate .

# Format HCL files
packer fmt .

# Build specific source
packer build -only='proxmox-clone.debian_12_hardened_apache' .

# Build with debug
PACKER_LOG=1 packer build .

# Build with timestamp UI
packer build -timestamp-ui .
```

### 3. Provisioner Ordering

**Windows**:
1. File provisioners (copy configs)
2. ESET Protect agent installation
3. Windows-prepare scripts
4. Windows Updates
5. Sysprep/generalization

**Linux**:
1. Shell provisioners (install dependencies)
2. Ansible-local provisioners
3. Cleanup scripts

### 4. Error Handling

Common issues:
- **WinRM timeout**: Increase `winrm_timeout` (default: 60m, Windows 11: 120m)
- **Boot loop (UEFI)**: Use `bios="ovmf"`, `machine="q35"`, `boot="order=scsi0;ide2"`
- **File not found**: Use absolute paths (`C:\\Windows\\Temp`) not `$PSScriptRoot`
- **SSH timeout**: Check `ssh_timeout`, verify SSH keys and network connectivity

## Security Considerations

### 1. Sensitive Data
- Never commit credentials in `.pkrvars.hcl` files
- Use `local.auto.pkrvars.hcl` (gitignored)
- Mark sensitive variables: `sensitive = true`
- Use GitHub Secrets for CI/CD

### 2. Template Security
- ESET Protect agent installed on all Windows templates
- SSH hardening on Linux templates
- Firewall rules configured
- Regular Windows Updates via `windows-update` provisioner
- CIS benchmarks applied in hardened variants

### 3. .gitignore Patterns
```
*.log
packer_cache/
*.secret
local.auto.pkrvars.hcl
variables.pkrvars.hcl
.DS_Store
crash.log
```

## Scripts Overview

### Windows Scripts

**install-eset-agent.ps1**:
- Downloads ESET Protect agent from official URL
- Requires `install_config.ini` in `C:\Windows\Temp`
- Silent installation with logging to `%TEMP%\era-agent-install.log`
- Exit codes: 0=success, 3010=reboot required

**windows-prepare.ps1**:
- Disables unnecessary services
- Configures Windows features
- Prepares for Sysprep

**windows-init.ps1**:
- Initial configuration scripts

### Python Scripts

**buildManager.py**:
- Orchestrates multiple Packer builds
- Manages build dependencies (base → minimal → hardened)
- Progress tracking and error reporting

## VM ID Allocation

### Proxmox VE
| VM ID | Template | Type |
|-------|----------|------|
| 9000 | Debian 12 Base | Base (ISO) |
| 9001-9004 | Debian 12 Hardened (apache, docker, mysql, tomcat) | Clone |
| 9005-9008 | Debian 12 Minimal (apache, docker, mysql, tomcat) | Clone |
| 9010 | Windows Server 2019 Base | Base (ISO) |
| 9011 | Windows Server 2019 Minimal | Clone |
| 9012 | Windows Server 2019 Hardened | Clone |
| 9013 | Windows Server 2022 Base | Base (ISO) |
| 9020 | Windows 10 Base | Base (ISO) |
| 9021 | Windows 10 Minimal | Clone |
| 9022 | Windows 10 Hardened | Clone |
| 9023 | Windows 11 Base | Base (ISO) |

## Copilot-Specific Guidance

When generating code for this repository:

### Do:
- ✅ Use HCL2 syntax for all Packer configurations
- ✅ Follow the three-tier pattern: base (ISO) → minimal/hardened (clone)
- ✅ Include git metadata in all templates
- ✅ Use `proxmox-iso` for base builds, `proxmox-clone` for variants
- ✅ Add proper error handling in PowerShell scripts
- ✅ Use `templatefile()` for dynamic content generation
- ✅ Include manifest post-processors for tracking builds
- ✅ Follow existing VM ID allocation scheme
- ✅ Use absolute paths in Windows provisioners (`C:\Windows\Temp`)
- ✅ Add UEFI configuration for Windows 11 builds
- ✅ Include `windows-update` provisioner before Sysprep
- ✅ Position ESET installation before Windows Updates

### Don't:
- ❌ Mix Packer JSON and HCL formats
- ❌ Hardcode credentials in source files
- ❌ Use relative paths in PowerShell scripts (`$PSScriptRoot` unreliable)
- ❌ Skip validation before building
- ❌ Commit `.pkrvars.hcl` files with secrets
- ❌ Use BIOS for Windows 11 (requires UEFI)
- ❌ Put CD-ROM before disk in UEFI boot order
- ❌ Remove LogonCount without user approval (security consideration)

### Code Completion Context
When completing:
- **Variable references**: Use `var.` prefix
- **Local values**: Use `local.` prefix
- **Data sources**: Use `data.` prefix
- **Packer functions**: `templatefile()`, `bcrypt()`, `formatdate()`, `timestamp()`
- **Builder types**: Check if base (proxmox-iso) or derived (proxmox-clone)
- **Provisioner order**: file → powershell/shell → windows-update/ansible → sysprep/cleanup

### Commit Message Format
Follow conventional commits:
```
feat(windows-10): Add ESET Protect agent installation
fix(debian-12): Correct cloud-init storage pool reference
refactor(windows-server-2019): Configure indefinite AutoLogon
docs(readme): Update build instructions for Windows 11 UEFI
```

### Testing Recommendations
Before suggesting code:
1. Validate HCL syntax is correct
2. Ensure all required variables are defined
3. Check that file paths are consistent with repository structure
4. Verify builder type matches template tier (ISO vs clone)
5. Confirm provisioner order follows established patterns

## Additional Resources

- **Packer Documentation**: https://developer.hashicorp.com/packer/docs
- **Proxmox Plugin**: https://developer.hashicorp.com/packer/plugins/builders/proxmox
- **Windows Update Plugin**: https://github.com/rgl/packer-plugin-windows-update
- **Repository Documentation**: See `README.md`, `CONTRIBUTING.md`, `scripts/README.md`

## Quick Reference Commands

```bash
# Build base template
cd builds/proxmox/linux/debian/12/base && packer build .

# Build specific hardened variant
cd builds/proxmox/linux/debian/12/hardened
packer build -only='proxmox-clone.debian12-hardened-apache' .

# Validate all builds in directory
for dir in */; do (cd "$dir" && packer validate .); done

# Check what changed
git diff --name-only main...HEAD | grep '.pkr.hcl'

# Run Windows build with logging
cd builds/proxmox/windows/server/2019/base
PACKER_LOG=1 packer build . 2>&1 | tee build.log
```
