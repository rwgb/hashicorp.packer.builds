# Windows 10 22H2 Minimal Build

This Packer configuration creates a minimal Windows 10 22H2 Professional template by cloning the base template (VM ID 9020) and applying additional provisioning.

## Overview

- **Source**: Clones from Windows 10 22H2 Base template (VM ID 9020)
- **Builder**: `proxmox-clone`
- **Target VM ID**: 9021
- **VM Name**: `win-10-22h2-minimal`
- **Purpose**: Minimal desktop template with Windows updates

## Features

- Cloned from tested base template
- Custom user account creation
- Windows Update provisioning
- Reduced resource allocation (4GB RAM, 2 cores)
- Remote Desktop enabled
- Build manifest generation

## Prerequisites

1. **Base Template**: Windows 10 22H2 Base (VM ID 9020) must exist
2. **Proxmox Access**: Valid API token with appropriate permissions
3. **Packer**: Version >= 1.9.4
4. **Network**: VM must have network access for Windows Updates

## Configuration

### Variables

The build uses the following variables (defined in `variables.auto.pkrvars.hcl`):

- `proxmox_host`: Proxmox server address
- `token_id`: API token ID
- `token_secret`: API token secret (sensitive)
- `node`: Proxmox node name
- `pool`: Resource pool name
- `username`: Build username (default: "packer")
- `password`: Administrator password (sensitive)

### VM Specifications

- **VM ID**: 9021
- **Name**: win-10-22h2-minimal
- **Memory**: 4096 MB
- **CPU**: 1 socket, 2 cores
- **Disk**: Inherited from base template (60GB)
- **Network**: e1000 adapter on vmbr0

## Usage

### Initialize Packer

```bash
packer init .
```

### Validate Configuration

```bash
packer validate .
```

### Build Template

```bash
packer build .
```

### Build with Custom Variables

```bash
packer build -var-file="custom.pkrvars.hcl" .
```

## Build Process

1. **Clone Base Template**: Creates full clone from VM ID 9020
2. **Boot and Connect**: Starts VM and establishes WinRM connection
3. **Provisioning**:
   - Creates custom user account
   - Configures Windows Explorer settings
   - Disables hibernation
   - Disables legacy TLS versions
   - Installs Cloudbase-Init
   - Enables Remote Desktop
4. **Windows Updates**: Installs available updates (up to 25 per run)
5. **Post-Processing**: Generates build manifest

## Build Time

- **Typical Duration**: 45-90 minutes (depending on Windows Updates)
- **Clone Time**: ~2-5 minutes
- **Provisioning**: ~5-10 minutes
- **Windows Updates**: 30-75 minutes (varies by update count)

## Output

### Build Artifacts

- **Template VM**: Ready-to-use minimal template in Proxmox
- **Manifest**: JSON file in `./manifests/` with build metadata

### Manifest Contents

```json
{
  "builds": [{
    "name": "windows_10_22h2_minimal",
    "builder_type": "proxmox-clone",
    "artifact_id": "9021",
    "custom_data": {
      "build_username": "packer",
      "build_date": "2025-12-11 ...",
      "build_version": "git-hash",
      "build_type": "minimal",
      "author": "...",
      "committer": "...",
      "timestamp": "..."
    }
  }]
}
```

## Template Usage

After the build completes, the template can be used to create new VMs:

```bash
# Clone the template
qm clone 9021 100 --name my-windows-10-vm

# Start the VM
qm start 100
```

## Customization

### Adding Provisioners

Add additional provisioners in `build.pkr.hcl`:

```hcl
provisioner "powershell" {
  inline = [
    "Write-Host 'Custom provisioning step'"
  ]
}
```

### Modifying Windows Updates

Adjust filters in the `windows-update` provisioner:

```hcl
provisioner "windows-update" {
  filters = [
    "exclude:$_.Title -like '*Preview*'",
    "include:$true"
  ]
  update_limit = 50  # Increase update limit
}
```

### Changing VM Specifications

Modify `sources.pkr.hcl`:

```hcl
memory  = 8192  # Increase to 8GB RAM
cores   = 4     # Increase to 4 cores
```

## Troubleshooting

### WinRM Connection Issues

If WinRM fails to connect:

1. Verify base template (VM 9020) has WinRM enabled
2. Check network connectivity
3. Verify Administrator password matches `var.password`
4. Use the WinRM tool for diagnostics:

```bash
python ../../../../../utils/winrm-tool.py --host <VM-IP> --user Administrator --password packer
```

### Clone Failures

If cloning fails:

- Verify VM 9020 exists and is a template
- Check Proxmox storage availability
- Ensure sufficient disk space
- Verify API token permissions

### Windows Update Errors

If updates fail:

- Check VM internet connectivity
- Review Windows Update logs in the VM
- Increase `winrm_timeout` in sources.pkr.hcl
- Reduce `update_limit` to install fewer updates per run

## Maintenance

### Updating Base Template

When the base template is updated:

1. No changes needed to this build
2. Next build will clone from updated base
3. Consider rebuilding minimal template after base updates

### Cleaning Up

Remove old manifests:

```bash
rm -f manifests/*.json
```

Remove Packer cache:

```bash
rm -rf packer_cache/
```

## Related Documentation

- [Base Build](../base/README.md)
- [WinRM Tool](../../../../../utils/README.md)
- [Packer Proxmox Builder](https://www.packer.io/plugins/builders/proxmox/clone)

## Tags

The template is tagged with:
- `windows`
- `desktop`
- `windows-10`
- `22h2`
- `template`
- `minimal`
