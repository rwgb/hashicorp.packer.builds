# Hardened Tomcat Application Server Build

## Overview

This build creates a security-hardened Tomcat application server VM based on Debian 12, configured with security valves, session protection, restricted HTTP methods, and fail2ban monitoring.

## VM Configuration

- **VM ID**: 9004
- **VM Name**: debian-12-hardened-tomcat
- **Base Template**: VM ID 9000 (Debian 12 base)
- **Tags**: linux;debian-12;hardened;tomcat

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

The default Tomcat applications (including the manager) are removed for security. If needed, they must be manually re-enabled and configured with proper authentication.

## Software Packages Installed

### Core Packages
- `default-jdk` - Java Development Kit (full JDK for development flexibility)
- `tomcat9` - Apache Tomcat 9 application server
- `tomcat9-admin` - Tomcat administration tools

### Security Packages
- `fail2ban` - Intrusion prevention framework

## Tomcat Security Configuration

### Security Valve (server.xml)

A Remote Address Valve restricts access to localhost only in `/etc/tomcat9/server.xml`:

```xml
<!-- Security Valve -->
<Valve className="org.apache.catalina.valves.RemoteAddrValve"
       allow="127\.\d+\.\d+\.\d+|::1|0:0:0:0:0:0:0:1" />

<!-- Error Report Valve - Hide version information -->
<Valve className="org.apache.catalina.valves.ErrorReportValve"
       showReport="false"
       showServerInfo="false" />
```

**Features**:
- **RemoteAddrValve**: Only allows localhost connections (modify for production)
- **ErrorReportValve**: Hides Tomcat version and detailed error information

### Security Constraints (web.xml)

HTTP method restrictions and security settings in `/etc/tomcat9/web.xml`:

```xml
<!-- Security constraints -->
<security-constraint>
  <web-resource-collection>
    <web-resource-name>Restricted methods</web-resource-name>
    <url-pattern>/*</url-pattern>
    <http-method>TRACE</http-method>
    <http-method>PUT</http-method>
    <http-method>DELETE</http-method>
  </web-resource-collection>
  <auth-constraint/>
</security-constraint>

<!-- Session configuration -->
<session-config>
  <session-timeout>30</session-timeout>
  <cookie-config>
    <http-only>true</http-only>
    <secure>true</secure>
  </cookie-config>
  <tracking-mode>COOKIE</tracking-mode>
</session-config>

<!-- Error pages -->
<error-page>
  <error-code>404</error-code>
  <location>/error.jsp</location>
</error-page>
<error-page>
  <error-code>500</error-code>
  <location>/error.jsp</location>
</error-page>
```

**Features**:
- **Restricted Methods**: TRACE, PUT, DELETE disabled (prevents XST and unauthorized modifications)
- **Session Timeout**: 30 minutes
- **HttpOnly Cookies**: Prevents JavaScript access to session cookies
- **Secure Cookies**: Requires HTTPS for cookie transmission
- **Cookie-based Tracking**: No URL rewriting for sessions
- **Custom Error Pages**: Prevents information disclosure

### Catalina Properties Security

Additional security properties in `/etc/tomcat9/catalina.properties`:

```properties
# Security properties
tomcat.util.scan.StandardJarScanFilter.jarsToSkip=*.jar
tomcat.util.http.parser.HttpParser.requestTargetAllow=|{}
```

**Purpose**:
- Skip unnecessary JAR scanning for faster startup
- Control allowed characters in HTTP request targets

### Removed Default Applications

The following default Tomcat applications are removed for security:

- **ROOT** - Default welcome page
- **docs** - Tomcat documentation
- **examples** - Example applications
- **host-manager** - Virtual host manager
- **manager** - Application manager

**Rationale**: These applications can expose sensitive information and provide attack vectors.

### Dedicated Tomcat User

A dedicated system user is created for running Tomcat:

- **Username**: tomcat
- **System User**: Yes
- **Shell**: /bin/false (no shell access)
- **Home**: /opt/tomcat (not created)

## Network Configuration

- **Default Port**: 8080 (HTTP)
- **AJP Port**: 8009 (if enabled)
- **Shutdown Port**: 8005

**Note**: HTTPS (8443) requires additional SSL/TLS certificate configuration.

## File Locations

### Configuration Files
- Server config: `/etc/tomcat9/server.xml`
- Web application config: `/etc/tomcat9/web.xml`
- Catalina properties: `/etc/tomcat9/catalina.properties`
- Tomcat users: `/etc/tomcat9/tomcat-users.xml`
- Environment variables: `/etc/default/tomcat9`

### Application Directories
- Web applications: `/var/lib/tomcat9/webapps/`
- Configuration: `/etc/tomcat9/`
- Libraries: `/usr/share/tomcat9/lib/`
- Work directory: `/var/cache/tomcat9/`

### Log Files
- Catalina log: `/var/log/tomcat9/catalina.out`
- Access log: `/var/log/tomcat9/localhost_access_log.*.txt`
- Error log: `/var/log/tomcat9/localhost.*.log`

## Services

The following service is enabled and started automatically:

- **tomcat9** - Apache Tomcat 9 application server

## Building the Image

### Build Tomcat Only
```bash
cd /path/to/builds/proxmox/linux/debian/12/hardened
packer build -only='debian_12_hardened_tomcat_only.proxmox-clone.debian_12_hardened_tomcat' .
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
   ```

2. **Configure Tomcat users** (if using manager/admin applications)
   ```bash
   sudo vim /etc/tomcat9/tomcat-users.xml
   ```
   Add:
   ```xml
   <role rolename="manager-gui"/>
   <role rolename="admin-gui"/>
   <user username="admin" password="StrongPassword" roles="manager-gui,admin-gui"/>
   ```

3. **Modify RemoteAddrValve for production**
   ```bash
   sudo vim /etc/tomcat9/server.xml
   ```
   Change the allow pattern to permit your network:
   ```xml
   <Valve className="org.apache.catalina.valves.RemoteAddrValve"
          allow="192\.168\.1\.\d+|127\.\d+\.\d+\.\d+" />
   ```

4. **Deploy your web application**
   ```bash
   # Copy WAR file to webapps
   sudo cp myapp.war /var/lib/tomcat9/webapps/
   
   # Tomcat will auto-deploy the WAR file
   # Check logs
   sudo tail -f /var/log/tomcat9/catalina.out
   ```

5. **Configure SSL/TLS** (recommended)
   ```bash
   # Generate keystore
   sudo keytool -genkey -alias tomcat -keyalg RSA \
     -keystore /etc/tomcat9/keystore.jks \
     -storepass changeit -keypass changeit
   
   # Edit server.xml to enable HTTPS connector
   sudo vim /etc/tomcat9/server.xml
   ```
   Add:
   ```xml
   <Connector port="8443" protocol="org.apache.coyote.http11.Http11NioProtocol"
              maxThreads="150" SSLEnabled="true">
       <SSLHostConfig>
           <Certificate certificateKeystoreFile="/etc/tomcat9/keystore.jks"
                        certificateKeystorePassword="changeit"
                        type="RSA" />
       </SSLHostConfig>
   </Connector>
   ```

6. **Restart Tomcat**
   ```bash
   sudo systemctl restart tomcat9
   ```

7. **Update the system**
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
```

### Manual Deployment Directory

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

### Undeploy Application

```bash
# Stop Tomcat
sudo systemctl stop tomcat9

# Remove application
sudo rm -rf /var/lib/tomcat9/webapps/myapp
sudo rm /var/lib/tomcat9/webapps/myapp.war

# Start Tomcat
sudo systemctl start tomcat9
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
builds/proxmox/ansible/hardened-tomcat.yml
```

Modify this file to customize the Tomcat security configuration.

## Performance Tuning

### JVM Settings

Edit `/etc/default/tomcat9`:

```bash
# Production JVM settings
JAVA_OPTS="-Djava.awt.headless=true"
JAVA_OPTS="$JAVA_OPTS -Xms512m -Xmx2048m"
JAVA_OPTS="$JAVA_OPTS -XX:+UseG1GC"
JAVA_OPTS="$JAVA_OPTS -XX:MaxGCPauseMillis=200"
JAVA_OPTS="$JAVA_OPTS -XX:+DisableExplicitGC"
```

### Connector Settings

Edit `/etc/tomcat9/server.xml`:

```xml
<Connector port="8080" protocol="HTTP/1.1"
           connectionTimeout="20000"
           maxThreads="200"
           minSpareThreads="10"
           maxConnections="10000"
           acceptCount="100"
           compression="on"
           compressionMinSize="2048"
           noCompressionUserAgents="gozilla, traviata"
           compressableMimeType="text/html,text/xml,text/plain,text/css,text/javascript,application/javascript" />
```

## Monitoring

### View Tomcat Logs

```bash
# Real-time log viewing
sudo tail -f /var/log/tomcat9/catalina.out

# View access logs
sudo tail -f /var/log/tomcat9/localhost_access_log.*.txt

# Check for errors
sudo grep -i error /var/log/tomcat9/catalina.out
```

### Check Tomcat Status

```bash
# Service status
sudo systemctl status tomcat9

# Check if Tomcat is listening
sudo netstat -tlnp | grep 8080

# View Java processes
ps aux | grep tomcat
```

### JVM Monitoring

```bash
# Install monitoring tools
sudo apt install openjdk-11-jdk

# Get Tomcat PID
TOMCAT_PID=$(pgrep -f tomcat)

# View thread dump
sudo -u tomcat9 jstack $TOMCAT_PID

# View heap usage
sudo -u tomcat9 jmap -heap $TOMCAT_PID

# Create heap dump
sudo -u tomcat9 jmap -dump:live,format=b,file=/tmp/heap.bin $TOMCAT_PID
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

# View logs
sudo journalctl -xeu tomcat9
sudo tail -n 100 /var/log/tomcat9/catalina.out

# Check port availability
sudo netstat -tlnp | grep 8080
```

### Application Won't Deploy

```bash
# Check file ownership
ls -la /var/lib/tomcat9/webapps/

# Fix ownership
sudo chown -R tomcat9:tomcat9 /var/lib/tomcat9/webapps/

# Check logs for deployment errors
sudo tail -f /var/log/tomcat9/catalina.out
```

### Out of Memory Errors

```bash
# Increase heap size in /etc/default/tomcat9
JAVA_OPTS="$JAVA_OPTS -Xms1024m -Xmx4096m"

# Restart Tomcat
sudo systemctl restart tomcat9
```

### Can't Access Tomcat Remotely

1. Check RemoteAddrValve in server.xml
2. Verify firewall rules
3. Ensure Tomcat is listening on correct interface:
   ```bash
   sudo netstat -tlnp | grep 8080
   ```

## Security Considerations

- Default applications removed - re-enable only if necessary and secure them properly
- RemoteAddrValve restricts localhost only by default - adjust for your network
- Secure cookies require HTTPS - configure SSL/TLS for production
- Regular security updates are essential
- Consider additional hardening:
  - Enable Access Log Valve for auditing
  - Implement request filtering
  - Configure security manager
  - Use strong passwords in tomcat-users.xml
  - Enable HTTPS and disable HTTP
  - Implement rate limiting
  - Regular vulnerability scanning

## Best Practices

1. **Always use HTTPS in production**
2. **Keep Tomcat and Java updated**
3. **Use strong, unique passwords**
4. **Limit manager application access**
5. **Implement regular backups**
6. **Monitor logs for suspicious activity**
7. **Use security manager for untrusted code**
8. **Implement proper error handling**
9. **Regular security audits**
10. **Follow least privilege principle**

## Compliance

This configuration implements several security best practices:
- Dangerous HTTP methods disabled
- Version information hidden
- Default applications removed
- HttpOnly and Secure flags on cookies
- Session timeout configured
- Access controls via RemoteAddrValve
- Custom error pages

For compliance with specific standards (PCI-DSS, OWASP, etc.), additional configuration may be required.

## Support

For issues specific to this build configuration, please refer to:
- Main repository README
- Packer documentation: https://www.packer.io/docs
- Proxmox documentation: https://pve.proxmox.com/pve-docs/
- Tomcat security: https://tomcat.apache.org/tomcat-9.0-doc/security-howto.html
