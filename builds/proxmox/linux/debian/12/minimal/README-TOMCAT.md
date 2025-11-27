# Minimal Tomcat Application Server Build

## Overview

This build creates a lightweight, minimal Tomcat application server VM based on Debian 12, optimized for resource efficiency with essential packages and basic configuration.

## VM Configuration

- **VM ID**: 9008
- **VM Name**: debian-12-minimal-tomcat
- **Base Template**: VM ID 9000 (Debian 12 base)
- **Tags**: linux;debian-12;minimal;tomcat

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

### Tomcat Manager Access

The default Tomcat applications (including the manager) are removed. If needed, they must be manually re-enabled.

## Software Packages Installed

### Core Packages (Minimal)
- `default-jre-headless` - Java Runtime Environment (headless, no GUI components)
- `tomcat9` - Apache Tomcat 9 application server

**Note**: Packages installed with `--no-install-recommends` flag for minimal footprint.

### Not Included
- Tomcat admin tools (use hardened build if needed)
- Full JDK (only JRE for running applications)
- fail2ban (use hardened build for security features)
- Documentation

## Tomcat Configuration

### Minimal JVM Settings

JVM is configured for minimal resource usage in `/etc/default/tomcat9`:

```bash
# Minimal JVM settings
JAVA_OPTS="-Djava.awt.headless=true -Xmx256m -Xms128m -XX:+UseSerialGC"
```

**Settings Explained**:
- `-Djava.awt.headless=true` - No GUI support needed
- `-Xmx256m` - Maximum heap size 256MB
- `-Xms128m` - Initial heap size 128MB
- `-XX:+UseSerialGC` - Serial garbage collector (low overhead)

### Minimal Connector Settings

HTTP connector configured for minimal resource usage in `/etc/tomcat9/server.xml`:

```xml
<!-- Minimal connection settings -->
maxThreads="50"
minSpareThreads="5"
connectionTimeout="20000"
```

**Settings Explained**:
- `maxThreads="50"` - Maximum 50 concurrent connections
- `minSpareThreads="5"` - Keep 5 threads ready
- `connectionTimeout="20000"` - 20 second timeout

### Removed Default Applications

The following default Tomcat applications are removed to save disk space:

- **ROOT** - Default welcome page
- **docs** - Tomcat documentation
- **examples** - Example applications
- **host-manager** - Virtual host manager
- **manager** - Application manager

## Resource Usage

This minimal configuration is optimized for:
- **Low Memory**: Suitable for VMs with 512MB-1GB RAM
- **Low Disk Space**: Minimal package installation
- **Fast Startup**: Fewer threads and smaller heap

**Comparison to Hardened Build**:
- No security valves or strict access controls
- No fail2ban
- JRE only (no full JDK)
- Smaller heap sizes
- Fewer worker threads
- No tomcat-admin package

## Network Configuration

- **Default Port**: 8080 (HTTP)
- **Shutdown Port**: 8005

**Note**: No access restrictions by default (unlike hardened build).

## File Locations

### Configuration Files
- Server config: `/etc/tomcat9/server.xml`
- Web application config: `/etc/tomcat9/web.xml`
- Environment variables: `/etc/default/tomcat9`

### Application Directories
- Web applications: `/var/lib/tomcat9/webapps/`
- Configuration: `/etc/tomcat9/`
- Libraries: `/usr/share/tomcat9/lib/`
- Work directory: `/var/cache/tomcat9/`

### Log Files
- Catalina log: `/var/log/tomcat9/catalina.out`
- Access log: `/var/log/tomcat9/localhost_access_log.*.txt` (if enabled)

## Services

The following service is enabled and started automatically:

- **tomcat9** - Apache Tomcat 9 application server

## Building the Image

### Build Tomcat Only
```bash
cd /path/to/builds/proxmox/linux/debian/12/minimal
packer build -only='debian_12_minimal_tomcat_only.proxmox-clone.debian_12_minimal_tomcat' .
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
   ```

2. **Deploy your web application**
   ```bash
   sudo cp myapp.war /var/lib/tomcat9/webapps/
   ```

3. **Adjust JVM memory if needed**
   ```bash
   sudo vim /etc/default/tomcat9
   # Adjust -Xmx and -Xms values
   sudo systemctl restart tomcat9
   ```

4. **Update the system**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

## Application Deployment

### Deploy WAR File

```bash
# Copy WAR to webapps directory
sudo cp application.war /var/lib/tomcat9/webapps/

# Tomcat auto-deploys the application
# Access at: http://server:8080/application/

# Check deployment logs
sudo tail -f /var/log/tomcat9/catalina.out
```

### Deploy Exploded Directory

```bash
# Create application directory
sudo mkdir -p /var/lib/tomcat9/webapps/myapp

# Copy application files
sudo cp -r /path/to/webapp/* /var/lib/tomcat9/webapps/myapp/

# Set ownership
sudo chown -R tomcat9:tomcat9 /var/lib/tomcat9/webapps/myapp

# Restart Tomcat
sudo systemctl restart tomcat9
```

### Check Application Status

```bash
# View deployment logs
sudo tail -f /var/log/tomcat9/catalina.out

# Test application
curl http://localhost:8080/myapp/
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
The Ansible playbook that configures Tomcat is located at:
```
builds/proxmox/ansible/minimal-tomcat.yml
```

Modify this file to customize the Tomcat configuration.

## Adjusting Resource Limits

### Increase Memory

For larger applications, increase heap size:

```bash
sudo vim /etc/default/tomcat9
```

Change:
```bash
JAVA_OPTS="-Djava.awt.headless=true -Xmx512m -Xms256m -XX:+UseSerialGC"
```

### Increase Connections

For higher traffic, edit `/etc/tomcat9/server.xml`:

```xml
<Connector port="8080" protocol="HTTP/1.1"
           maxThreads="100"
           minSpareThreads="10"
           connectionTimeout="20000" />
```

## Adding Features

This minimal build focuses on simplicity. To add features:

### Install Manager Application

```bash
# Reinstall tomcat-admin package
sudo apt install tomcat9-admin

# Configure users
sudo vim /etc/tomcat9/tomcat-users.xml
```

Add:
```xml
<role rolename="manager-gui"/>
<user username="admin" password="password" roles="manager-gui"/>
```

### Enable Access Logging

Edit `/etc/tomcat9/server.xml`, add inside `<Host>` element:

```xml
<Valve className="org.apache.catalina.valves.AccessLogValve"
       directory="logs"
       prefix="localhost_access_log" suffix=".txt"
       pattern="%h %l %u %t &quot;%r&quot; %s %b" />
```

### Add Security Features

For production environments, consider using the **hardened-tomcat** build which includes:
- Security valves and access controls
- Restricted HTTP methods
- HttpOnly and Secure cookies
- fail2ban protection
- Version information hiding

## Basic Management

### Start/Stop/Restart Tomcat

```bash
# Stop Tomcat
sudo systemctl stop tomcat9

# Start Tomcat
sudo systemctl start tomcat9

# Restart Tomcat
sudo systemctl restart tomcat9

# Check status
sudo systemctl status tomcat9
```

### View Logs

```bash
# Real-time log viewing
sudo tail -f /var/log/tomcat9/catalina.out

# View last 100 lines
sudo tail -n 100 /var/log/tomcat9/catalina.out

# Search for errors
sudo grep -i error /var/log/tomcat9/catalina.out
```

### Check if Tomcat is Running

```bash
# Check service
sudo systemctl status tomcat9

# Check if listening on port 8080
sudo netstat -tlnp | grep 8080

# Test with curl
curl http://localhost:8080/
```

## Troubleshooting

### Build Fails with Permission Error
Ensure your Proxmox API token has the required permissions.

### SSH Connection Timeout
Verify base template configuration and network connectivity.

### Tomcat Won't Start

```bash
# Check service status
sudo systemctl status tomcat9

# View detailed logs
sudo journalctl -xeu tomcat9
sudo tail -f /var/log/tomcat9/catalina.out

# Check if port is already in use
sudo netstat -tlnp | grep 8080
```

### Application Won't Deploy

```bash
# Check file permissions
ls -la /var/lib/tomcat9/webapps/

# Fix ownership
sudo chown -R tomcat9:tomcat9 /var/lib/tomcat9/webapps/

# Check logs
sudo tail -f /var/log/tomcat9/catalina.out
```

### Out of Memory Errors

```bash
# Increase heap in /etc/default/tomcat9
JAVA_OPTS="-Djava.awt.headless=true -Xmx512m -Xms256m -XX:+UseSerialGC"

# Restart Tomcat
sudo systemctl restart tomcat9

# Monitor memory usage
ps aux | grep tomcat
```

### Slow Performance

```bash
# Switch to better garbage collector
JAVA_OPTS="-Djava.awt.headless=true -Xmx512m -Xms256m -XX:+UseG1GC"

# Increase thread count in server.xml
# maxThreads="100"

# Restart Tomcat
sudo systemctl restart tomcat9
```

## Use Cases

This minimal Tomcat build is ideal for:
- Development and testing environments
- Small web applications
- Microservices
- Learning Java web development
- CI/CD deployment targets
- Resource-constrained environments

For production environments with security requirements, use the **hardened-tomcat** build instead.

## Performance Tips

1. **Use appropriate JVM settings** for your workload
2. **Deploy only necessary applications**
3. **Monitor memory usage** and adjust heap accordingly
4. **Use connection pooling** in your applications
5. **Enable compression** for text-based responses
6. **Consider upgrading to G1GC** for better performance

## Monitoring

### Basic Monitoring

```bash
# Check Tomcat status
sudo systemctl status tomcat9

# View real-time logs
sudo tail -f /var/log/tomcat9/catalina.out

# Check memory usage
ps aux | grep tomcat

# View open connections
sudo netstat -an | grep 8080
```

### Install Monitoring Tools (Optional)

```bash
# Install Java monitoring tools (requires full JDK)
sudo apt install openjdk-11-jdk

# Get Tomcat PID
TOMCAT_PID=$(pgrep -f tomcat)

# View thread information
sudo -u tomcat9 jstack $TOMCAT_PID
```

## Limitations

- Small heap size (256MB max)
- Limited concurrent connections (50)
- No manager/admin tools included
- No security hardening
- Basic logging only
- JRE only (no development tools)

For applications requiring more resources or security, adjust configuration or use the hardened build.

## Support

For issues specific to this build configuration, please refer to:
- Main repository README
- Packer documentation: https://www.packer.io/docs
- Proxmox documentation: https://pve.proxmox.com/pve-docs/
- Tomcat documentation: https://tomcat.apache.org/tomcat-9.0-doc/
