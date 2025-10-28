# Ansible Provisioning for Proxmox Linux Builds

## Overview

All Proxmox Linux builds now include Ansible provisioning to automatically configure VMs as Docker hosts with security hardening and monitoring.

## Changes Applied

### Updated Builds
- ✅ Debian 12 (`builds/proxmox/linux/debian/12/build.pkr.hcl`)
- ✅ Debian 13 (`builds/proxmox/linux/debian/13/build.pkr.hcl`)

### What Gets Installed

All builds now automatically configure the following:

#### 1. Docker Environment
- **Docker CE** - Latest stable version
- **Docker Compose** - Both plugin and standalone versions
- **User Configuration** - Build user added to docker group
- **Pre-configuration** - Daemon optimized for production use

#### 2. Security Hardening
- **UFW Firewall** - Configured with Docker-compatible rules
- **Fail2ban** - SSH brute-force protection
- **SSH Hardening** - Disabled root login and password auth
- **Automatic Updates** - Unattended security updates enabled

#### 3. System Configuration
- **Base Packages** - Essential tools (curl, wget, git, vim, htop, etc.)
- **Time Sync** - Chrony for accurate timekeeping
- **System Optimization** - Sysctl and ulimit tuning

#### 4. Monitoring
- **Prometheus Node Exporter** - System metrics on port 9100
- **Docker Metrics** - Container and runtime statistics

## Build Process

### 1. System Preparation
```bash
# Updates package cache
# Installs Python3, pip, and apt prerequisites
```

### 2. Ansible Provisioning
```bash
# Applies roles in order:
#   1. common - Base system configuration
#   2. security - Firewall and SSH hardening
#   3. docker - Docker Engine installation
#   4. monitoring - Prometheus Node Exporter
```

### 3. Verification
```bash
# Tests Docker installation
# Runs hello-world container
# Verifies systemd services
```

### 4. Template Cleanup
```bash
# Removes temporary files
# Clears machine-id for cloning
# Cleans cloud-init state
```

## Configuration Variables

The Ansible provisioning is configured via extra variables:

| Variable | Value | Purpose |
|----------|-------|---------|
| `host_type` | `docker` | Triggers docker role |
| `ansible_python_interpreter` | `/usr/bin/python3` | Python path |
| `docker_users` | `[username]` | Users in docker group |
| `docker_install_compose` | `true` | Install Docker Compose |
| `common_timezone` | From var | System timezone |
| `security_enable_ufw` | `true` | Enable firewall |
| `security_enable_fail2ban` | `true` | Enable fail2ban |
| `monitoring_enable` | `true` | Install Node Exporter |

## Ansible Playbook Location

The playbook is located at: `builds/proxmox/ansible/playbook.yml`

All builds reference this shared playbook using:
```hcl
locals {
  ansible_root = "${path.root}/../../../ansible"
}
```

## Build Example

### Using buildManager.py
```bash
cd /path/to/hashicorp.packer

# Build Debian 12 Docker host
python3 scripts/buildManager.py --os debian_12_proxmox

# Build Debian 13 Docker host
python3 scripts/buildManager.py --os debian_13_proxmox
```

### Direct Packer Build
```bash
cd builds/proxmox/linux/debian/12

# Initialize plugins
packer init .

# Build
packer build .
```

## Template Usage

After the build completes, the resulting template includes:

### Pre-installed Software
- ✅ Docker Engine (latest stable)
- ✅ Docker Compose v2.x
- ✅ Python3 with Docker SDK
- ✅ Prometheus Node Exporter
- ✅ Fail2ban for SSH protection
- ✅ UFW firewall configured

### Pre-configured Services
- ✅ Docker service enabled and running
- ✅ UFW firewall active (ports 22, 80, 443, 9100)
- ✅ Fail2ban monitoring SSH
- ✅ Node Exporter on port 9100
- ✅ Chrony for time synchronization

### Security Hardening
- ✅ SSH root login disabled
- ✅ SSH password authentication disabled
- ✅ Automatic security updates enabled
- ✅ Minimal open ports
- ✅ System optimization applied

## First Boot Verification

After cloning a VM from the template:

```bash
# SSH into the VM
ssh user@vm-ip

# Check Docker
docker --version
docker compose version
sudo systemctl status docker

# Verify Docker works
docker run --rm hello-world

# Check firewall
sudo ufw status

# Check monitoring
curl http://localhost:9100/metrics

# View installed packages
docker images
docker ps
```

## Customization

To customize the Ansible provisioning, you can:

### 1. Modify Variables in build.pkr.hcl
```hcl
provisioner "ansible" {
  playbook_file = "${local.ansible_root}/playbook.yml"
  
  extra_arguments = [
    "--extra-vars", "host_type=docker",
    "--extra-vars", "docker_users=['user1','user2']",  # Add multiple users
    "--extra-vars", "monitoring_enable=false",          # Disable monitoring
    # Add your customizations here
  ]
}
```

### 2. Modify Ansible Roles
Edit the roles in `builds/proxmox/ansible/roles/`:
- `common/defaults/main.yml` - Base system packages
- `security/defaults/main.yml` - Firewall rules, fail2ban settings
- `docker/defaults/main.yml` - Docker configuration
- `monitoring/defaults/main.yml` - Node Exporter settings

### 3. Add Additional Roles
Create new roles in `builds/proxmox/ansible/roles/` and reference them in the playbook.

## Troubleshooting

### Ansible Connection Issues

If Ansible fails to connect during the build:

1. **Check SSH Key**: Ensure the SSH key is generated properly
   ```bash
   ls -la ~/.ssh/
   ```

2. **Check Variables**: Verify `var.username` is set correctly

3. **Enable Debug Mode**:
   ```hcl
   extra_arguments = [
     # ... other args ...
     "-vvv"  # Very verbose
   ]
   ```

### Docker Installation Fails

Check the build output for:
- Package installation errors
- Repository access issues
- Systemd service failures

View detailed logs during build:
```bash
PACKER_LOG=1 packer build .
```

### Template Clone Issues

If cloned VMs have issues:

1. **Machine ID**: Ensure machine-id was cleaned
   ```bash
   cat /etc/machine-id  # Should be empty or regenerated
   ```

2. **Cloud-init**: Check cloud-init status
   ```bash
   cloud-init status
   ```

3. **Network**: Verify network configuration
   ```bash
   ip addr show
   ```

## Build Times

Typical build times with Ansible provisioning:

| Build | Time | Notes |
|-------|------|-------|
| Debian 12 Base | ~10 min | Without Ansible |
| Debian 12 Docker | ~18 min | With Ansible + Docker |
| Debian 13 Base | ~10 min | Without Ansible |
| Debian 13 Docker | ~18 min | With Ansible + Docker |

The additional time is spent:
- Installing packages (~5 min)
- Configuring Docker (~2 min)
- Applying security hardening (~1 min)
- Verification and cleanup (~2 min)

## Manifest Output

Each build generates a manifest with metadata:

```json
{
  "builds": [{
    "custom_data": {
      "template_type": "docker-host",
      "ansible_roles": "common,security,docker,monitoring",
      "docker_compose": "true",
      "security_hardened": "true",
      "build_username": "deployer",
      "build_date": "2025-10-28 14:30 UTC",
      "build_version": "abc123def456"
    }
  }]
}
```

## Related Documentation

- [Ansible Playbook](../ansible/README.md) - Main playbook documentation
- [Docker Role](../ansible/roles/docker/README.md) - Docker configuration details
- [Security Role](../ansible/roles/security/README.md) - Security hardening details
- [Monitoring Role](../ansible/roles/monitoring/README.md) - Monitoring setup
- [Build Manager](../../scripts/README.md) - buildManager.py documentation

## Future Enhancements

Planned improvements:

- [ ] Add option to skip Ansible provisioning (minimal build)
- [ ] Support for database-only hosts (PostgreSQL/MySQL)
- [ ] Support for web server-only hosts (Nginx/Apache)
- [ ] Pre-load common Docker images (nginx, postgres, redis)
- [ ] Add Kubernetes node configuration
- [ ] Add monitoring dashboards (Grafana)
- [ ] Add log aggregation (Promtail/Loki)

## Support

For issues or questions:

1. Check build logs with `PACKER_LOG=1`
2. Review Ansible output in the build logs
3. Verify Ansible playbook syntax: `cd builds/proxmox/ansible && ansible-playbook playbook.yml --syntax-check`
4. Test roles individually: `ansible-playbook playbook.yml --tags docker -vvv`

## Contributing

To contribute improvements:

1. Test changes on a single build first
2. Update this documentation
3. Apply changes to all builds consistently
4. Update buildManager.py if needed
5. Commit with descriptive message

## Version History

- **2025-10-28**: Initial Ansible provisioning added to all Debian builds
  - Added ansible plugin requirement
  - Added docker, security, monitoring roles
  - Added verification and cleanup steps
  - Updated manifest metadata
