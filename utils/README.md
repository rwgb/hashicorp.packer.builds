# WinRM Tool

A Python-based WinRM client for connecting to Windows VMs during Packer builds. This tool enables remote PowerShell/CMD access, command execution, and log file retrieval from Windows build machines.

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Usage Modes](#usage-modes)
- [Examples](#examples)
  - [Basic Examples](#basic-examples)
  - [Intermediate Examples](#intermediate-examples)
  - [Advanced Examples](#advanced-examples)
- [Troubleshooting](#troubleshooting)
- [Use Cases](#use-cases)

## Installation

### Prerequisites

- Python 3.6 or higher
- Network access to the Windows VM
- Valid Windows credentials

### Install Dependencies

```bash
pip install pywinrm
```

Or using a requirements file:

```bash
pip install -r requirements.txt
```

## Quick Start

The simplest way to connect to a Windows VM:

```bash
python utils/winrm-tool.py --host 192.168.1.95 --user Administrator --password packer
```

This opens an interactive PowerShell session where you can execute commands interactively.

## Usage Modes

The tool supports three primary modes:

1. **Interactive Shell** (default) - Start an interactive PowerShell session
2. **Single Command** - Execute one command and exit
3. **Log Retrieval** - Retrieve Packer build log files

### Command Line Options

```
--host         IP address or hostname of Windows VM (required)
--user         Windows username (default: Administrator)
--password     Windows password (default: packer)
--port         WinRM port (default: 5985)
--command      Execute a single PowerShell command and exit
--get-logs     Retrieve build log files and exit
--shell        Shell to use: powershell or cmd (default: powershell)
```

## Examples

### Basic Examples

#### 1. Interactive Shell Session

```bash
python utils/winrm-tool.py --host 192.168.1.95 --user Administrator --password packer
```

Once connected, you can run PowerShell commands:

```powershell
PS 192.168.1.95> Get-Service WinRM
PS 192.168.1.95> Get-Process | Select-Object -First 10
PS 192.168.1.95> hostname
PS 192.168.1.95> exit
```

#### 2. Retrieve Build Logs

```bash
python utils/winrm-tool.py --host 192.168.1.95 --user Administrator --password packer --get-logs
```

This retrieves both `windows-init.log` and `windows-prepare.log` from `C:\Windows\Temp\`.

#### 3. Execute Single Command

```bash
python utils/winrm-tool.py --host 192.168.1.95 --user Administrator --password packer \
    --command "Get-Service WinRM | Format-List"
```

#### 4. Check System Information

```bash
python utils/winrm-tool.py --host 192.168.1.95 --user Administrator --password packer \
    --command "Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, OsHardwareAbstractionLayer"
```

### Intermediate Examples

#### 5. Check WinRM Configuration

```bash
python utils/winrm-tool.py --host 192.168.1.95 --user Administrator --password packer \
    --command "winrm get winrm/config"
```

#### 6. Verify Network Profile

```bash
python utils/winrm-tool.py --host 192.168.1.95 --user Administrator --password packer \
    --command "Get-NetConnectionProfile | Select-Object Name, NetworkCategory, InterfaceAlias"
```

#### 7. Check Running Services

```bash
python utils/winrm-tool.py --host 192.168.1.95 --user Administrator --password packer \
    --command "Get-Service | Where-Object Status -eq 'Running' | Select-Object Name, DisplayName, Status"
```

#### 8. View Firewall Rules

```bash
python utils/winrm-tool.py --host 192.168.1.95 --user Administrator --password packer \
    --command "Get-NetFirewallRule | Where-Object DisplayName -like '*WinRM*' | Format-Table DisplayName, Enabled, Direction"
```

#### 9. Check Disk Space

```bash
python utils/winrm-tool.py --host 192.168.1.95 --user Administrator --password packer \
    --command "Get-PSDrive C | Select-Object Used, Free, @{Name='Total';Expression={(\$_.Used + \$_.Free)}}"
```

#### 10. List Installed Software

```bash
python utils/winrm-tool.py --host 192.168.1.95 --user Administrator --password packer \
    --command "Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object DisplayName, DisplayVersion, Publisher | Where-Object DisplayName -ne \$null"
```

### Advanced Examples

#### 11. Check Event Logs for Errors

```bash
python utils/winrm-tool.py --host 192.168.1.95 --user Administrator --password packer \
    --command "Get-EventLog -LogName System -Newest 20 -EntryType Error | Format-Table TimeGenerated, Source, Message -Wrap"
```

#### 12. Verify QEMU Guest Agent Installation

```bash
python utils/winrm-tool.py --host 192.168.1.95 --user Administrator --password packer \
    --command "Get-Service QEMU-GA | Format-List Name, Status, StartType; Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' | Where-Object DisplayName -like '*QEMU*'"
```

#### 13. Test Network Connectivity

```bash
python utils/winrm-tool.py --host 192.168.1.95 --user Administrator --password packer \
    --command "Test-NetConnection -ComputerName google.com -Port 443; Get-NetAdapter | Select-Object Name, Status, LinkSpeed"
```

#### 14. Check Windows Update Status

```bash
python utils/winrm-tool.py --host 192.168.1.95 --user Administrator --password packer \
    --command "Get-WindowsUpdateLog; Get-WUList"
```

#### 15. Review Security Settings

```bash
python utils/winrm-tool.py --host 192.168.1.95 --user Administrator --password packer \
    --command "Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' | Select-Object fDenyTSConnections; Get-NetFirewallProfile | Select-Object Name, Enabled"
```

#### 16. Multi-line PowerShell Script Execution

```bash
python utils/winrm-tool.py --host 192.168.1.95 --user Administrator --password packer \
    --command "\$logPath = 'C:\Windows\Temp\windows-init.log'; if (Test-Path \$logPath) { Get-Content \$logPath | Select-Object -Last 50 } else { Write-Output 'Log file not found' }"
```

#### 17. Check Packer Build Artifacts

```bash
python utils/winrm-tool.py --host 192.168.1.95 --user Administrator --password packer \
    --command "Get-ChildItem C:\Windows\Temp\*.log | Select-Object Name, Length, LastWriteTime; Get-ChildItem C:\Users\Administrator\AppData\Local\Temp\*.msi -ErrorAction SilentlyContinue"
```

#### 18. Validate AutoLogon Configuration

```bash
python utils/winrm-tool.py --host 192.168.1.95 --user Administrator --password packer \
    --command "Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' | Select-Object AutoAdminLogon, DefaultUserName, AutoLogonCount"
```

#### 19. Interactive Debugging Session

Start an interactive session and run multiple diagnostic commands:

```bash
python utils/winrm-tool.py --host 192.168.1.95 --user Administrator --password packer
```

Then in the interactive shell:

```powershell
PS 192.168.1.95> # Check WinRM service
PS 192.168.1.95> Get-Service WinRM | Format-List

PS 192.168.1.95> # View WinRM configuration
PS 192.168.1.95> winrm get winrm/config/service

PS 192.168.1.95> # Check network profile
PS 192.168.1.95> Get-NetConnectionProfile

PS 192.168.1.95> # Retrieve build logs
PS 192.168.1.95> get-logs

PS 192.168.1.95> # Check last 20 lines of init log
PS 192.168.1.95> Get-Content C:\Windows\Temp\windows-init.log | Select-Object -Last 20

PS 192.168.1.95> # Verify firewall status
PS 192.168.1.95> Get-NetFirewallProfile | Select-Object Name, Enabled

PS 192.168.1.95> # Exit when done
PS 192.168.1.95> exit
```

#### 20. Custom Port and CMD Shell

```bash
python utils/winrm-tool.py --host 192.168.1.95 --user Administrator --password packer \
    --port 5986 --shell cmd --command "ipconfig /all"
```

## Troubleshooting

### Connection Issues

**Problem:** Connection timeout or refused

```bash
# Verify VM is running and has network
python utils/winrm-tool.py --host 192.168.1.95 --user Administrator --password packer \
    --command "hostname"
```

**Solution:** Check that:
- VM has network connectivity
- WinRM service is running
- Firewall allows port 5985
- Network profile is Private (not Public)

### Authentication Issues

**Problem:** 401 Unauthorized errors

```bash
# Check WinRM authentication settings
python utils/winrm-tool.py --host 192.168.1.95 --user Administrator --password packer \
    --command "winrm get winrm/config/service/auth"
```

**Solution:** Verify:
- Username and password are correct
- Basic authentication is enabled
- AllowUnencrypted is true
- Administrator account is enabled

### Log Files Not Found

**Problem:** Cannot retrieve log files

```bash
# Check if log files exist
python utils/winrm-tool.py --host 192.168.1.95 --user Administrator --password packer \
    --command "Get-ChildItem C:\Windows\Temp\*.log | Select-Object Name, Length, LastWriteTime"
```

**Solution:** 
- Ensure FirstLogonCommands have executed
- Check script execution in Task Manager or Event Viewer
- Verify log file paths in scripts

## Use Cases

### During Packer Builds

1. **Real-time Log Monitoring**: Check build progress without waiting for timeout
2. **Debug Authentication Issues**: Verify WinRM configuration during 401 errors
3. **Validate Script Execution**: Confirm FirstLogonCommands ran successfully
4. **Check Service Status**: Verify QEMU Guest Agent, WinRM, and other services

### Post-Build Validation

1. **Verify Installed Software**: Confirm all packages were installed
2. **Check Configuration**: Validate registry settings, firewall rules, network config
3. **Security Audit**: Review security settings before template finalization
4. **Performance Testing**: Check running processes, memory usage, disk space

### Troubleshooting Failed Builds

1. **Retrieve Error Logs**: Get detailed error messages from log files
2. **Diagnose WinRM Issues**: Check service configuration and authentication
3. **Network Problems**: Test connectivity, verify network profile
4. **Script Failures**: Review script execution logs and error messages

## Interactive Shell Special Commands

When in interactive mode, the tool supports these special commands:

- `get-logs` - Retrieve both windows-init.log and windows-prepare.log
- `exit` or `quit` - End the interactive session
- `Ctrl+C` - Interrupt current command (without ending session)

All other input is executed as PowerShell commands on the remote host.

## Notes

- The tool defaults to HTTP (port 5985) for simplicity during builds
- For production use, consider HTTPS (port 5986) with proper certificates
- Build VMs typically use "Administrator" user with "packer" password
- The tool automatically tests the connection before entering interactive mode
- Exit codes from commands are preserved when using `--command` mode

## Examples Summary

| Example | Command | Use Case |
|---------|---------|----------|
| Interactive | `--host IP --user USER --password PASS` | General debugging |
| Get Logs | `--host IP --user USER --password PASS --get-logs` | Retrieve build logs |
| Single Command | `--command "Get-Service WinRM"` | Quick status check |
| WinRM Config | `--command "winrm get winrm/config"` | Verify WinRM settings |
| Network Profile | `--command "Get-NetConnectionProfile"` | Check network category |
| Services | `--command "Get-Service \| Where Status -eq Running"` | List running services |
| Firewall | `--command "Get-NetFirewallRule"` | Review firewall rules |
| Disk Space | `--command "Get-PSDrive C"` | Check available space |
| Event Logs | `--command "Get-EventLog -LogName System"` | Review system events |
| QEMU Agent | `--command "Get-Service QEMU-GA"` | Verify agent status |

## Related Documentation

- [WinRM Configuration Issues](../docs/troubleshooting/winrm-authentication-issues.md)
- [Packer Build Scripts](../builds/proxmox/windows/scripts/)
- [Windows Build Templates](../builds/proxmox/windows/)
