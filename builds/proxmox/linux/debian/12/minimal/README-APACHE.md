# Minimal Apache Web Server Build

## Overview

This build creates a lightweight, minimal Apache web server VM based on Debian 12, optimized for resource efficiency with only essential packages and modules.

## VM Configuration

- **VM ID**: 9005
- **VM Name**: debian-12-minimal-apache
- **Base Template**: VM ID 9000 (Debian 12 base)
- **Tags**: linux;debian-12;minimal;apache

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

### Core Package
- `apache2` - Apache HTTP Server (installed with `--no-install-recommends` for minimal footprint)

**Note**: No recommended packages are installed to minimize disk space and memory usage.

## Apache Configuration

### Disabled Modules
The following unnecessary modules are disabled to reduce resource usage:
- `autoindex` - Directory listing
- `status` - Server status page
- `negotiation` - Content negotiation

### Enabled Modules (Essential Only)
- `mpm_event` - Event-driven MPM for better performance
- `authz_core` - Core authorization
- `dir` - Directory index handling

### Performance Configuration

The following settings optimize Apache for minimal resource usage:

```apache
ServerTokens Prod
ServerSignature Off
TraceEnable Off
Timeout 30
KeepAlive On
MaxKeepAliveRequests 50
KeepAliveTimeout 3
```

**Key Settings**:
- **Timeout**: Reduced to 30 seconds
- **KeepAlive**: Enabled with short timeout (3 seconds)
- **MaxKeepAliveRequests**: Limited to 50 per connection

### Default Site
The default site configuration (`000-default.conf`) is removed to force explicit virtual host configuration.

## Network Configuration

- **Default Ports**: 
  - HTTP: 80

**Note**: SSL/TLS is not included in the minimal build. Add `apache2-ssl` package if HTTPS is needed.

## File Locations

### Configuration Files
- Apache main config: `/etc/apache2/apache2.conf`
- Minimal config: `/etc/apache2/conf-available/minimal.conf` (enabled)
- Available sites: `/etc/apache2/sites-available/`
- Enabled sites: `/etc/apache2/sites-enabled/`

### Log Files
- Access log: `/var/log/apache2/access.log`
- Error log: `/var/log/apache2/error.log`

### Web Root
- Default: `/var/www/html`

## Services

The following service is enabled and started automatically:

- **apache2** - Apache HTTP Server

## Resource Usage

This minimal configuration is optimized for:
- **Low Memory**: Suitable for VMs with 512MB-1GB RAM
- **Low Disk Space**: Minimal package installation
- **Fast Startup**: Fewer modules and dependencies

## Building the Image

### Build Apache Only
```bash
cd /path/to/builds/proxmox/linux/debian/12/minimal
packer build -only='debian_12_minimal_apache_only.proxmox-clone.debian_12_minimal_apache' .
```

### Build All Minimal Variants
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

2. **Create a virtual host configuration**
   ```bash
   sudo vim /etc/apache2/sites-available/mysite.conf
   sudo a2ensite mysite
   sudo systemctl reload apache2
   ```

3. **Deploy your web application**
   - Place files in `/var/www/html/` or custom document root
   - Ensure proper file permissions

4. **Enable additional modules if needed**
   ```bash
   sudo a2enmod rewrite  # For URL rewriting
   sudo a2enmod ssl      # For HTTPS (requires additional packages)
   sudo systemctl reload apache2
   ```

5. **Update the system**
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
builds/proxmox/ansible/minimal-apache.yml
```

Modify this file to customize the Apache configuration.

## Adding Security Features

This minimal build focuses on resource efficiency. To add security features:

1. **Install mod_security**
   ```bash
   sudo apt install libapache2-mod-security2
   sudo a2enmod security2
   ```

2. **Install fail2ban**
   ```bash
   sudo apt install fail2ban
   ```

3. **Configure SSL/TLS**
   ```bash
   sudo apt install apache2-ssl
   sudo a2enmod ssl
   ```

Or consider using the **hardened-apache** build instead, which includes these features pre-configured.

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

### Apache Won't Start
Check logs for errors:
```bash
sudo journalctl -xeu apache2
sudo tail -f /var/log/apache2/error.log
```

## Use Cases

This minimal Apache build is ideal for:
- Development and testing environments
- Lightweight web hosting
- Static content serving
- Microservices with low resource requirements
- Learning and experimentation

For production environments requiring security hardening, use the **hardened-apache** build instead.

## Performance Tuning

If you need to adjust resource usage further:

1. **Edit MPM configuration** (`/etc/apache2/mods-available/mpm_event.conf`)
2. **Adjust KeepAlive settings** in minimal.conf
3. **Limit maximum clients** to prevent memory exhaustion

## Support

For issues specific to this build configuration, please refer to:
- Main repository README
- Packer documentation: https://www.packer.io/docs
- Proxmox documentation: https://pve.proxmox.com/pve-docs/
