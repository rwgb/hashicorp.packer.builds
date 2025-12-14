# Windows Server 2019 Packer Builds

This directory contains HashiCorp Packer configurations for building Windows Server 2019 virtual machine templates on Proxmox VE. Multiple build variants are available, each optimized for specific use cases.

## 📋 Available Builds

### Base Build (`base/`)
- **VM ID**: 9010
- **Builder**: `proxmox-iso`
- **Purpose**: Foundation template for all other builds
- **Features**:
  - Clean Windows Server 2019 Datacenter installation from ISO
  - VirtIO drivers pre-installed
  - Windows Updates applied
  - Sysprepped and ready for cloning
- **Build Time**: ~90 minutes (including Windows Updates)

### Domain Controller (`domain-controller/`)
- **VM ID**: 9012
- **Builder**: `proxmox-iso`
- **Purpose**: Active Directory Domain Controller
- **Features**:
  - Full AD DS installation with forest creation
  - DNS server with configurable forwarders
  - Default OUs (Servers, Workstations, Users, Groups, Service Accounts)
  - AD Recycle Bin enabled
  - Firewall rules for DC services (DNS, Kerberos, LDAP, SMB, Global Catalog)
- **Configuration**: Ansible playbook (`windows-domain-controller.yml`)
- **Build Time**: ~120 minutes

### DHCP/DNS Server (`dhcp-dns/`)
- **VM ID**: 9013
- **Builder**: `proxmox-clone`
- **Purpose**: Standalone DHCP and DNS server
- **Features**:
  - DNS server with primary zones and forwarders
  - DHCP server with configurable scope
  - Dynamic DNS updates enabled
  - DHCP audit logging
  - Firewall rules for DHCP/DNS services
- **Configuration**: Ansible playbook (`windows-dhcp-dns.yml`)
- **Build Time**: ~60 minutes

### Minimal Build (`minimal/`)
- **VM ID**: 9011
- **Builder**: `proxmox-clone`
- **Purpose**: Lightweight baseline server
- **Features**:
  - Cloned from base template
  - Minimal configuration applied
  - Windows initialization and preparation scripts
  - Windows Updates applied
- **Build Time**: ~45 minutes

### Hardened Build (`hardened/`)
- **VM ID**: 9014
- **Builder**: `proxmox-clone`
- **Purpose**: Security-hardened baseline server
- **Features**:
  - CIS Microsoft Windows Server 2019 Benchmark compliance
  - Strong password policies (14 char min, complexity, 60-day max age, 24 password history)
  - Account lockout policy (5 attempts, 30 min duration)
  - Comprehensive audit logging enabled
  - Windows Firewall enabled and configured
  - SMBv1 disabled, SMB signing enforced
  - LLMNR and NetBIOS disabled
  - LSA protection and Credential Guard enabled
  - TLS 1.2 enforced (SSL 2.0/3.0, TLS 1.0/1.1 disabled)
  - Unnecessary services disabled
  - Windows Defender optimized
  - PowerShell v2 removed
- **Configuration**: Ansible playbook (`windows-hardened.yml`)
- **Build Time**: ~50 minutes

## 🚀 Quick Start

### Prerequisites

- Proxmox VE 7.x or later
- Packer 1.9.4 or later
- Ansible 2.9 or later (for builds using Ansible provisioner)
- Windows Server 2019 ISO uploaded to Proxmox storage
- VirtIO drivers (included in builds)

### Build Order

It's recommended to build in this order:

1. **Base** - Creates the foundation template
2. **Minimal** or **Hardened** - Clone-based builds from base
3. **Domain Controller** - Full ISO build with AD DS
4. **DHCP/DNS** - Clone-based or standalone build

### Building the Base Template

```bash
cd base/

# Create variables file (or use variables.auto.pkrvars.hcl)
cat > variables.auto.pkrvars.hcl <<EOF
proxmox_host     = "192.168.1.160"
node             = "skull"
pool             = "packer_builds"
username         = "Administrator"
password         = "YourPassword"
iso_storage_pool = "local"
disk_storage_pool = "local-lvm"
EOF

# Initialize Packer
packer init .

# Validate configuration
packer validate .

# Build
packer build .
```

### Building the Domain Controller

```bash
cd domain-controller/

# Create variables file
cat > variables.auto.pkrvars.hcl <<EOF
proxmox_host          = "192.168.1.160"
node                  = "skull"
pool                  = "packer_builds"
username              = "Administrator"
password              = "YourPassword"
domain_name           = "lab.local"
domain_netbios_name   = "LAB"
safe_mode_password    = "YourSafeModePassword"
iso_storage_pool      = "local"
disk_storage_pool     = "local-lvm"
EOF

# Build
packer build .
```

### Building DHCP/DNS Server

```bash
cd dhcp-dns/

# Create variables file
cat > variables.auto.pkrvars.hcl <<EOF
proxmox_host          = "192.168.1.160"
node                  = "skull"
pool                  = "packer_builds"
username              = "Administrator"
password              = "YourPassword"
dns_zone              = "lab.local"
dhcp_scope_name       = "Lab Network"
dhcp_scope_start      = "192.168.1.100"
dhcp_scope_end        = "192.168.1.200"
dhcp_subnet           = "255.255.255.0"
dhcp_gateway          = "192.168.1.1"
disk_storage_pool     = "local-lvm"
EOF

# Build
packer build .
```

### Building Hardened Server

```bash
cd hardened/

# Create variables file
cat > variables.auto.pkrvars.hcl <<EOF
proxmox_host          = "192.168.1.160"
node                  = "skull"
pool                  = "packer_builds"
username              = "Administrator"
password              = "YourPassword"
disk_storage_pool     = "local-lvm"
EOF

# Build
packer build .
```

## 🔧 Configuration

### Required Variables

All builds require these base variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `proxmox_host` | Proxmox host IP or FQDN | - |
| `token_id` | Proxmox API token ID | - |
| `token_secret` | Proxmox API token secret | - |
| `node` | Proxmox node name | - |
| `pool` | Resource pool name | "" |
| `username` | Administrator username | "Administrator" |
| `password` | Administrator password | - |

### Domain Controller Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `domain_name` | AD domain name (FQDN) | "lab.local" |
| `domain_netbios_name` | NetBIOS domain name | "LAB" |
| `safe_mode_password` | DSRM password | - |

### DHCP/DNS Server Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `dns_zone` | DNS zone name | "lab.local" |
| `dhcp_scope_name` | DHCP scope name | "Lab Network" |
| `dhcp_scope_start` | DHCP range start IP | "192.168.1.100" |
| `dhcp_scope_end` | DHCP range end IP | "192.168.1.200" |
| `dhcp_subnet` | Subnet mask | "255.255.255.0" |
| `dhcp_gateway` | Default gateway | "192.168.1.1" |

### Storage Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `iso_storage_pool` | ISO storage pool | "local" |
| `disk_storage_pool` | VM disk storage pool | "local-lvm" |

## 📁 Directory Structure

```
2019/
├── README.md                    # This file
├── base/                        # Base template build
│   ├── build.pkr.hcl           # Build configuration
│   ├── sources.pkr.hcl         # Source definitions
│   ├── variables.pkr.hcl       # Variable declarations
│   ├── variables.auto.pkrvars.hcl  # Auto-loaded values
│   ├── data/                   # Autounattend templates
│   ├── drivers/                # VirtIO drivers
│   └── manifests/              # Build manifests
├── domain-controller/           # Domain Controller build
│   ├── build.pkr.hcl
│   ├── sources.pkr.hcl
│   ├── variables.pkr.hcl
│   ├── data/
│   ├── drivers/
│   └── manifests/
├── dhcp-dns/                    # DHCP/DNS server build
│   ├── build.pkr.hcl
│   ├── sources.pkr.hcl
│   ├── variables.pkr.hcl
│   └── manifests/
├── minimal/                     # Minimal server build
│   ├── build.pkr.hcl
│   ├── sources.pkr.hcl
│   ├── variables.pkr.hcl
│   └── manifests/
└── hardened/                    # Hardened server build
    ├── build.pkr.hcl
    ├── sources.pkr.hcl
    ├── variables.pkr.hcl
    └── manifests/
```

## 🔐 Security Considerations

### Base and Minimal Builds
- Default credentials should be changed immediately after deployment
- Windows Firewall is enabled but permissive
- Suitable for development/lab environments only

### Domain Controller Build
- DSRM password must be complex and securely stored
- DNS forwarders default to public DNS (8.8.8.8, 1.1.1.1)
- Consider implementing additional security policies via GPO

### Hardened Build
- Enforces CIS Benchmark recommendations
- Some applications may require policy adjustments
- Test thoroughly before production use
- TLS 1.0/1.1 disabled may affect legacy applications

### General Recommendations
1. Use complex passwords for all builds
2. Change default credentials immediately after deployment
3. Keep systems updated with latest patches
4. Implement network segmentation
5. Enable and configure Windows Defender
6. Use secure credential storage (Vault, Azure Key Vault, etc.)

## 🛠️ Troubleshooting

### Common Issues

**Build fails at WinRM connection**
- Verify VM has network connectivity
- Check Windows Firewall allows WinRM (port 5985)
- Ensure autounattend.xml properly configured

**Ansible provisioning fails**
- Verify Ansible is installed and in PATH
- Check WinRM is configured for basic auth
- Ensure ansible.windows collection is installed: `ansible-galaxy collection install ansible.windows`

**ISO not found**
- Verify ISO is uploaded to Proxmox storage
- Check `iso_storage_pool` variable matches storage name
- Ensure ISO file path is correct in sources.pkr.hcl

**Driver loading fails during installation**
- Verify VirtIO drivers are in `drivers/` directory
- Check driver catalog (.cat) and INF files are present
- Ensure drivers match Windows Server 2019 version

### Logs and Debugging

Build manifests are stored in `manifests/` with timestamps:
```
manifests/2025-12-06-15-30-45.json
```

Enable Packer debug logging:
```bash
export PACKER_LOG=1
export PACKER_LOG_PATH=packer.log
packer build .
```

Enable Ansible verbose output:
```bash
export PACKER_LOG=1
ANSIBLE_STDOUT_CALLBACK=debug packer build .
```

## 📚 Additional Resources

- [Packer Documentation](https://www.packer.io/docs)
- [Proxmox Packer Builder](https://www.packer.io/plugins/builders/proxmox)
- [Ansible Windows Modules](https://docs.ansible.com/ansible/latest/collections/ansible/windows/)
- [Windows Server 2019 Documentation](https://docs.microsoft.com/en-us/windows-server/)
- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks/)

## 🤝 Contributing

When adding new builds or modifying existing ones:

1. Follow existing naming conventions
2. Document all variables in variables.pkr.hcl
3. Include example variables.auto.pkrvars.hcl
4. Test builds thoroughly before committing
5. Update this README with new build information
6. Include build manifests in .gitignore

## 📝 License

See repository LICENSE file for details.

## 📧 Support

For issues or questions, please open an issue in the repository.
