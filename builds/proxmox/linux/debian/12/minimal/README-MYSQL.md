# Minimal MySQL Database Server Build

## Overview

This build creates a lightweight, minimal MySQL database server VM based on Debian 12, optimized for resource efficiency with essential packages and basic configuration.

## VM Configuration

- **VM ID**: 9007
- **VM Name**: debian-12-minimal-mysql
- **Base Template**: VM ID 9000 (Debian 12 base)
- **Tags**: linux;debian-12;minimal;mysql

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

The MySQL root user can be accessed locally without a password initially:

```bash
sudo mysql
```

**Important**: Set a root password immediately after deployment.

## Software Packages Installed

### Core Packages (Minimal)
- `mysql-server` - MySQL database server
- `python3-pymysql` - Python MySQL client library

**Note**: Packages installed with `--no-install-recommends` flag for minimal footprint.

### Not Included
- fail2ban (use hardened build for security features)
- Additional monitoring tools
- Backup utilities

## MySQL Configuration

### Minimal Resource Settings

The MySQL server is configured for minimal resource usage in `/etc/mysql/mysql.conf.d/minimal.cnf`:

```ini
[mysqld]
# Minimal resource configuration
innodb_buffer_pool_size = 128M   # Small buffer pool
max_connections = 50              # Limited connections
thread_cache_size = 8             # Small thread cache
query_cache_size = 16M            # Small query cache
query_cache_limit = 1M            # Small query cache entries

# Network settings
bind-address = 127.0.0.1          # Localhost only

# Logging (minimal)
log_error = /var/log/mysql/error.log
```

### Performance Schema Disabled

Performance schema is disabled to reduce memory overhead in `/etc/mysql/mysql.conf.d/performance.cnf`:

```ini
[mysqld]
performance_schema = OFF
```

**Impact**: Reduces memory usage by ~400MB but disables performance monitoring features.

### Key Configuration Choices

#### InnoDB Buffer Pool
- **Setting**: 128M
- **Purpose**: Minimal memory for InnoDB cache
- **Recommendation**: Increase for production (typically 70-80% of available RAM)

#### Max Connections
- **Setting**: 50
- **Purpose**: Limit concurrent connections
- **Consideration**: Increase if you need more connections

#### Query Cache
- **Setting**: 16M size, 1M limit per query
- **Purpose**: Cache frequent queries
- **Note**: Query cache is deprecated in MySQL 8.0+

#### Network Binding
- **Setting**: 127.0.0.1 (localhost only)
- **Purpose**: Prevent remote connections by default
- **Modification**: Change to `0.0.0.0` for remote access

## Resource Usage

This minimal configuration is optimized for:
- **Low Memory**: Suitable for VMs with 512MB-1GB RAM
- **Low Disk Space**: Minimal package installation
- **Fast Startup**: No additional tools or monitoring

**Comparison to Hardened Build**:
- No fail2ban
- No strict security configurations
- No SSL/TLS pre-configuration
- No audit logging
- Smaller buffer pools and caches
- Performance schema disabled

## Network Configuration

- **Default Port**: 3306 (TCP)
- **Bind Address**: 127.0.0.1 (localhost only)

**To allow remote connections**:
```bash
sudo vim /etc/mysql/mysql.conf.d/minimal.cnf
# Change: bind-address = 0.0.0.0
sudo systemctl restart mysql
```

## File Locations

### Configuration Files
- Main MySQL config: `/etc/mysql/mysql.conf.d/mysqld.cnf`
- Minimal config: `/etc/mysql/mysql.conf.d/minimal.cnf`
- Performance config: `/etc/mysql/mysql.conf.d/performance.cnf`

### Log Files
- Error log: `/var/log/mysql/error.log`

### Data Directory
- MySQL data: `/var/lib/mysql/`

## Services

The following service is enabled and started automatically:

- **mysql** - MySQL database server

## Building the Image

### Build MySQL Only
```bash
cd /path/to/builds/proxmox/linux/debian/12/minimal
packer build -only='debian_12_minimal_mysql_only.proxmox-clone.debian_12_minimal_mysql' .
```

### Build All Minimal Variants
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
   sudo mysql_secure_installation
   ```
   This will:
   - Set root password
   - Remove anonymous users
   - Disable remote root login
   - Remove test database

3. **Set MySQL root password**
   ```bash
   sudo mysql
   ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'YourPassword';
   FLUSH PRIVILEGES;
   EXIT;
   ```

4. **Create application database and user**
   ```bash
   mysql -u root -p
   CREATE DATABASE myapp;
   CREATE USER 'appuser'@'localhost' IDENTIFIED BY 'password';
   GRANT ALL PRIVILEGES ON myapp.* TO 'appuser'@'localhost';
   FLUSH PRIVILEGES;
   EXIT;
   ```

5. **Update the system**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

## Basic Usage

### Connecting to MySQL

```bash
# As root (locally)
sudo mysql

# As root with password
mysql -u root -p

# As specific user
mysql -u appuser -p myapp
```

### Common Operations

```bash
# List databases
mysql> SHOW DATABASES;

# Use a database
mysql> USE myapp;

# List tables
mysql> SHOW TABLES;

# Show table structure
mysql> DESCRIBE tablename;

# List users
mysql> SELECT User, Host FROM mysql.user;

# Grant privileges
mysql> GRANT SELECT, INSERT, UPDATE ON myapp.* TO 'user'@'localhost';
mysql> FLUSH PRIVILEGES;
```

### Basic Database Management

```bash
# Create database
mysql> CREATE DATABASE mydb;

# Drop database
mysql> DROP DATABASE mydb;

# Create table
mysql> CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    email VARCHAR(100)
);

# Insert data
mysql> INSERT INTO users (username, email) VALUES ('john', 'john@example.com');

# Query data
mysql> SELECT * FROM users;
```

## Backup and Restore

### Manual Backup

```bash
# Backup single database
mysqldump -u root -p myapp > myapp_backup.sql

# Backup all databases
mysqldump -u root -p --all-databases > all_backup.sql

# Backup with compression
mysqldump -u root -p myapp | gzip > myapp_backup.sql.gz
```

### Restore Database

```bash
# Restore from backup
mysql -u root -p myapp < myapp_backup.sql

# Restore compressed backup
gunzip < myapp_backup.sql.gz | mysql -u root -p myapp
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
builds/proxmox/ansible/minimal-mysql.yml
```

Modify this file to customize the MySQL configuration.

## Adding Features

This minimal build focuses on simplicity. To add features:

### Enable Remote Access

```bash
# Edit configuration
sudo vim /etc/mysql/mysql.conf.d/minimal.cnf
# Change: bind-address = 0.0.0.0

# Restart MySQL
sudo systemctl restart mysql

# Create remote user
mysql -u root -p
CREATE USER 'remoteuser'@'%' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON myapp.* TO 'remoteuser'@'%';
FLUSH PRIVILEGES;
```

### Install Additional Tools

```bash
# Install phpMyAdmin
sudo apt install phpmyadmin

# Install monitoring tools
sudo apt install mytop

# Install backup tools
sudo apt install automysqlbackup
```

### Add Security Features

For production environments, consider using the **hardened-mysql** build which includes:
- fail2ban protection
- Strict security configurations
- SSL/TLS support
- Connection limits
- Audit logging capabilities

## Troubleshooting

### Build Fails with Permission Error
Ensure your Proxmox API token has the required permissions.

### SSH Connection Timeout
Verify base template configuration and network connectivity.

### MySQL Won't Start
```bash
sudo journalctl -xeu mysql
sudo tail -f /var/log/mysql/error.log
sudo systemctl status mysql
```

### Can't Connect to MySQL
```bash
# Check if MySQL is running
sudo systemctl status mysql

# Check if MySQL is listening
sudo netstat -tlnp | grep 3306

# Check bind address
mysql -u root -p -e "SHOW VARIABLES LIKE 'bind_address';"
```

### Forgot Root Password
```bash
# Stop MySQL
sudo systemctl stop mysql

# Start in safe mode
sudo mysqld_safe --skip-grant-tables &

# Connect and reset password
mysql -u root
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY 'newpassword';
EXIT;

# Restart normally
sudo systemctl restart mysql
```

### Out of Connections
```bash
# Increase max_connections temporarily
mysql -u root -p
SET GLOBAL max_connections = 100;

# Make permanent
sudo vim /etc/mysql/mysql.conf.d/minimal.cnf
# Change: max_connections = 100
sudo systemctl restart mysql
```

## Performance Optimization

### For Better Performance

If you need better performance, adjust settings in minimal.cnf:

```ini
[mysqld]
# Increase buffer pool (use 70-80% of available RAM)
innodb_buffer_pool_size = 512M

# Increase connections
max_connections = 100

# Increase query cache (if using MySQL 5.7)
query_cache_size = 64M

# Enable performance schema (if you have RAM)
performance_schema = ON
```

### Monitor Performance

```bash
# Check MySQL status
mysql -u root -p -e "SHOW STATUS;"

# Check slow queries
mysql -u root -p -e "SHOW GLOBAL STATUS LIKE 'Slow_queries';"

# View current connections
mysql -u root -p -e "SHOW PROCESSLIST;"

# Check buffer pool usage
mysql -u root -p -e "SHOW STATUS LIKE 'Innodb_buffer_pool%';"
```

## Use Cases

This minimal MySQL build is ideal for:
- Development and testing environments
- Small applications with low traffic
- Learning SQL and database management
- Microservices with dedicated databases
- Resource-constrained environments
- CI/CD database instances

For production environments with security requirements, use the **hardened-mysql** build instead.

## Limitations

- No fail2ban protection
- No SSL/TLS encryption configured
- Performance schema disabled
- Small buffer pools (limited performance)
- Basic logging only
- No automated backups
- No monitoring tools included

## Support

For issues specific to this build configuration, please refer to:
- Main repository README
- Packer documentation: https://www.packer.io/docs
- Proxmox documentation: https://pve.proxmox.com/pve-docs/
- MySQL documentation: https://dev.mysql.com/doc/
