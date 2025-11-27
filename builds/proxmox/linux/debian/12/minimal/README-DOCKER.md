# Minimal Docker Host Build

## Overview

This build creates a lightweight, minimal Docker host VM based on Debian 12, optimized for resource efficiency with only essential packages and basic configuration.

## VM Configuration

- **VM ID**: 9006
- **VM Name**: debian-12-minimal-docker
- **Base Template**: VM ID 9000 (Debian 12 base)
- **Tags**: linux;debian-12;minimal;docker

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

### Prerequisites (Minimal)
- `apt-transport-https` - HTTPS transport for APT
- `ca-certificates` - Common CA certificates
- `curl` - Command line tool for data transfer
- `gnupg` - GNU Privacy Guard

**Note**: Packages installed with `--no-install-recommends` flag for minimal footprint.

### Docker Packages
- `docker-ce` - Docker Community Edition
- `docker-ce-cli` - Docker CLI
- `containerd.io` - Container runtime

**Note**: Docker Compose plugin is NOT included in minimal build. Install separately if needed.

## Docker Configuration

### Daemon Settings

The Docker daemon is configured for minimal resource usage in `/etc/docker/daemon.json`:

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "5m",      // Smaller log files than hardened build
    "max-file": "1"        // Keep only 1 log file
  },
  "storage-driver": "overlay2"
}
```

### Key Features

#### Logging
- **Driver**: JSON file logging
- **Max Size**: 5MB per file (reduced from 10MB in hardened build)
- **Max Files**: 1 (reduced from 3 in hardened build)
- **Purpose**: Minimize disk space usage

#### Storage Driver
- **Driver**: overlay2
- **Purpose**: Efficient storage with good performance
- **Benefits**: Lower overhead than aufs or devicemapper

## Resource Usage

This minimal configuration is optimized for:
- **Low Memory**: Suitable for VMs with 1-2GB RAM
- **Low Disk Space**: Minimal package installation
- **Fast Startup**: No additional security tools or auditing

**Comparison to Hardened Build**:
- No auditd (saves ~50MB RAM)
- No AppArmor utilities
- No user namespace remapping overhead
- Smaller log files
- Docker Compose not pre-installed

## Network Configuration

- **Default Ports**: 
  - Docker daemon socket: `/var/run/docker.sock` (Unix socket)
  - Exposed container ports: As configured per container

**Note**: Inter-container communication is ENABLED by default (unlike hardened build).

## File Locations

### Configuration Files
- Docker daemon config: `/etc/docker/daemon.json`

### Log Files
- Container logs: `/var/lib/docker/containers/<container-id>/<container-id>-json.log`
- System journal: `journalctl -u docker`

### Data Directories
- Docker root: `/var/lib/docker`
- Container data: `/var/lib/docker/containers/`
- Images: `/var/lib/docker/image/overlay2/`
- Volumes: `/var/lib/docker/volumes/`

## Services

The following services are enabled and started automatically:

- **docker** - Docker daemon
- **containerd** - Container runtime

## Building the Image

### Build Docker Host Only
```bash
cd /path/to/builds/proxmox/linux/debian/12/minimal
packer build -only='debian_12_minimal_docker_only.proxmox-clone.debian_12_minimal_docker' .
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

2. **Add user to docker group**
   ```bash
   sudo usermod -aG docker yourusername
   newgrp docker
   ```

3. **Verify Docker is working**
   ```bash
   docker run hello-world
   ```

4. **Install Docker Compose if needed**
   ```bash
   sudo apt update
   sudo apt install docker-compose-plugin
   ```

5. **Configure resource limits if needed**
   ```bash
   # Edit /etc/default/docker
   sudo vim /etc/default/docker
   ```

6. **Update the system**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

## Basic Usage

### Running Containers

```bash
# Run a simple container
docker run -d nginx

# Run with port mapping
docker run -d -p 8080:80 nginx

# Run with volume mount
docker run -d -v /host/path:/container/path nginx

# Run with environment variables
docker run -d -e MYSQL_ROOT_PASSWORD=secret mysql

# Run with resource limits
docker run -d --memory="512m" --cpus="1.0" nginx
```

### Managing Containers

```bash
# List running containers
docker ps

# List all containers
docker ps -a

# View container logs
docker logs container_name

# Stop container
docker stop container_name

# Remove container
docker rm container_name

# Remove all stopped containers
docker container prune
```

### Managing Images

```bash
# List images
docker images

# Pull image
docker pull nginx:alpine

# Remove image
docker rmi nginx:alpine

# Remove unused images
docker image prune -a
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
builds/proxmox/ansible/minimal-docker.yml
```

Modify this file to customize the Docker configuration.

## Adding Features

This minimal build focuses on simplicity. To add features:

### Install Docker Compose
```bash
sudo apt install docker-compose-plugin
docker compose version
```

### Add Monitoring
```bash
# Install cAdvisor
docker run -d \
  --name=cadvisor \
  --restart=always \
  -p 8080:8080 \
  -v /:/rootfs:ro \
  -v /var/run:/var/run:ro \
  -v /sys:/sys:ro \
  -v /var/lib/docker/:/var/lib/docker:ro \
  google/cadvisor:latest
```

### Enable Security Features
For production environments, consider using the **hardened-docker** build which includes:
- User namespace remapping
- Audit logging
- AppArmor profiles
- Restricted inter-container communication
- Enhanced daemon security settings

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

### Permission Denied on Docker Socket
```bash
# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Verify group membership
groups
```

### Out of Disk Space
Docker can consume significant disk space:
```bash
# Clean up unused resources
docker system prune -a

# Check disk usage
docker system df

# Set up automatic cleanup (add to crontab)
0 2 * * * docker system prune -f
```

## Use Cases

This minimal Docker build is ideal for:
- Development and testing environments
- CI/CD build agents
- Lightweight container hosting
- Learning Docker
- Resource-constrained environments
- Non-production workloads

For production environments requiring security hardening, use the **hardened-docker** build instead.

## Performance Tips

1. **Use alpine-based images**
   ```bash
   docker run nginx:alpine  # Much smaller than nginx:latest
   ```

2. **Limit container resources**
   ```bash
   docker run --memory="256m" --cpus="0.5" myapp
   ```

3. **Use multi-stage builds** for smaller images
   ```dockerfile
   FROM golang:1.21 AS builder
   # Build stage
   FROM alpine:latest
   # Runtime stage
   ```

4. **Clean up regularly**
   ```bash
   docker system prune -a --volumes
   ```

## Resource Monitoring

Monitor Docker resource usage:

```bash
# View container resource usage
docker stats

# View system-wide Docker disk usage
docker system df

# View detailed disk usage
docker system df -v
```

## Support

For issues specific to this build configuration, please refer to:
- Main repository README
- Packer documentation: https://www.packer.io/docs
- Proxmox documentation: https://pve.proxmox.com/pve-docs/
- Docker documentation: https://docs.docker.com/
