# Hardened MySQL Database Server Build

## Overview

This build creates a security-hardened MySQL database server VM based on Debian 12, configured with strict security settings, connection limits, fail2ban protection, and hardened MySQL configuration.

## VM Configuration

- **VM ID**: 9003
- **VM Name**: debian-12-hardened-mysql
- **Base Template**: VM ID 9000 (Debian 12 base)
- **Tags**: linux;debian-12;hardened;mysql

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

### MySQL Root Access

The MySQL root user is configured for local authentication only. After deployment, secure the MySQL installation:

```bash
sudo /root/mysql_secure.sh
# Or run the security script manually
```

## Software Packages Installed

### Core Packages
- `mysql-server` - MySQL database server
- `python3-pymysql` - Python MySQL client library (for Ansible management)

### Security Packages
- `fail2ban` - Intrusion prevention framework

## MySQL Security Configuration

### Security Settings

The MySQL server is configured with strict security settings in `/etc/mysql/mysql.conf.d/security.cnf`:

```ini
[mysqld]
# Security settings
local-infile=0              # Disable LOCAL INFILE
symbolic-links=0            # Disable symbolic links
skip-show-database          # Hide database list from non-privileged users

# Network settings
bind-address = 127.0.0.1    # Listen on localhost only

# Logging
log_error = /var/log/mysql/error.log
log_warnings = 2

# Connection limits
max_connections = 100        # Maximum concurrent connections
max_connect_errors = 10      # Max errors before host block

# User limits
max_user_connections = 50    # Max connections per user
```

### Key Security Features

#### LOCAL INFILE Disabled
- **Setting**: `local-infile=0`
- **Purpose**: Prevents loading local files into database
- **Impact**: Protects against file system access attacks

#### Symbolic Links Disabled
- **Setting**: `symbolic-links=0`
- **Purpose**: Prevents symlink attacks
- **Impact**: Database files cannot be symlinked to sensitive locations

#### Network Binding
- **Setting**: `bind-address = 127.0.0.1`
- **Purpose**: MySQL only accessible from localhost
- **Impact**: Prevents remote connections (modify for remote access)

#### Connection Limits
- **max_connections**: 100 total connections
- **max_connect_errors**: 10 errors before host block
- **max_user_connections**: 50 per user
- **Purpose**: Prevent resource exhaustion and brute force attacks

### SQL Mode

Strict SQL mode is enforced in `/etc/mysql/mysql.conf.d/sql-mode.cnf`:

```ini
[mysqld]
sql_mode=STRICT_ALL_TABLES,NO_ZERO_DATE,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION
```

**Enabled Modes**:
- `STRICT_ALL_TABLES` - Strict mode for all storage engines
- `NO_ZERO_DATE` - Don't allow '0000-00-00' as valid date
- `NO_ZERO_IN_DATE` - Don't allow dates with zero parts
- `ERROR_FOR_DIVISION_BY_ZERO` - Treat division by zero as error
- `NO_ENGINE_SUBSTITUTION` - Don't automatically substitute storage engines

### Fail2ban Configuration

Fail2ban monitors MySQL authentication failures in `/etc/fail2ban/jail.d/mysql.conf`:

```ini
[mysqld-auth]
enabled = true
port = 3306
logpath = /var/log/mysql/error.log
maxretry = 5           # Ban after 5 failed attempts
bantime = 600          # Ban for 10 minutes
```

### File Permissions

MySQL directories are configured with strict permissions:

- `/var/lib/mysql` - Mode 0750, owned by mysql:mysql
- `/var/log/mysql` - Mode 0750, owned by mysql:mysql

### MySQL Security Script

A security script is created at `/root/mysql_secure.sh` that performs:
- Remove anonymous users
- Remove remote root access
- Drop test database
- Flush privileges

**Mode**: 0700 (root only)

## SSL/TLS Configuration

SSL/TLS settings are pre-configured but commented out in the security configuration:

```ini
# require_secure_transport = ON
# ssl-ca=/etc/mysql/ssl/ca-cert.pem
# ssl-cert=/etc/mysql/ssl/server-cert.pem
# ssl-key=/etc/mysql/ssl/server-key.pem
```

Uncomment and configure certificates for encrypted connections.

## Network Configuration

- **Default Port**: 3306 (TCP)
- **Bind Address**: 127.0.0.1 (localhost only)

**Important**: To allow remote connections:
1. Change `bind-address` to `0.0.0.0` or specific IP
2. Configure firewall rules
3. Create MySQL users with appropriate host restrictions
4. Consider enabling SSL/TLS for remote connections

## File Locations

### Configuration Files
- Main MySQL config: `/etc/mysql/mysql.conf.d/mysqld.cnf`
- Security config: `/etc/mysql/mysql.conf.d/security.cnf`
- SQL mode config: `/etc/mysql/mysql.conf.d/sql-mode.cnf`
- Fail2ban config: `/etc/fail2ban/jail.d/mysql.conf`
- Security script: `/root/mysql_secure.sh`

### Log Files
- Error log: `/var/log/mysql/error.log`
- Fail2ban log: `/var/log/fail2ban.log`

### Data Directory
- MySQL data: `/var/lib/mysql/`

## Services

The following services are enabled and started automatically:

- **mysql** - MySQL database server
- **fail2ban** - Intrusion prevention

## Building the Image

### Build MySQL Only
```bash
cd /path/to/builds/proxmox/linux/debian/12/hardened
packer build -only='debian_12_hardened_mysql_only.proxmox-clone.debian_12_hardened_mysql' .
```

### Build All Hardened Variants
```bash
packer build .
```

## Post-Deployment Steps

After deploying a VM from this template, you should:

1. **Change default system credentials**
   ```bash
   sudo passwd packer
   ```

2. **Secure MySQL installation**
   ```bash
   sudo /root/mysql_secure.sh
   # Or manually run mysql_secure_installation
   ```

3. **Set MySQL root password**
   ```bash
   sudo mysql
   ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'YourStrongPassword';
   FLUSH PRIVILEGES;
   EXIT;
   ```

4. **Create application database and user**
   ```bash
   sudo mysql -u root -p
   CREATE DATABASE myapp;
   CREATE USER 'appuser'@'localhost' IDENTIFIED BY 'StrongPassword';
   GRANT ALL PRIVILEGES ON myapp.* TO 'appuser'@'localhost';
   FLUSH PRIVILEGES;
   EXIT;
   ```

5. **Configure remote access (if needed)**
   ```bash
   # Edit security config
   sudo vim /etc/mysql/mysql.conf.d/security.cnf
   # Change: bind-address = 0.0.0.0
   
   # Create remote user
   sudo mysql -u root -p
   CREATE USER 'remoteuser'@'192.168.1.%' IDENTIFIED BY 'StrongPassword';
   GRANT SELECT, INSERT, UPDATE ON myapp.* TO 'remoteuser'@'192.168.1.%';
   FLUSH PRIVILEGES;
   EXIT;
   
   # Restart MySQL
   sudo systemctl restart mysql
   ```

6. **Enable SSL/TLS (recommended for remote access)**
   ```bash
   # Generate certificates
   sudo mysql_ssl_rsa_setup --uid=mysql
   
   # Uncomment SSL settings in security.cnf
   sudo vim /etc/mysql/mysql.conf.d/security.cnf
   
   # Restart MySQL
   sudo systemctl restart mysql
   ```

7. **Verify fail2ban is working**
   ```bash
   sudo fail2ban-client status mysqld-auth
   ```

8. **Update the system**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

## Database Management

### Common Operations

```bash
# Check MySQL status
sudo systemctl status mysql

# View MySQL logs
sudo tail -f /var/log/mysql/error.log

# Connect to MySQL
sudo mysql -u root -p

# List databases
mysql> SHOW DATABASES;

# List users
mysql> SELECT User, Host FROM mysql.user;

# Check connections
mysql> SHOW PROCESSLIST;

# Check variables
mysql> SHOW VARIABLES LIKE 'max_connections';
```

### Backup and Restore

```bash
# Backup database
mysqldump -u root -p myapp > myapp_backup.sql

# Backup all databases
mysqldump -u root -p --all-databases > all_databases.sql

# Restore database
mysql -u root -p myapp < myapp_backup.sql

# Automated backup script
cat > /root/backup_mysql.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
mysqldump -u root -p'PASSWORD' --all-databases | gzip > /backup/mysql_$DATE.sql.gz
find /backup -name "mysql_*.sql.gz" -mtime +7 -delete
EOF
chmod 700 /root/backup_mysql.sh
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
The Ansible playbook that configures MySQL is located at:
```
builds/proxmox/ansible/hardened-mysql.yml
```

Modify this file to customize the MySQL security configuration.

## Performance Tuning

For production workloads, consider adjusting:

```ini
[mysqld]
innodb_buffer_pool_size = 1G      # 70-80% of available RAM
max_connections = 200              # Adjust based on load
query_cache_size = 64M             # For read-heavy workloads
tmp_table_size = 64M
max_heap_table_size = 64M
```

## Troubleshooting

### Build Fails with Permission Error
Ensure your Proxmox API token has the required permissions.

### SSH Connection Timeout
Verify base template configuration and network connectivity.

### MySQL Won't Start
```bash
sudo journalctl -xeu mysql
sudo tail -f /var/log/mysql/error.log
```

### Can't Connect to MySQL Remotely
1. Check bind-address setting
2. Verify user host restrictions
3. Check firewall rules
4. Verify MySQL is listening:
   ```bash
   sudo netstat -tlnp | grep 3306
   ```

### Too Many Connections Error
```bash
mysql> SET GLOBAL max_connections = 200;
# Then update in security.cnf permanently
```

### Fail2ban Not Banning
```bash
# Check fail2ban status
sudo fail2ban-client status mysqld-auth

# View fail2ban log
sudo tail -f /var/log/fail2ban.log

# Test the regex
sudo fail2ban-regex /var/log/mysql/error.log /etc/fail2ban/filter.d/mysqld-auth.conf
```

## Security Considerations

- MySQL root should only be accessible locally
- Use strong passwords (minimum 16 characters)
- Create specific users with limited privileges for each application
- Enable SSL/TLS for any remote connections
- Regularly update MySQL and apply security patches
- Monitor failed authentication attempts
- Implement regular backups
- Consider additional hardening:
  - Enable audit logging
  - Implement firewall rules
  - Use SELinux or AppArmor
  - Encrypt data at rest
  - Implement connection encryption

## Monitoring

Monitor MySQL performance and security:

```bash
# Install monitoring tools
sudo apt install mytop

# View live MySQL activity
sudo mytop

# Check slow queries
mysql> SHOW GLOBAL STATUS LIKE 'Slow_queries';

# Check failed logins
sudo grep "Access denied" /var/log/mysql/error.log

# Monitor connections
mysql> SHOW STATUS LIKE 'Threads_connected';
mysql> SHOW STATUS LIKE 'Max_used_connections';
```

## Compliance

This configuration implements several security best practices:
- Disabled LOCAL INFILE
- Disabled symbolic links
- Strict SQL mode enabled
- Connection limits configured
- Failed login monitoring with fail2ban
- Restricted file permissions
- No test database or anonymous users (via security script)

For compliance with specific standards (PCI-DSS, HIPAA, etc.), additional configuration may be required.

## Support

For issues specific to this build configuration, please refer to:
- Main repository README
- Packer documentation: https://www.packer.io/docs
- Proxmox documentation: https://pve.proxmox.com/pve-docs/
- MySQL security: https://dev.mysql.com/doc/refman/8.0/en/security.html
