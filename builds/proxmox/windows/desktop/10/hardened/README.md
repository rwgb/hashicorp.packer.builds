# Windows 10 22H2 Hardened Build

This Packer configuration creates a security-hardened Windows 10 22H2 Professional template by cloning the minimal template (VM ID 9021) and applying comprehensive security configurations based on CIS Benchmarks.

## Overview

- **Source**: Clones from Windows 10 22H2 Minimal template (VM ID 9021)
- **Builder**: `proxmox-clone`
- **Target VM ID**: 9022
- **VM Name**: `win-10-22h2-hardened`
- **Purpose**: Security-hardened desktop template for production environments

## Features

### Security Hardening

- **Password Policies**: 14 character minimum, complexity required, 24 password history, 60-day max age
- **Account Lockout**: 5 failed attempts, 30-minute lockout duration
- **Windows Firewall**: Enabled on all profiles with default deny inbound
- **Audit Policies**: Comprehensive auditing for account logon, management, logon/logoff, object access, policy changes, privilege use, and system events
- **SMB Security**: SMBv1 disabled and removed, SMB signing enforced
- **Network Protection**: LLMNR and NetBIOS disabled
- **LSA Protection**: RunAsPPL and Credential Guard enabled
- **Script Security**: Windows Script Host disabled
- **AutoRun/AutoPlay**: Disabled for all drive types
- **Screen Saver**: 15-minute timeout with password lock
- **Secure Logon**: Ctrl+Alt+Del required
- **Legal Notice**: Login banner for authorized access warning
- **Privacy**: Camera, microphone, and location services disabled
- **Telemetry**: Windows telemetry and advertising ID disabled
- **Consumer Features**: Windows consumer features and suggestions disabled
- **Windows Defender**: Real-time protection, advanced MAPS reporting, controlled folder access enabled
- **TLS/SSL**: Only TLS 1.2 enabled (SSL 2.0/3.0, TLS 1.0/1.1 disabled)
- **Event Logs**: Increased log sizes (Security: 196MB, Application/System: 32MB)
- **Windows Updates**: Automatic updates configured
- **Legacy Features**: PowerShell v2 and SMBv1 removed

### Disabled Services

- RemoteRegistry
- RemoteAccess
- SSDPSRV (SSDP Discovery)
- upnphost (UPnP Device Host)
- WMPNetworkSvc (Windows Media Player Network Sharing)
- WerSvc (Windows Error Reporting)
- Browser (Computer Browser)
- lmhosts (TCP/IP NetBIOS Helper)
- XblAuthManager (Xbox Live Auth Manager)
- XblGameSave (Xbox Live Game Save)
- XboxNetApiSvc (Xbox Live Networking Service)
- XboxGipSvc (Xbox Accessory Management)

## Prerequisites

1. **Minimal Template**: Windows 10 22H2 Minimal (VM ID 9021) must exist
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
- `username`: Build username (default: "Administrator")
- `password`: Administrator password (sensitive)

### VM Specifications

- **VM ID**: 9022
- **Name**: win-10-22h2-hardened
- **Memory**: 4096 MB
- **CPU**: 1 socket, 2 cores
- **Disk**: Inherited from minimal template (60GB)
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

1. **Clone Minimal Template**: Creates full clone from VM ID 9021
2. **Boot and Connect**: Starts VM and establishes WinRM connection
3. **Security Hardening**:
   - Configure password and account policies
   - Enable and configure Windows Firewall
   - Disable unnecessary services
   - Configure comprehensive audit policies
   - Apply registry security settings
   - Configure Windows Defender
   - Configure TLS/SSL security
   - Increase event log sizes
   - Configure Windows Update
   - Remove unnecessary features
4. **Windows Updates**: Installs available updates (up to 25 per run)
5. **Cleanup**: Remove temporary files
6. **Post-Processing**: Generates build manifest

## Build Time

- **Typical Duration**: 60-120 minutes
- **Clone Time**: ~2-5 minutes
- **Security Hardening**: ~15-20 minutes
- **Windows Updates**: 40-90 minutes (varies by update count)
- **Cleanup**: ~2-5 minutes

## Output

### Build Artifacts

- **Template VM**: Production-ready hardened template in Proxmox
- **Manifest**: JSON file in `./manifests/` with build metadata and security level

### Manifest Contents

```json
{
  "builds": [{
    "name": "windows_10_22h2_hardened",
    "builder_type": "proxmox-clone",
    "artifact_id": "9022",
    "custom_data": {
      "build_type": "hardened",
      "build_username": "Administrator",
      "build_date": "2025-12-11 ...",
      "build_version": "git-hash",
      "security_level": "CIS Benchmarks",
      "author": "...",
      "committer": "...",
      "timestamp": "..."
    }
  }]
}
```

## Template Usage

After the build completes, the template can be used to create new secure VMs:

```bash
# Clone the template
qm clone 9022 100 --name my-secure-windows-10-vm

# Start the VM
qm start 100
```

## Security Compliance

This template implements security hardening based on:

- **CIS Microsoft Windows 10 Enterprise Benchmark v2.0.0**
- **DISA STIG for Windows 10**
- **Microsoft Security Baseline for Windows 10**

### Key Compliance Areas

- Access Control (Account policies, lockout policies)
- Authentication (Secure logon, LSA protection)
- Network Security (Firewall, SMB signing, protocol hardening)
- Audit and Accountability (Comprehensive audit policies, event log retention)
- System Hardening (Service reduction, feature removal, registry hardening)
- Privacy Controls (Telemetry, consumer features, privacy settings)
- Encryption (TLS 1.2 enforcement)
- Malware Protection (Windows Defender configuration)

## Customization

### Adjusting Password Policies

Modify the password policy provisioner in `build.pkr.hcl`:

```hcl
"$secpol = $secpol -replace 'MinimumPasswordLength = .*', 'MinimumPasswordLength = 16'",  # Increase to 16 chars
"$secpol = $secpol -replace 'MaximumPasswordAge = .*', 'MaximumPasswordAge = 90'",        # Change to 90 days
```

### Adding Additional Service Disabling

Add services to the list in the service disabling provisioner:

```hcl
"$services = @('RemoteRegistry','RemoteAccess','SSDPSRV','upnphost','WMPNetworkSvc','WerSvc','Browser','lmhosts','XblAuthManager','XblGameSave','XboxNetApiSvc','XboxGipSvc','YourServiceName')",
```

### Modifying Firewall Rules

Add custom firewall rules in the firewall provisioner:

```hcl
provisioner "powershell" {
  inline = [
    "New-NetFirewallRule -DisplayName 'Allow HTTPS' -Direction Inbound -Protocol TCP -LocalPort 443 -Action Allow"
  ]
}
```

### Changing Windows Update Settings

Adjust the Windows Update provisioner:

```hcl
provisioner "windows-update" {
  update_limit = 50  # Increase update limit
  filters = [
    "exclude:$_.Title -like '*Preview*'",
    "include:$true"
  ]
}
```

## Troubleshooting

### WinRM Connection Issues

If WinRM fails to connect:

1. Verify minimal template (VM 9021) has WinRM enabled
2. Check network connectivity
3. Verify Administrator password matches `var.password`
4. Increase `winrm_timeout` in sources.pkr.hcl if hardening takes longer

### Clone Failures

If cloning fails:

- Verify VM 9021 exists and is accessible
- Check Proxmox storage availability
- Ensure sufficient disk space
- Verify API token permissions

### Security Policy Failures

If security policies fail to apply:

- Check build logs for specific policy errors
- Some policies may require specific Windows editions
- Verify Windows version supports all features (e.g., Credential Guard)
- Review event logs in the VM for detailed error messages

### Windows Update Errors

If updates fail:

- Check VM internet connectivity
- Review Windows Update logs in the VM
- Increase `winrm_timeout` in sources.pkr.hcl
- Reduce `update_limit` to install fewer updates per run
- Run build again to install remaining updates

## Post-Build Verification

After building, verify security settings:

```powershell
# Check firewall status
Get-NetFirewallProfile

# Check audit policies
auditpol /get /category:*

# Check disabled services
Get-Service | Where-Object {$_.StartType -eq 'Disabled'} | Select-Object Name, DisplayName

# Check password policy
net accounts

# Check TLS configuration
Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server'

# Check Windows Defender status
Get-MpPreference
```

## Maintenance

### Updating Minimal Template

When the minimal template is updated:

1. No changes needed to this build
2. Next build will clone from updated minimal template
3. Consider rebuilding hardened template after minimal updates

### Periodic Hardening Updates

Review and update hardening configurations regularly:

1. Check for new CIS Benchmark releases
2. Review DISA STIG updates
3. Update security policies as needed
4. Test changes in non-production environment first

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
- [Minimal Build](../minimal/README.md)
- [WinRM Tool](../../../../../utils/README.md)
- [Packer Proxmox Builder](https://www.packer.io/plugins/builders/proxmox/clone)
- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks/)
- [Microsoft Security Baselines](https://docs.microsoft.com/en-us/windows/security/threat-protection/windows-security-baselines)

## Security Considerations

### Important Notes

- **Password Policy**: The template enforces a 14-character minimum password. Ensure you update the Administrator password after deployment to meet this requirement.
- **Firewall**: Default deny inbound rules are configured. Configure required firewall rules after deployment.
- **Services**: Many services are disabled. Re-enable only those required for your specific use case.
- **Updates**: Keep the template updated with the latest Windows security updates.
- **Testing**: Always test hardened templates in a non-production environment before deployment.

### Recommended Post-Deployment Steps

1. Change Administrator password to meet new complexity requirements
2. Configure required firewall rules for your applications
3. Enable only necessary services
4. Join to domain (if applicable) and apply Group Policies
5. Configure local users and groups as needed
6. Install required applications
7. Configure backup and monitoring
8. Document changes and exceptions to hardening baseline

## Tags

The template is tagged with:
- `windows`
- `desktop`
- `windows-10`
- `22h2`
- `template`
- `hardened`
- `security`
