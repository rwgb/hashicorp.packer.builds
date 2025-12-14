#!/usr/bin/env python3
"""
WinRM Client Tool for Packer Build VMs

A Python-based WinRM client for connecting to Windows VMs during Packer builds.
Supports interactive shell, command execution, and log file retrieval.

Usage:
    python winrm-tool.py --host <IP> --user <username> --password <password>
    python winrm-tool.py --host <IP> --user <username> --password <password> --command "Get-Process"
    python winrm-tool.py --host <IP> --user <username> --password <password> --get-logs
"""

import argparse
import sys
import os
from typing import Optional

try:
    import winrm
    from winrm.protocol import Protocol
except ImportError:
    print("Error: pywinrm package not found.")
    print("Install it with: pip install pywinrm")
    sys.exit(1)


class WinRMClient:
    """WinRM client for connecting to Windows hosts."""
    
    def __init__(self, host: str, username: str, password: str, port: int = 5985):
        """
        Initialize WinRM client.
        
        Args:
            host: IP address or hostname of Windows machine
            username: Windows username
            password: Windows password
            port: WinRM port (default: 5985 for HTTP)
        """
        self.host = host
        self.username = username
        self.password = password
        self.port = port
        self.endpoint = f"http://{host}:{port}/wsman"
        
        # Create session
        self.session = winrm.Session(
            self.endpoint,
            auth=(username, password),
            transport='basic',
            server_cert_validation='ignore'
        )
    
    def execute_command(self, command: str, shell: str = 'powershell') -> tuple:
        """
        Execute a command on the remote Windows host.
        
        Args:
            command: Command to execute
            shell: Shell to use ('powershell' or 'cmd')
        
        Returns:
            Tuple of (stdout, stderr, exit_code)
        """
        try:
            if shell.lower() == 'powershell':
                result = self.session.run_ps(command)
            else:
                result = self.session.run_cmd(command)
            
            return (
                result.std_out.decode('utf-8') if result.std_out else '',
                result.std_err.decode('utf-8') if result.std_err else '',
                result.status_code
            )
        except Exception as e:
            return ('', f'Error executing command: {str(e)}', 1)
    
    def get_file_content(self, remote_path: str) -> Optional[str]:
        """
        Retrieve content of a file from the remote host.
        
        Args:
            remote_path: Path to file on remote host
        
        Returns:
            File content as string, or None if error
        """
        command = f"Get-Content -Path '{remote_path}' -ErrorAction Stop"
        stdout, stderr, exit_code = self.execute_command(command)
        
        if exit_code == 0:
            return stdout
        else:
            print(f"Error reading file: {stderr}")
            return None
    
    def get_build_logs(self) -> dict:
        """
        Retrieve Packer build log files from standard locations.
        
        Returns:
            Dictionary with log file names as keys and content as values
        """
        log_files = {
            'windows-init.log': r'C:\Windows\Temp\windows-init.log',
            'windows-prepare.log': r'C:\Windows\Temp\windows-prepare.log'
        }
        
        logs = {}
        for name, path in log_files.items():
            print(f"\n{'='*60}")
            print(f"Retrieving: {name}")
            print('='*60)
            
            content = self.get_file_content(path)
            if content:
                logs[name] = content
                print(content)
            else:
                print(f"Could not retrieve {name}")
        
        return logs
    
    def interactive_shell(self):
        """
        Start an interactive PowerShell session.
        """
        print(f"\nConnected to {self.host}")
        print("Interactive PowerShell Session")
        print("Type 'exit' or 'quit' to end session")
        print("Type 'get-logs' to retrieve build log files")
        print("-" * 60)
        
        while True:
            try:
                command = input(f"PS {self.host}> ").strip()
                
                if not command:
                    continue
                
                if command.lower() in ['exit', 'quit']:
                    print("Ending session...")
                    break
                
                if command.lower() == 'get-logs':
                    self.get_build_logs()
                    continue
                
                stdout, stderr, exit_code = self.execute_command(command)
                
                if stdout:
                    print(stdout, end='')
                if stderr:
                    print(f"ERROR: {stderr}", file=sys.stderr, end='')
                
                if exit_code != 0:
                    print(f"[Exit Code: {exit_code}]")
                    
            except KeyboardInterrupt:
                print("\n\nInterrupted. Type 'exit' to quit.")
            except EOFError:
                print("\nEnding session...")
                break
            except Exception as e:
                print(f"Error: {str(e)}", file=sys.stderr)
    
    def test_connection(self) -> bool:
        """
        Test the WinRM connection.
        
        Returns:
            True if connection successful, False otherwise
        """
        print(f"Testing connection to {self.host}:{self.port}...")
        stdout, stderr, exit_code = self.execute_command("hostname")
        
        if exit_code == 0:
            print(f"✓ Connection successful! Remote host: {stdout.strip()}")
            return True
        else:
            print(f"✗ Connection failed: {stderr}")
            return False


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='WinRM Client for Packer Build VMs',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Interactive shell
  python winrm-tool.py --host 192.168.1.95 --user Administrator --password packer
  
  # Execute single command
  python winrm-tool.py --host 192.168.1.95 --user Administrator --password packer \\
      --command "Get-Service WinRM"
  
  # Retrieve build logs
  python winrm-tool.py --host 192.168.1.95 --user Administrator --password packer --get-logs
        """
    )
    
    parser.add_argument('--host', required=True, help='IP address or hostname of Windows VM')
    parser.add_argument('--user', default='Administrator', help='Windows username (default: Administrator)')
    parser.add_argument('--password', default='packer', help='Windows password (default: packer)')
    parser.add_argument('--port', type=int, default=5985, help='WinRM port (default: 5985)')
    parser.add_argument('--command', help='Execute a single PowerShell command and exit')
    parser.add_argument('--get-logs', action='store_true', help='Retrieve build log files and exit')
    parser.add_argument('--shell', choices=['powershell', 'cmd'], default='powershell', 
                       help='Shell to use (default: powershell)')
    
    args = parser.parse_args()
    
    # Create client
    client = WinRMClient(args.host, args.user, args.password, args.port)
    
    # Test connection
    if not client.test_connection():
        sys.exit(1)
    
    print()
    
    # Execute based on mode
    if args.get_logs:
        client.get_build_logs()
    elif args.command:
        stdout, stderr, exit_code = client.execute_command(args.command, args.shell)
        if stdout:
            print(stdout, end='')
        if stderr:
            print(stderr, file=sys.stderr, end='')
        sys.exit(exit_code)
    else:
        # Interactive shell
        client.interactive_shell()


if __name__ == '__main__':
    main()
