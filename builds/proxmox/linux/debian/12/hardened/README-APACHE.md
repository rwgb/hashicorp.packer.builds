# Hardened Apache Web Server Build

## Overview

This build creates a security-hardened Apache web server VM based on Debian 12, configured with multiple security layers including ModSecurity, fail2ban, and security headers.

## VM Configuration

- **VM ID**: 9001
- **VM Name**: debian-12-hardened-apache
- **Base Template**: VM ID 9000 (Debian 12 base)
- **Tags**: linux;debian-12;hardened;apache

## Access Information

### During Build Process

When Packer clones the template (VM ID 9000), it uses SSH to connect and provision the VM:

- **SSH Username**: `packer` (configurable via `username` variable)
- **SSH Password**: `packer` (configurable via `password` variable)
- **SSH Timeout**: 15 minutes

These credentials are defined in `variables.auto.pkrvars.hcl` and must match the credentials configured in your base template (VM ID 9000).

### After Build Completion

The build process does not modify user accounts, so the same credentials will work:

- **Username**: `packer`
- **Password**: `packer`

**Security Note**: Change these default credentials immediately after deployment in production environments.

## Software Packages Installed

### Core Packages
- `apache2` - Apache HTTP Server
- `apache2-utils` - Apache utility programs

### Security Packages
- `libapache2-mod-security2` - ModSecurity Web Application Firewall
- `libapache2-mod-evasive` - Evasive module for Apache
- `fail2ban` - Intrusion prevention framework

## Apache Security Configuration

### Enabled Apache Modules
- `ssl` - SSL/TLS support
- `headers` - HTTP header control
- `security2` - ModSecurity WAF
- `evasive` - DDoS mitigation

### Security Headers
The following HTTP security headers are automatically configured:

```apache
ServerTokens Prod
ServerSignature Off
TraceEnable Off
Header always set X-Content-Type-Options "nosniff"
Header always set X-Frame-Options "SAMEORIGIN"
Header always set X-XSS-Protection "1; mode=block"
Header always set Referrer-Policy "strict-origin-when-cross-origin"
```

### ModSecurity Configuration
- **Mode**: Active (blocks malicious requests)
- **Config File**: `/etc/modsecurity/modsecurity.conf`
- **Rule Engine**: Enabled

ModSecurity provides real-time web application monitoring and access control.

### Fail2ban Configuration
Fail2ban monitors Apache logs and automatically bans IPs showing malicious behavior:

**Protected Scenarios**:
- `apache-auth` - Failed authentication attempts
- `apache-badbots` - Known bad bots and scanners
- `apache-noscript` - Script injection attempts

**Configuration File**: `/etc/fail2ban/jail.d/apache.conf`

### Additional Security Settings
- **Directory Listing**: Disabled (`Options -Indexes`)
- **Server Tokens**: Production mode (minimal information disclosure)
- **TRACE Method**: Disabled (prevents XST attacks)

## Network Configuration

- **Default Ports**: 
  - HTTP: 80
  - HTTPS: 443 (SSL module enabled but certificate required)

## File Locations

### Configuration Files
- Apache main config: `/etc/apache2/apache2.conf`
- Security config: `/etc/apache2/conf-available/security.conf`
- ModSecurity config: `/etc/modsecurity/modsecurity.conf`
- Fail2ban config: `/etc/fail2ban/jail.d/apache.conf`

### Log Files
- Access log: `/var/log/apache2/access.log`
- Error log: `/var/log/apache2/error.log`
- Fail2ban log: `/var/log/fail2ban.log`

### Web Root
- Default: `/var/www/html`

## Services

The following services are enabled and started automatically:

- **apache2** - Apache HTTP Server
- **fail2ban** - Intrusion prevention

## Building the Image

### Build Apache Only
```bash
cd /path/to/builds/proxmox/linux/debian/12/hardened
packer build -only='debian_12_hardened_apache_only.proxmox-clone.debian_12_hardened_apache' .
```

### Build All Hardened Variants
```bash
packer build .
```

## Post-Deployment Steps

After deploying a VM from this template, you should:

1. **Change default credentials**
   ```bash
   sudo passwd packer
   # Or create new user and remove packer user
   ```

2. **Configure SSL/TLS certificates**
   ```bash
   sudo a2enmod ssl
   sudo a2ensite default-ssl
   # Add your certificates to /etc/apache2/ssl/
   ```

3. **Review and customize ModSecurity rules**
   ```bash
   sudo vim /etc/modsecurity/modsecurity.conf
   ```

4. **Configure your web application**
   - Place files in `/var/www/html/`
   - Create virtual host configurations in `/etc/apache2/sites-available/`

5. **Verify fail2ban is working**
   ```bash
   sudo fail2ban-client status apache-auth
   ```

6. **Update the system**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

## Customization

### Variables
You can customize the build by modifying `variables.auto.pkrvars.hcl`:

```hcl
proxmox_host = "your-proxmox-host"
token_id     = "your-token-id"
token_secret = "your-token-secret"
node         = "your-node-name"
clone_vm_id  = 9000  # Base template VM ID
username     = "packer"
password     = "packer"
```

### Ansible Playbook
The Ansible playbook that configures Apache is located at:
```
builds/proxmox/ansible/hardened-apache.yml
```

Modify this file to customize the Apache security configuration.

## Troubleshooting

### Build Fails with Permission Error
Ensure your Proxmox API token has the following permissions:
- VM.Clone
- VM.Allocate
- VM.Config.*
- VM.PowerMgmt
- Datastore.AllocateSpace

### SSH Connection Timeout
- Verify the base template (VM ID 9000) has cloud-init configured
- Ensure the username/password in variables match the base template
- Check network connectivity between Packer host and Proxmox VMs

### ModSecurity Blocking Legitimate Traffic
Review and adjust ModSecurity rules in `/etc/modsecurity/modsecurity.conf` or temporarily set to DetectionOnly mode:
```apache
SecRuleEngine DetectionOnly
```

## Security Considerations

- This is a hardened configuration but should not be considered production-ready without additional customization
- Regular security updates are essential
- Configure SSL/TLS certificates before exposing to the internet
- Review and customize fail2ban rules for your specific use case
- Consider additional hardening steps from CIS Benchmarks or STIG guidelines

## Support

For issues specific to this build configuration, please refer to:
- Main repository README
- Packer documentation: https://www.packer.io/docs
- Proxmox documentation: https://pve.proxmox.com/pve-docs/
