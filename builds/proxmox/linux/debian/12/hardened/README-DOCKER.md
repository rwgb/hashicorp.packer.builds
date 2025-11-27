# Hardened Docker Host Build

## Overview

This build creates a security-hardened Docker host VM based on Debian 12, configured with audit logging, AppArmor profiles, secure daemon settings, and user namespace remapping.

## VM Configuration

- **VM ID**: 9002
- **VM Name**: debian-12-hardened-docker
- **Base Template**: VM ID 9000 (Debian 12 base)
- **Tags**: linux;debian-12;hardened;docker

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

### Prerequisites
- `apt-transport-https` - HTTPS transport for APT
- `ca-certificates` - Common CA certificates
- `curl` - Command line tool for data transfer
- `gnupg` - GNU Privacy Guard
- `lsb-release` - Linux Standard Base version reporting

### Security Packages
- `auditd` - Linux Audit daemon for security monitoring
- `apparmor` - Mandatory Access Control framework
- `apparmor-utils` - AppArmor utilities

### Docker Packages
- `docker-ce` - Docker Community Edition
- `docker-ce-cli` - Docker CLI
- `containerd.io` - Container runtime
- `docker-compose-plugin` - Docker Compose V2 plugin

## Docker Security Configuration

### Daemon Security Settings

The Docker daemon is configured with the following security settings in `/etc/docker/daemon.json`:

```json
{
  "icc": false,                    // Disable inter-container communication
  "live-restore": true,            // Keep containers running during daemon downtime
  "userland-proxy": false,         // Use iptables directly (more secure)
  "no-new-privileges": true,       // Prevent privilege escalation
  "log-driver": "json-file",       // JSON file logging
  "log-opts": {
    "max-size": "10m",             // Maximum log file size
    "max-file": "3"                // Keep 3 log files
  },
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft": 64000
    }
  },
  "userns-remap": "default"        // Enable user namespace remapping
}
```

### Key Security Features

#### Inter-Container Communication (ICC)
- **Setting**: `"icc": false`
- **Purpose**: Containers cannot communicate with each other by default
- **Impact**: Explicit network connections required between containers

#### User Namespace Remapping
- **Setting**: `"userns-remap": "default"`
- **Purpose**: Maps container root user to unprivileged host user
- **Impact**: Provides container isolation from host

#### No New Privileges
- **Setting**: `"no-new-privileges": true`
- **Purpose**: Prevents privilege escalation in containers
- **Impact**: Containers cannot gain additional privileges

#### Userland Proxy
- **Setting**: `"userland-proxy": false`
- **Purpose**: Use iptables directly instead of Docker proxy
- **Impact**: Better performance and security

### Audit Configuration

Docker operations are monitored through auditd with rules in `/etc/audit/rules.d/docker.rules`:

**Monitored Paths**:
- `/usr/bin/docker` - Docker binary
- `/var/lib/docker` - Docker data directory
- `/etc/docker` - Docker configuration
- `/lib/systemd/system/docker.service` - Docker service unit
- `/lib/systemd/system/docker.socket` - Docker socket unit
- `/etc/default/docker` - Docker defaults
- `/etc/docker/daemon.json` - Docker daemon config
- `/usr/bin/containerd` - Containerd binary
- `/usr/bin/runc` - Runc binary

All changes to these paths are logged and tagged with `docker` for easy filtering.

### Docker Socket Permissions

The Docker socket (`/var/run/docker.sock`) is configured with mode `0660` to restrict access.

## AppArmor Integration

AppArmor is installed and enabled to provide mandatory access control for containers. Docker automatically applies AppArmor profiles to containers.

## Network Configuration

- **Default Ports**: 
  - Docker daemon socket: `/var/run/docker.sock` (Unix socket)
  - Exposed container ports: As configured per container

**Note**: The Docker daemon is not exposed over TCP by default for security reasons.

## File Locations

### Configuration Files
- Docker daemon config: `/etc/docker/daemon.json`
- Audit rules: `/etc/audit/rules.d/docker.rules`
- AppArmor profiles: `/etc/apparmor.d/`

### Log Files
- Docker logs: `/var/log/docker.log` (if configured)
- Container logs: `/var/lib/docker/containers/<container-id>/<container-id>-json.log`
- Audit logs: `/var/log/audit/audit.log`
- System journal: `journalctl -u docker`

### Data Directories
- Docker root: `/var/lib/docker`
- Container data: `/var/lib/docker/containers/`
- Images: `/var/lib/docker/image/`
- Volumes: `/var/lib/docker/volumes/`

## Services

The following services are enabled and started automatically:

- **docker** - Docker daemon
- **containerd** - Container runtime
- **auditd** - Audit daemon

## Building the Image

### Build Docker Host Only
```bash
cd /path/to/builds/proxmox/linux/debian/12/hardened
packer build -only='debian_12_hardened_docker_only.proxmox-clone.debian_12_hardened_docker' .
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

2. **Add users to docker group (if needed)**
   ```bash
   sudo usermod -aG docker yourusername
   ```
   **Note**: With user namespace remapping, consider security implications.

3. **Verify Docker is working**
   ```bash
   sudo docker run hello-world
   ```

4. **Review audit logs**
   ```bash
   sudo ausearch -k docker
   ```

5. **Configure Docker networks**
   ```bash
   docker network create --driver bridge isolated-network
   ```

6. **Set up container monitoring**
   ```bash
   docker stats
   ```

7. **Update the system**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

## Using Docker with Security Features

### Running Containers Securely

```bash
# Run with read-only root filesystem
docker run --read-only -v /tmp --tmpfs /run alpine

# Run with no new privileges
docker run --security-opt=no-new-privileges alpine

# Run with AppArmor profile
docker run --security-opt apparmor=docker-default alpine

# Limit resources
docker run --memory="256m" --cpus="1.0" alpine
```

### Custom Networks

Since ICC is disabled, create explicit networks:

```bash
# Create isolated network
docker network create --driver bridge my-app-network

# Run containers on same network
docker run --network my-app-network --name web nginx
docker run --network my-app-network --name db postgres
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
The Ansible playbook that configures Docker is located at:
```
builds/proxmox/ansible/hardened-docker.yml
```

Modify this file to customize the Docker security configuration.

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

### Docker Won't Start
Check logs:
```bash
sudo journalctl -xeu docker
sudo systemctl status docker
```

### User Namespace Remapping Issues
If containers fail due to user namespace remapping:
```bash
# Check subordinate UID/GID mappings
cat /etc/subuid
cat /etc/subgid

# Verify dockremap user was created
id dockremap
```

### Permission Denied on Docker Socket
```bash
# Check socket permissions
ls -la /var/run/docker.sock

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

## Security Considerations

- User namespace remapping may affect volume mounts and file permissions
- ICC disabled means containers need explicit network configuration
- Audit logs can grow large - configure log rotation
- AppArmor profiles may need customization for specific workloads
- Regular security updates are essential
- Consider additional hardening:
  - Enable Docker Content Trust
  - Use image scanning tools
  - Implement secrets management
  - Configure TLS for Docker daemon if remote access needed

## Best Practices

1. **Run containers as non-root**
   ```dockerfile
   USER nobody
   ```

2. **Use specific image tags, not `latest`**
   ```bash
   docker run nginx:1.21-alpine
   ```

3. **Scan images for vulnerabilities**
   ```bash
   docker scan myimage:latest
   ```

4. **Limit container capabilities**
   ```bash
   docker run --cap-drop=ALL --cap-add=NET_BIND_SERVICE nginx
   ```

5. **Use secrets for sensitive data**
   ```bash
   docker secret create my_secret my_secret.txt
   ```

## Compliance

This configuration implements several CIS Docker Benchmark recommendations:
- User namespace remapping enabled
- Inter-container communication restricted
- Audit logging configured
- AppArmor enabled
- Daemon socket permissions restricted

For full CIS compliance, additional manual steps may be required.

## Support

For issues specific to this build configuration, please refer to:
- Main repository README
- Packer documentation: https://www.packer.io/docs
- Proxmox documentation: https://pve.proxmox.com/pve-docs/
- Docker security: https://docs.docker.com/engine/security/
