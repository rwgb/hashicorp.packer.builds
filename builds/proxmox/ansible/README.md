# Ansible Playbooks for Packer-Built Hosts

This directory contains Ansible playbooks and roles for configuring hosts built with Packer. The playbooks support multiple host types including Docker hosts, database servers, and web servers.

## 📋 Overview

The main playbook (`playbook.yml`) uses a role-based architecture to configure hosts based on their intended purpose. Each role is modular and can be combined with others.

### Available Roles

| Role | Description | Key Features |
|------|-------------|--------------|
| **common** | Base configuration for all hosts | System packages, timezone, sysctl, ulimits, auto-updates |
| **security** | Security hardening | UFW firewall, fail2ban, SSH hardening |
| **docker** | Docker Engine installation | Docker CE, Docker Compose, user management |
| **database** | Database server setup | PostgreSQL, MySQL, or MariaDB |
| **webserver** | Web server installation | Nginx or Apache with SSL support |
| **monitoring** | Monitoring tools | Prometheus Node Exporter |

## 🚀 Quick Start

### 1. Prerequisites

```bash
# Install Ansible
sudo apt install ansible  # Debian/Ubuntu
brew install ansible       # macOS

# Verify installation
ansible --version
```

### 2. Configure Inventory

Copy the example inventory and customize for your environment:

```bash
cp inventory.example inventory
vim inventory
```

Example inventory entry:
```ini
[docker_hosts]
docker-01 ansible_host=192.168.1.101 ansible_user=debian

[database_hosts]
db-01 ansible_host=192.168.1.201 ansible_user=debian db_engine=postgresql

[webserver_hosts]
web-01 ansible_host=192.168.1.301 ansible_user=debian web_engine=nginx
```

### 3. Run Playbook

```bash
# Configure as Docker host
ansible-playbook playbook.yml -i inventory -e "host_type=docker" --limit docker-01

# Configure as database host (PostgreSQL)
ansible-playbook playbook.yml -i inventory -e "host_type=database db_engine=postgresql" --limit db-01

# Configure as web server (Nginx)
ansible-playbook playbook.yml -i inventory -e "host_type=webserver web_engine=nginx" --limit web-01

# Configure with multiple roles
ansible-playbook playbook.yml -i inventory -e "host_type=docker,webserver" --limit dev-01
```

## 📦 Host Types

### Docker Host

Installs Docker Engine, Docker Compose, and configures Docker daemon.

**Features:**
- Docker CE latest version
- Docker Compose plugin and standalone
- User group management
- Optimized daemon configuration
- Log rotation
- Python Docker SDK

**Usage:**
```bash
ansible-playbook playbook.yml -e "host_type=docker"
```

**Custom Variables:**
```yaml
docker_users:
  - myuser
docker_compose_version: "2.23.0"
docker_preload_images:
  - nginx:latest
  - postgres:15
  - redis:alpine
```

### Database Host

Installs and configures PostgreSQL, MySQL, or MariaDB.

**Supported Engines:**
- PostgreSQL 15 (default)
- MySQL 8.0
- MariaDB 10.11

**Usage:**
```bash
# PostgreSQL
ansible-playbook playbook.yml -e "host_type=database db_engine=postgresql db_version=15"

# MySQL
ansible-playbook playbook.yml -e "host_type=database db_engine=mysql mysql_version=8.0"

# MariaDB
ansible-playbook playbook.yml -e "host_type=database db_engine=mariadb mariadb_version=10.11"
```

**Custom Variables (PostgreSQL example):**
```yaml
postgresql_listen_addresses: "0.0.0.0"
postgresql_max_connections: 200
postgresql_databases:
  - name: myapp
    encoding: UTF8
postgresql_users:
  - name: myapp_user
    password: "changeme"
    role_attr_flags: "CREATEDB,NOSUPERUSER"
postgresql_allowed_networks:
  - "10.0.0.0/8"
  - "192.168.1.0/24"
```

### Web Server Host

Installs and configures Nginx or Apache web server.

**Supported Engines:**
- Nginx (default)
- Apache 2.4

**Usage:**
```bash
# Nginx
ansible-playbook playbook.yml -e "host_type=webserver web_engine=nginx"

# Apache
ansible-playbook playbook.yml -e "host_type=webserver web_engine=apache"
```

**Custom Variables (Nginx example):**
```yaml
nginx_sites:
  - name: example
    server_name: example.com
    document_root: /var/www/example
    port: 80
    ssl: true
    ssl_certificate: /etc/ssl/certs/example.crt
    ssl_certificate_key: /etc/ssl/private/example.key
```

## 🔒 Security Configuration

The security role is automatically applied when `enable_firewall`, `enable_fail2ban`, or `ssh_hardening` is enabled.

**Features:**
- UFW firewall with default deny incoming
- Fail2ban for SSH brute-force protection
- SSH hardening (disable root login, password auth)
- Customizable allowed ports

**Usage:**
```bash
ansible-playbook playbook.yml -e "enable_firewall=true enable_fail2ban=true"
```

**Custom Variables:**
```yaml
firewall_allowed_ports:
  - { port: 80, proto: tcp }
  - { port: 443, proto: tcp }
  - { port: 5432, proto: tcp }

ssh_permit_root_login: "no"
ssh_password_authentication: "no"
fail2ban_maxretry: 3
fail2ban_bantime: "1h"
```

## 📊 Monitoring

The monitoring role installs Prometheus Node Exporter for metrics collection.

**Usage:**
```bash
ansible-playbook playbook.yml --tags monitoring -e "enable_monitoring=true"
```

**Custom Variables:**
```yaml
monitoring_allowed_ips:
  - "10.0.0.100"  # Prometheus server
  - "192.168.1.0/24"
```

**Access Metrics:**
```bash
curl http://your-host:9100/metrics
```

## 🎯 Advanced Usage

### Run Specific Roles Only

```bash
# Only common and security roles
ansible-playbook playbook.yml --tags common,security

# Only Docker role
ansible-playbook playbook.yml --tags docker
```

### Dry Run (Check Mode)

```bash
ansible-playbook playbook.yml --check --diff
```

### Limit to Specific Hosts

```bash
ansible-playbook playbook.yml --limit docker-01,docker-02
```

### Using Variable Files

Create a variable file `vars/production.yml`:
```yaml
host_type: "docker,webserver"
docker_compose_version: "2.23.0"
enable_firewall: true
enable_fail2ban: true
firewall_allowed_ports:
  - { port: 80, proto: tcp }
  - { port: 443, proto: tcp }
```

Run with variable file:
```bash
ansible-playbook playbook.yml -e "@vars/production.yml"
```

### Multi-Role Configuration

```bash
# Docker + Nginx web server
ansible-playbook playbook.yml -e "host_type=docker,webserver web_engine=nginx"

# Database + monitoring
ansible-playbook playbook.yml -e "host_type=database enable_monitoring=true" --tags database,monitoring
```

## 📁 Directory Structure

```
ansible/
├── playbook.yml                    # Main playbook
├── ansible.cfg                     # Ansible configuration
├── inventory.example               # Example inventory
├── inventory                       # Your inventory (gitignored)
├── README.md                       # This file
└── roles/
    ├── common/                     # Base configuration
    │   ├── tasks/main.yml
    │   └── defaults/main.yml
    ├── security/                   # Security hardening
    │   ├── tasks/main.yml
    │   ├── defaults/main.yml
    │   └── handlers/main.yml
    ├── docker/                     # Docker installation
    │   ├── tasks/main.yml
    │   ├── defaults/main.yml
    │   └── handlers/main.yml
    ├── database/                   # Database servers
    │   ├── tasks/
    │   │   ├── main.yml
    │   │   ├── postgresql.yml
    │   │   ├── mysql.yml
    │   │   └── mariadb.yml
    │   ├── defaults/main.yml
    │   └── handlers/main.yml
    ├── webserver/                  # Web servers
    │   ├── tasks/
    │   │   ├── main.yml
    │   │   ├── nginx.yml
    │   │   └── apache.yml
    │   ├── templates/
    │   │   ├── nginx.conf.j2
    │   │   ├── nginx-site.conf.j2
    │   │   └── apache-site.conf.j2
    │   ├── defaults/main.yml
    │   └── handlers/main.yml
    └── monitoring/                 # Monitoring tools
        ├── tasks/main.yml
        ├── defaults/main.yml
        └── handlers/main.yml
```

## 🔧 Configuration Examples

### Development Environment

```yaml
# vars/development.yml
host_type: "docker"
enable_firewall: false
enable_fail2ban: false
docker_users:
  - developer
docker_preload_images:
  - nginx:alpine
  - postgres:15-alpine
  - redis:alpine
```

### Production Web Server

```yaml
# vars/production-web.yml
host_type: "webserver"
web_engine: "nginx"
enable_firewall: true
enable_fail2ban: true
ssh_password_authentication: "no"

firewall_allowed_ports:
  - { port: 80, proto: tcp }
  - { port: 443, proto: tcp }

nginx_sites:
  - name: myapp
    server_name: myapp.example.com
    document_root: /var/www/myapp
    ssl: true
    ssl_certificate: /etc/ssl/certs/myapp.crt
    ssl_certificate_key: /etc/ssl/private/myapp.key
```

### Production Database Server

```yaml
# vars/production-db.yml
host_type: "database"
db_engine: "postgresql"
db_version: "15"
enable_firewall: true
enable_monitoring: true

postgresql_listen_addresses: "0.0.0.0"
postgresql_max_connections: 200
postgresql_shared_buffers: "2GB"
postgresql_allowed_networks:
  - "10.0.0.0/8"

postgresql_databases:
  - name: production_db
    encoding: UTF8

postgresql_users:
  - name: app_user
    password: "{{ vault_db_password }}"
    role_attr_flags: "NOCREATEDB,NOSUPERUSER"

firewall_allowed_ports:
  - { port: 5432, proto: tcp }

monitoring_allowed_ips:
  - "10.0.0.100"
```

## 🔐 Using Ansible Vault for Secrets

```bash
# Create encrypted variable file
ansible-vault create vars/secrets.yml

# Edit encrypted file
ansible-vault edit vars/secrets.yml

# Run playbook with vault
ansible-playbook playbook.yml -e "@vars/secrets.yml" --ask-vault-pass
```

## 🧪 Testing

```bash
# Syntax check
ansible-playbook playbook.yml --syntax-check

# List hosts
ansible all -i inventory --list-hosts

# Test connectivity
ansible all -i inventory -m ping

# Dry run
ansible-playbook playbook.yml -i inventory --check --diff
```

## 📝 Common Variables Reference

### Global Variables
- `host_type`: Comma-separated roles (base, docker, database, webserver)
- `enable_firewall`: Enable UFW firewall (default: true)
- `enable_fail2ban`: Enable fail2ban (default: true)
- `ssh_hardening`: Harden SSH configuration (default: true)
- `timezone`: System timezone (default: UTC)

### Docker Variables
- `docker_users`: List of users to add to docker group
- `docker_compose_version`: Docker Compose version
- `docker_preload_images`: List of Docker images to pull

### Database Variables
- `db_engine`: postgresql, mysql, or mariadb
- `db_version`: Database version
- `postgresql_max_connections`: Max database connections
- `postgresql_databases`: List of databases to create
- `postgresql_users`: List of users to create

### Web Server Variables
- `web_engine`: nginx or apache
- `nginx_sites`: List of Nginx sites to configure
- `apache_sites`: List of Apache sites to configure

## 🤝 Contributing

To add a new role:

1. Create role directory: `mkdir -p roles/myrole/{tasks,defaults,handlers,templates}`
2. Create `roles/myrole/tasks/main.yml`
3. Create `roles/myrole/defaults/main.yml`
4. Add role to `playbook.yml`
5. Document in this README

## 📄 License

See main repository LICENSE file.

## 🆘 Troubleshooting

### SSH Connection Issues
```bash
# Test SSH connectivity
ansible all -i inventory -m ping -vvv

# Use specific SSH key
ansible-playbook playbook.yml --private-key ~/.ssh/mykey
```

### Permission Denied
```bash
# Run with become (sudo)
ansible-playbook playbook.yml --become --ask-become-pass
```

### Check What Would Change
```bash
ansible-playbook playbook.yml --check --diff
```

### Verbose Output
```bash
ansible-playbook playbook.yml -vvv
```
