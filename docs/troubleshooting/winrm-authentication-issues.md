# WinRM Authentication Issues with Windows 10 Packer Builds

## Issue Summary

When building Windows 10 templates with Packer, WinRM authentication consistently failed with `401 - invalid content type` errors, preventing the build from completing. This occurred despite WinRM being properly configured and responsive on the Windows VM.

## Symptoms

- Packer build times out after 2+ hours with "Timeout waiting for WinRM"
- Continuous `401 - invalid content type` errors in packer logs
- WinRM service is running and responds to `Test-WSMan` commands
- Manual authentication tests using `pywinrm` succeed with NTLM
- QEMU Guest Agent reports correct IP address

## Root Causes

### 1. Built-in Administrator Account Disabled

**Problem**: Windows 10 disables the built-in Administrator account by default. When autounattend.xml creates a LocalAccount with the name "Administrator", it creates a separate local user account, not the built-in Administrator account that Packer expects.

**Impact**: Packer attempts to authenticate as the built-in Administrator but fails because the account is disabled.

### 2. Conflicting LocalAccount Creation

**Problem**: Autounattend.xml was configured to create a LocalAccount named "Administrator" while also setting the AdministratorPassword. This creates confusion about which account should be used.

**Impact**: The LocalAccount creation conflicts with the built-in Administrator account setup.

### 3. Packer WinRM NTLM Compatibility

**Problem**: Packer's Go-based WinRM implementation has compatibility issues with Windows 10's NTLM authentication, despite NTLM being properly configured and working with other WinRM clients (like `pywinrm`).

**Impact**: Even with correct credentials and WinRM configuration, Packer cannot authenticate using NTLM.

## Solution

### Step 1: Enable Built-in Administrator Account

Add a FirstLogonCommand in autounattend.xml to explicitly enable the built-in Administrator account:

```xml
<FirstLogonCommands>
   <SynchronousCommand wcm:action="add">
      <CommandLine>cmd /c net user Administrator /active:yes</CommandLine>
      <Description>Enable Built-in Administrator Account</Description>
      <Order>1</Order>
      <RequiresUserInput>false</RequiresUserInput>
   </SynchronousCommand>
   <!-- Other commands follow -->
</FirstLogonCommands>
```

### Step 2: Remove Conflicting LocalAccount Creation

Remove the `<LocalAccounts>` section from autounattend.xml. Only set the `AdministratorPassword`:

```xml
<UserAccounts>
   <AdministratorPassword>
      <Value>${password}</Value>
      <PlainText>true</PlainText>
   </AdministratorPassword>
   <!-- DO NOT create a LocalAccount named Administrator -->
</UserAccounts>
```

### Step 3: Use Basic Authentication Instead of NTLM

In Packer's `sources.pkr.hcl`, configure WinRM to use Basic authentication:

```hcl
communicator     = "winrm"
winrm_username   = var.username
winrm_password   = var.password
winrm_port       = 5985
winrm_timeout    = "120m"
winrm_insecure   = true
winrm_use_ssl    = false
winrm_use_ntlm   = false    // Use Basic auth instead
winrm_no_proxy   = true     // Prevent proxy interference
```

### Step 4: Configure Credentials

Set the username to "Administrator" in `variables.auto.pkrvars.hcl`:

```hcl
username = "Administrator"
password = "packer"
```

### Step 5: Ensure WinRM Configuration in windows-init.ps1

The `windows-init.ps1` script should enable Basic authentication:

```powershell
# Enable Basic Authentication
Write-Host "[INFO] Enabling Basic authentication"
Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true

# Allow unencrypted traffic
Write-Host "[INFO] Allowing unencrypted WinRM traffic"
Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $true

# Configure WinRM service
Write-Host "[INFO] Configuring WinRM service"
winrm quickconfig -quiet -force

# Restart WinRM to apply changes
Write-Host "[INFO] Restarting WinRM service"
Restart-Service WinRM
Start-Sleep -Seconds 5
```

## Verification Steps

### 1. Test WinRM Connectivity

Use the provided `testWinrm.py` script to verify authentication before running Packer:

```bash
python testWinrm.py <VM_IP_ADDRESS> --diagnostics
```

Expected output:
```
✓ NTLM Auth:   ✓ PASSED
✓ WinRM is configured correctly for Packer!
```

### 2. Verify Account Configuration

From the VM console or via WinRM, check that:
- Built-in Administrator is enabled: `net user Administrator`
- Administrator is in the administrators group: `net localgroup administrators`
- BUILD_USER environment variable is set: `echo $env:BUILD_USER`

### 3. Check Packer Logs

Monitor `packer-build.log` for successful connection:
```
[INFO] Attempting WinRM connection...
WinRM connected.
Connected to WinRM!
```

## Testing Script

A Python test script (`testWinrm.py`) is available to validate WinRM authentication outside of Packer:

```python
# Test both Basic and NTLM authentication
python testWinrm.py 192.168.1.32 --diagnostics

# Test with custom credentials
python testWinrm.py 192.168.1.32 -u Administrator -p packer
```

## Timeline of Changes

1. **Initial issue**: 401 authentication errors with NTLM enabled
2. **Added Administrator enablement**: `net user Administrator /active:yes` in FirstLogonCommands
3. **Removed conflicting LocalAccount**: Eliminated LocalAccount creation in autounattend.xml
4. **Switched to Basic auth**: Changed `winrm_use_ntlm` from `true` to `false`
5. **Added no_proxy setting**: Set `winrm_no_proxy = true` to prevent proxy interference
6. **Result**: Successful WinRM connection and build completion

## Key Learnings

1. **Windows 10 defaults**: The built-in Administrator account is disabled by default in Windows 10
2. **Account naming conflicts**: Creating a LocalAccount named "Administrator" does not enable the built-in Administrator
3. **Packer NTLM issues**: Packer's WinRM implementation may have NTLM compatibility issues with Windows 10
4. **Basic auth works**: While less secure, Basic auth over HTTP (in isolated build networks) is reliable
5. **Test independently**: Use standalone WinRM clients (like `pywinrm`) to isolate Packer-specific issues

## Security Considerations

- Basic authentication transmits credentials in base64 encoding (not encrypted)
- Only use Basic auth over HTTP in isolated/trusted build networks
- Consider HTTPS with Basic auth for production environments
- The built-in Administrator account should be disabled/renamed after template creation
- Use strong, unique passwords for build accounts

## Related Files

- `builds/proxmox/windows/desktop/10/base/sources.pkr.hcl` - WinRM configuration
- `builds/proxmox/windows/desktop/10/base/data/autounattend.pkrtpl.hcl` - Windows unattended setup
- `builds/proxmox/windows/desktop/10/base/variables.auto.pkrvars.hcl` - Credentials
- `builds/proxmox/windows/scripts/windows-init.ps1` - WinRM initialization script
- `builds/proxmox/windows/desktop/10/base/testWinrm.py` - WinRM testing utility

## References

- [Packer WinRM Communicator Documentation](https://www.packer.io/docs/communicators/winrm)
- [Microsoft WinRM Configuration](https://docs.microsoft.com/en-us/windows/win32/winrm/installation-and-configuration-for-windows-remote-management)
- [Windows Unattended Installation Reference](https://docs.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/)
