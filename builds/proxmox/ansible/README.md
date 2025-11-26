# Ansible Playbooks for Debian 12 Role-Specific Builds

This directory contains Ansible playbooks for configuring role-specific Debian 12 templates with both hardened and minimal variants.

## Directory Structure

```
builds/proxmox/ansible/
├── hardened-apache.yml    # Hardened Apache web server
├── hardened-docker.yml    # Hardened Docker host
├── hardened-mysql.yml     # Hardened MySQL database server
├── hardened-tomcat.yml    # Hardened Tomcat application server
├── minimal-apache.yml     # Minimal Apache web server
├── minimal-docker.yml     # Minimal Docker host
├── minimal-mysql.yml      # Minimal MySQL database server
└── minimal-tomcat.yml     # Minimal Tomcat application server
```

## Hardened Variant Features

The hardened playbooks implement security best practices:

### Apache (hardened-apache.yml)
- ModSecurity web application firewall
- mod_evasive for DoS protection
- fail2ban integration
- Security headers (X-Frame-Options, XSS Protection, etc.)
- Disabled directory listing
- Server signature hiding

### Docker (hardened-docker.yml)
- User namespace remapping
- Audit logging for Docker operations
- AppArmor/SELinux integration
- Disabled inter-container communication by default
- No new privileges flag
- Proper socket permissions

### MySQL (hardened-mysql.yml)
- Disabled local infile
- Strict SQL modes
- Connection limits
- fail2ban integration
- Secure default configuration
- Network binding restrictions

### Tomcat (hardened-tomcat.yml)
- Removed default applications
- Restricted HTTP methods
- Secure session configuration
- fail2ban integration
- Security valves
- Error page customization

## Minimal Variant Features

The minimal playbooks focus on resource efficiency:

### Apache (minimal-apache.yml)
- Minimal module installation
- No recommended packages
- Only essential modules enabled
- Optimized for low resource usage

### Docker (minimal-docker.yml)
- Minimal package installation
- Reduced logging
- Overlay2 storage driver
- No additional security tooling

### MySQL (minimal-mysql.yml)
- Reduced buffer pool sizes
- Performance schema disabled
- Limited connections
- Minimal logging

### Tomcat (minimal-tomcat.yml)
- JRE headless only
- Minimal JVM settings
- Reduced thread counts
- No admin applications

## Usage

These playbooks are automatically invoked by Packer during the build process. They can also be run manually:

```bash
# Hardened Apache
ansible-playbook -i inventory hardened-apache.yml

# Minimal Docker
ansible-playbook -i inventory minimal-docker.yml
```

## VM ID Assignments

- **9000**: Debian 12 Base (source template)
- **9001**: Hardened Apache
- **9002**: Hardened Docker
- **9003**: Hardened MySQL
- **9004**: Hardened Tomcat
- **9005**: Minimal Apache
- **9006**: Minimal Docker
- **9007**: Minimal MySQL
- **9008**: Minimal Tomcat

## Build Process

1. **Base Build**: Create Debian 12 base template (VM ID 9000)
2. **Clone**: Use proxmox-clone builder to clone base template
3. **Provision**: Run Ansible playbook to configure role-specific settings
4. **Finalize**: Clean up and create new template

## Requirements

- Ansible 2.9 or higher
- Python 3.7 or higher
- Debian 12 base template (VM ID 9000)
- Proxmox VE 7.x or higher

## Notes

- All playbooks assume `become: true` for privilege escalation
- SSH access must be configured on the base template
- Playbooks are idempotent and can be run multiple times
- Individual role files allow building specific variants independently
