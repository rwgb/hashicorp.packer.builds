# HashiCorp Packer Builds

<div align="center">

![Packer](https://img.shields.io/badge/Packer-02A8EF?style=for-the-badge&logo=packer&logoColor=white)
![Proxmox](https://img.shields.io/badge/Proxmox-E57000?style=for-the-badge&logo=proxmox&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-FF9900?style=for-the-badge&logo=amazon-aws&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?style=for-the-badge&logo=github-actions&logoColor=white)
![Version](https://img.shields.io/badge/version-0.1.4-blue?style=for-the-badge)

**Multi-cloud VM and AMI builds using HashiCorp Packer**

[Features](#-features) • [Quick Start](#-quick-start) • [Builds](#-available-builds) • [CI/CD](#-cicd-automation) • [Documentation](#-documentation)

</div>

---

## 📋 Overview

This repository contains **HashiCorp Packer** configurations for building virtual machine images and AMIs across multiple cloud providers. All builds are automated using **GitHub Actions** with support for both manual and scheduled builds.

### Supported Platforms

**Proxmox VE** - Virtual Machine Templates
**AWS** - Amazon Machine Images (AMIs)

### Supported Operating Systems

#### Proxmox Builds
| OS | Version | Status | Build Path |
|---|---|---|---|
| **Debian** | 12 (Bookworm) | ✅ | `builds/proxmox/linux/debian/12/` |
| **Debian** | 13 (Trixie) | ✅ | `builds/proxmox/linux/debian/13/` |
| **Windows Server** | 2019 | ✅ | `builds/proxmox/windows/server/2019/` |
| **Windows Server** | 2022 | ✅ | `builds/proxmox/windows/server/2022/` |

#### AWS AMI Builds
| OS | Version | Status | Build Path |
|---|---|---|---|
| **Debian** | 11 (Bullseye) | ✅ | `builds/aws/linux/debian/11/` |
| **Debian** | 12 (Bookworm) | ✅ | `builds/aws/linux/debian/12/` |
| **Ubuntu** | 22.04 LTS (Jammy) | ✅ | `builds/aws/linux/ubuntu/22/` |
| **Ubuntu** | 24.04 LTS (Noble) | ✅ | `builds/aws/linux/ubuntu/24/` |
| **Windows Server** | 2019 | ✅ | `builds/aws/windows/server/2019/` |
| **Windows Server** | 2022 | ✅ | `builds/aws/windows/server/2022/` |
| **Windows Desktop** | 10 | ✅ | `builds/aws/windows/desktop/10/` |
| **Windows Desktop** | 11 | ✅ | `builds/aws/windows/desktop/11/` |

---

## ✨ Features

- 🤖 **Automated Builds**: GitHub Actions workflows for CI/CD
- 🔄 **Matrix Builds**: Parallel execution of multiple builds
- 📦 **Artifact Management**: Automatic manifest and log uploads
- 🔐 **Secure**: GitHub Secrets integration for credentials
- 🎯 **Selective Builds**: Choose specific images or build all
- 📅 **Scheduled Builds**: Monthly automated rebuilds
- 🐛 **Validation**: Pre-build validation with `packer validate`
- 📊 **Build Summaries**: Detailed execution reports

---

## 🚀 Quick Start

### Prerequisites

- **Proxmox VE** server (7.x or later)
- **Packer** (1.9.x or later)
- **GitHub** repository with secrets configured
- **Git** for version control

### Local Development

```bash
# Clone the repository
git clone https://github.com/rwgb/hashicorp.packer.builds.git
cd hashicorp.packer.builds

# Navigate to a build directory
cd builds/linux/debian/13

# Initialize Packer
packer init .

# Validate the configuration
packer validate \
  -var="proxmox_host=your-proxmox-host" \
  -var="token_id=your-token-id" \
  -var="token_secret=your-token-secret" \
  -var="node=your-node" \
  -var="pool=your-pool" \
  -var="username=build-user" \
  -var="password=build-password" \
  -var="build_key=your-ssh-key" \
  .

# Build the image
packer build \
  -var="proxmox_host=your-proxmox-host" \
  -var="token_id=your-token-id" \
  -var="token_secret=your-token-secret" \
  -var="node=your-node" \
  -var="pool=your-pool" \
  -var="username=build-user" \
  -var="password=build-password" \
  -var="build_key=your-ssh-key" \
  .
```

### Using Variable Files (Recommended)

Create a `local.auto.pkrvars.hcl` file:

```hcl
proxmox_host = "proxmox.example.com"
token_id     = "build@pve!packer"
token_secret = "your-secret-token"
node         = "pve-node1"
pool         = "production"
username     = "ansible"
password     = "secure-password"
build_key    = "ssh-rsa AAAAB3..."
```

Then build with:

```bash
packer build .
```

---

## 🏗️ Available Builds

### Linux Builds

#### Debian 12 (Bookworm)

Debian 12 builds use a **three-tier approach**:

1. **Base Build** (`builds/proxmox/linux/debian/12/base/`)
   - **VM ID**: 9000
   - **Builder**: `proxmox-iso` (builds from ISO)
   - **ISO**: Debian 12.9.0 netinstall
   - **Features**: Minimal base, cloud-init ready, SSH hardened
   - **Purpose**: Foundation template for all variant clones

2. **Hardened Variants** (`builds/proxmox/linux/debian/12/hardened/`)
   - **Builder**: `proxmox-clone` (clones from base VM 9000)
   - **Provisioning**: Ansible playbooks with security-focused configurations
   - **Available Roles**:
     - **Apache** (VM 9001): ModSecurity WAF, fail2ban, SSL hardening
     - **Docker** (VM 9002): Docker Engine, secure daemon config, user namespaces
     - **MySQL** (VM 9003): MySQL Server, authentication plugins, audit logging
     - **Tomcat** (VM 9004): Tomcat 10, JMX monitoring, security manager

3. **Minimal Variants** (`builds/proxmox/linux/debian/12/minimal/`)
   - **Builder**: `proxmox-clone` (clones from base VM 9000)
   - **Provisioning**: Ansible playbooks with lightweight configurations
   - **Available Roles**:
     - **Apache** (VM 9005): Apache2 with minimal modules, optimized performance
     - **Docker** (VM 9006): Docker Engine, essential tools only
     - **MySQL** (VM 9007): MySQL Server, minimal plugins, performance tuning
     - **Tomcat** (VM 9008): Tomcat 10, lightweight deployment

**Build Workflow**:
```bash
# 1. Build the base template
cd builds/proxmox/linux/debian/12/base/
packer build .

# 2. Build hardened variants (clones from VM 9000)
cd ../hardened/
packer build -only='proxmox-clone.debian12-hardened-apache' .
packer build -only='proxmox-clone.debian12-hardened-docker' .
packer build -only='proxmox-clone.debian12-hardened-mysql' .
packer build -only='proxmox-clone.debian12-hardened-tomcat' .

# 3. Build minimal variants (clones from VM 9000)
cd ../minimal/
packer build -only='proxmox-clone.debian12-minimal-apache' .
packer build -only='proxmox-clone.debian12-minimal-docker' .
packer build -only='proxmox-clone.debian12-minimal-mysql' .
packer build -only='proxmox-clone.debian12-minimal-tomcat' .
```

#### Debian 13 (Trixie)
- **Path**: `builds/proxmox/linux/debian/13/`
- **VM ID**: 9001
- **Builder**: `proxmox-iso`
- **ISO**: Debian 13.1.0 netinstall
- **Features**: Latest packages, modern kernel, optimized for containers

### Windows Builds

#### Windows Server 2019
- **Path**: `builds/windows/server/2019/`
- **ISO**: Windows Server 2019 Standard
- **Features**: Sysprep configured, VirtIO drivers, optimized

#### Windows Server 2022
- **Path**: `builds/windows/server/2022/`
- **ISO**: Windows Server 2022 Standard
- **Features**: Latest Windows Server, enhanced security, VirtIO drivers

---

## 🔧 Configuration

### Required Variables

All builds require the following variables:

| Variable | Type | Description | Example |
|----------|------|-------------|---------|
| `proxmox_host` | string | Proxmox server hostname/IP | `proxmox.example.com` |
| `token_id` | string | API token ID | `build@pve!packer` |
| `token_secret` | string | API token secret | `xxxxxxxx-xxxx-xxxx...` |
| `node` | string | Proxmox node name | `pve-node1` |
| `pool` | string | Resource pool | `production` |
| `username` | string | Build user username | `ansible` |
| `password` | string | Build user password | `secure-password` |
| `build_key` | string | SSH public key | `ssh-rsa AAAAB3...` |

### Optional Variables

Check each build's `variables.pkr.hcl` for additional options like:
- Guest OS language/keyboard/timezone
- Additional packages to install
- Network configuration
- Storage settings

---

## 🔄 CI/CD Automation

### GitHub Actions Workflows

This repository includes automated workflows for building images:

#### Build All Images
**File**: `.github/workflows/build-all.yml`

```bash
# Manual trigger (specific build)
gh workflow run build-all.yml -f build_target=debian-13

# Manual trigger (all builds)
gh workflow run build-all.yml -f build_target=all
```

**Triggers**:
- Manual dispatch with build selection
- Push to `main` or `develop` branches
- Monthly schedule (1st of month, 2AM UTC)

#### Build Debian 13
**File**: `.github/workflows/build-debian-13.yml`

**Triggers**:
- Manual dispatch
- Push to `build/debian13` branch
- Changes to `builds/linux/debian/13/**`

### Setting Up GitHub Secrets

Configure these secrets in your repository:

```bash
# Via GitHub CLI
gh secret set PROXMOX_HOST
gh secret set TOKEN_ID
gh secret set TOKEN_SECRET
gh secret set NODE
gh secret set POOL
gh secret set USERNAME
gh secret set PASSWORD
gh secret set BUILD_KEY

# Or via GitHub UI:
# Settings → Secrets and variables → Actions → New repository secret
```

### Self-Hosted Runner

The workflows use a self-hosted GitHub Actions runner that:
- Has network access to Proxmox VE
- Has Packer installed
- Has sufficient resources for builds
- Is labeled as `self-hosted`

**Setup instructions**: See [GitHub's self-hosted runner documentation](https://docs.github.com/en/actions/hosting-your-own-runners)

---

## 📁 Repository Structure

```
hashicorp.packer.builds/
├── .github/
│   ├── copilot-instructions.md    # GitHub Copilot configuration
│   └── workflows/
│       ├── build-all.yml          # Build all images workflow
│       ├── test-debian12-build.yml # Debian 12 base build test
│       └── README.md              # Workflow documentation
├── builds/
│   ├── proxmox/
│   │   ├── ansible/
│   │   │   ├── hardened-apache.yml      # Security-focused Apache config
│   │   │   ├── hardened-docker.yml      # Hardened Docker setup
│   │   │   ├── hardened-mysql.yml       # MySQL with security plugins
│   │   │   ├── hardened-tomcat.yml      # Tomcat with security manager
│   │   │   ├── minimal-apache.yml       # Lightweight Apache
│   │   │   ├── minimal-docker.yml       # Minimal Docker installation
│   │   │   ├── minimal-mysql.yml        # Performance-tuned MySQL
│   │   │   ├── minimal-tomcat.yml       # Lightweight Tomcat
│   │   │   └── README.md                # Ansible documentation
│   │   └── linux/
│   │       └── debian/
│   │           ├── 12/
│   │           │   ├── base/
│   │           │   │   ├── build.pkr.hcl          # Base build config
│   │           │   │   ├── sources.pkr.hcl        # proxmox-iso source
│   │           │   │   ├── variables.pkr.hcl      # Base variables
│   │           │   │   ├── data/                  # Preseed templates
│   │           │   │   └── manifests/             # Build manifests (VM 9000)
│   │           │   ├── hardened/
│   │           │   │   ├── build.pkr.hcl          # All hardened builds
│   │           │   │   ├── sources-apache.pkr.hcl # VM 9001 source
│   │           │   │   ├── sources-docker.pkr.hcl # VM 9002 source
│   │           │   │   ├── sources-mysql.pkr.hcl  # VM 9003 source
│   │           │   │   ├── sources-tomcat.pkr.hcl # VM 9004 source
│   │           │   │   ├── variables-apache.pkr.hcl
│   │           │   │   ├── variables-docker.pkr.hcl
│   │           │   │   ├── variables-mysql.pkr.hcl
│   │           │   │   └── variables-tomcat.pkr.hcl
│   │           │   └── minimal/
│   │           │       ├── build.pkr.hcl          # All minimal builds
│   │           │       ├── sources-apache.pkr.hcl # VM 9005 source
│   │           │       ├── sources-docker.pkr.hcl # VM 9006 source
│   │           │       ├── sources-mysql.pkr.hcl  # VM 9007 source
│   │           │       ├── sources-tomcat.pkr.hcl # VM 9008 source
│   │           │       ├── variables-apache.pkr.hcl
│   │           │       ├── variables-docker.pkr.hcl
│   │           │       ├── variables-mysql.pkr.hcl
│   │           │       └── variables-tomcat.pkr.hcl
│   │           └── 13/
│   │               ├── build.pkr.hcl
│   │               ├── sources.pkr.hcl
│   │               ├── variables.pkr.hcl
│   │               ├── data/
│   │               └── manifests/
│   └── windows/
│       └── server/
│           ├── 2019/
│           │   ├── build.pkr.hcl
│           │   ├── sources.pkr.hcl
│           │   ├── variables.pkr.hcl
│           │   ├── data/                  # Autounattend.xml
│           │   ├── drivers/               # VirtIO drivers
│           │   └── manifests/
│           └── 2022/
│               ├── build.pkr.hcl
│               ├── sources.pkr.hcl
│               ├── variables.pkr.hcl
│               ├── data/
│               ├── drivers/
│               └── manifests/
├── scripts/
│   ├── buildManager.py            # Build orchestration tool
│   ├── EXAMPLES.md                # Usage examples
│   └── README.md                  # Scripts documentation
├── .gitignore
├── .actrc                         # Act (local testing) configuration
├── CHANGELOG.md
├── CONTRIBUTING.md
├── LICENSE
├── VERSION
└── README.md                      # This file
```

---

## 🧪 Local Testing

### Using `nektos/act`

Test GitHub Actions workflows locally:

```bash
# Install act
brew install act  # macOS
# or
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# List available workflows
act -l

# Test build-all workflow (dry run)
act workflow_dispatch -W .github/workflows/build-all.yml -n

# Run with secrets file
act workflow_dispatch --secret-file .secrets
```

Create a `.secrets` file (don't commit this!):
```bash
PROXMOX_HOST=proxmox.local
TOKEN_ID=build@pve!packer
TOKEN_SECRET=your-secret
NODE=pve
POOL=dev
USERNAME=ansible
PASSWORD=password
BUILD_KEY=ssh-rsa...
```

### Validating Configurations

```bash
# Validate all builds
for dir in builds/*/*/*/*/; do
  echo "Validating: $dir"
  cd "$dir"
  packer init .
  packer validate .
  cd -
done
```

---

## 🔧 Ansible Provisioning

The hardened and minimal variants use Ansible for automated configuration:

### Playbook Structure

All playbooks are located in `builds/proxmox/ansible/`:

| Playbook | Purpose | Key Components |
|----------|---------|----------------|
| `hardened-apache.yml` | Security-focused Apache | ModSecurity WAF, fail2ban, SSL hardening |
| `hardened-docker.yml` | Hardened Docker setup | Secure daemon config, user namespaces, audit logging |
| `hardened-mysql.yml` | MySQL with security | Authentication plugins, audit logging, encrypted connections |
| `hardened-tomcat.yml` | Tomcat with security | Security manager, JMX monitoring, encrypted configs |
| `minimal-apache.yml` | Lightweight Apache | Essential modules only, optimized performance |
| `minimal-docker.yml` | Minimal Docker | Docker Engine, essential tools, lightweight |
| `minimal-mysql.yml` | Performance-tuned MySQL | Minimal plugins, InnoDB optimization, query cache |
| `minimal-tomcat.yml` | Lightweight Tomcat | Essential webapps, memory-optimized JVM |

### Provisioning Workflow

1. **Base Build**: Creates foundation template (VM 9000) using `proxmox-iso` builder
2. **Clone**: Packer uses `proxmox-clone` builder to clone base template
3. **Provision**: Ansible playbook runs inside cloned VM to configure role
4. **Finalize**: VM is converted to template with role-specific configuration

### VM ID Assignments

| VM ID | Type | Role | Description |
|-------|------|------|-------------|
| 9000 | Base | Foundation | Minimal Debian 12 base template |
| 9001 | Hardened | Apache | ModSecurity, fail2ban, SSL |
| 9002 | Hardened | Docker | Secure daemon, user namespaces |
| 9003 | Hardened | MySQL | Authentication, audit, encryption |
| 9004 | Hardened | Tomcat | Security manager, JMX |
| 9005 | Minimal | Apache | Lightweight, performance-focused |
| 9006 | Minimal | Docker | Essential Docker only |
| 9007 | Minimal | MySQL | Performance-tuned |
| 9008 | Minimal | Tomcat | Memory-optimized |

### Extending with New Roles

To add a new role (e.g., PostgreSQL):

1. Create Ansible playbooks:
   ```bash
   # Hardened variant
   builds/proxmox/ansible/hardened-postgresql.yml
   
   # Minimal variant
   builds/proxmox/ansible/minimal-postgresql.yml
   ```

2. Create Packer sources:
   ```bash
   # Hardened
   builds/proxmox/linux/debian/12/hardened/sources-postgresql.pkr.hcl
   builds/proxmox/linux/debian/12/hardened/variables-postgresql.pkr.hcl
   
   # Minimal
   builds/proxmox/linux/debian/12/minimal/sources-postgresql.pkr.hcl
   builds/proxmox/linux/debian/12/minimal/variables-postgresql.pkr.hcl
   ```

3. Add build blocks to `build.pkr.hcl` in hardened/ and minimal/ directories

4. Assign VM IDs (next available: 9009 for hardened, 9010 for minimal)

---

## 🔧 Ansible Provisioning

The hardened and minimal variants use Ansible for automated configuration:

### Playbook Structure

All playbooks are located in `builds/proxmox/ansible/`:

| Playbook | Purpose | Key Components |
|----------|---------|----------------|
| `hardened-apache.yml` | Security-focused Apache | ModSecurity WAF, fail2ban, SSL hardening |
| `hardened-docker.yml` | Hardened Docker setup | Secure daemon config, user namespaces, audit logging |
| `hardened-mysql.yml` | MySQL with security | Authentication plugins, audit logging, encrypted connections |
| `hardened-tomcat.yml` | Tomcat with security | Security manager, JMX monitoring, encrypted configs |
| `minimal-apache.yml` | Lightweight Apache | Essential modules only, optimized performance |
| `minimal-docker.yml` | Minimal Docker | Docker Engine, essential tools, lightweight |
| `minimal-mysql.yml` | Performance-tuned MySQL | Minimal plugins, InnoDB optimization, query cache |
| `minimal-tomcat.yml` | Lightweight Tomcat | Essential webapps, memory-optimized JVM |

### Provisioning Workflow

1. **Base Build**: Creates foundation template (VM 9000) using `proxmox-iso` builder
2. **Clone**: Packer uses `proxmox-clone` builder to clone base template
3. **Provision**: Ansible playbook runs inside cloned VM to configure role
4. **Finalize**: VM is converted to template with role-specific configuration

### VM ID Assignments

| VM ID | Type | Role | Description |
|-------|------|------|-------------|
| 9000 | Base | Foundation | Minimal Debian 12 base template |
| 9001 | Hardened | Apache | ModSecurity, fail2ban, SSL |
| 9002 | Hardened | Docker | Secure daemon, user namespaces |
| 9003 | Hardened | MySQL | Authentication, audit, encryption |
| 9004 | Hardened | Tomcat | Security manager, JMX |
| 9005 | Minimal | Apache | Lightweight, performance-focused |
| 9006 | Minimal | Docker | Essential Docker only |
| 9007 | Minimal | MySQL | Performance-tuned |
| 9008 | Minimal | Tomcat | Memory-optimized |

### Extending with New Roles

To add a new role (e.g., PostgreSQL):

1. Create Ansible playbooks:
   ```bash
   # Hardened variant
   builds/proxmox/ansible/hardened-postgresql.yml
   
   # Minimal variant
   builds/proxmox/ansible/minimal-postgresql.yml
   ```

2. Create Packer sources:
   ```bash
   # Hardened
   builds/proxmox/linux/debian/12/hardened/sources-postgresql.pkr.hcl
   builds/proxmox/linux/debian/12/hardened/variables-postgresql.pkr.hcl
   
   # Minimal
   builds/proxmox/linux/debian/12/minimal/sources-postgresql.pkr.hcl
   builds/proxmox/linux/debian/12/minimal/variables-postgresql.pkr.hcl
   ```

3. Add build blocks to `build.pkr.hcl` in hardened/ and minimal/ directories

4. Assign VM IDs (next available: 9009 for hardened, 9010 for minimal)

---

## 📖 Documentation

### Packer Files Explained

#### `build.pkr.hcl`
Defines the build process:
- Packer plugins required
- Local variables and data sources
- Build steps and post-processors
- Manifest generation

#### `sources.pkr.hcl`
Defines the source configuration:
- Proxmox connection details
- VM hardware specifications
- ISO and boot configuration
- Provisioning settings

#### `variables.pkr.hcl`
Defines input variables:
- Required variables (no defaults)
- Optional variables (with defaults)
- Sensitive variables
- Validation rules

#### `data/` directory
Contains template files:
- **Linux**: Kickstart files (`ks.pkrtpl.hcl`)
- **Linux**: Cloud-init configs (`user-data.pkrtpl.hcl`, `meta-data.pkrtpl.hcl`)
- **Windows**: Autounattend.xml (`autounattend.pkrtpl.hcl`)

#### `manifests/` directory
Generated build artifacts:
- JSON manifest files with build metadata
- Includes VM ID, timestamps, git commit info
- Used for tracking and auditing

---

## 🔍 Troubleshooting

### Common Issues

#### Build fails with "repository does not exist"
**Solution**: The git-commit datasource needs the full repository. This is fixed with:
- `fetch-depth: 0` in GitHub Actions checkout
- Explicit `path` parameter in git-commit datasource

#### Proxmox connection fails
**Solution**: Check:
- Proxmox host is reachable from runner
- API token has correct permissions
- TLS certificate validation settings

#### Build timeouts
**Solution**: Increase timeout in Packer configuration or adjust VM resources

#### ISO download fails
**Solution**: Verify ISO URLs are accessible and up-to-date

### Debug Mode

Enable Packer debug logging:

```bash
export PACKER_LOG=1
export PACKER_LOG_PATH=packer-debug.log
packer build .
```

Or in GitHub Actions (already configured):
```yaml
env:
  PACKER_LOG: "1"
  PACKER_LOG_PATH: "packer-build.log"
```

---

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Adding New Builds

1. Create directory structure: `builds/<os>/<distro>/<version>/`
2. Add Packer configuration files
3. Update `.github/workflows/build-all.yml` matrix
4. Test locally with `packer validate` and `packer build`
5. Submit PR

---

## 📜 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

## 🔗 Links

- [HashiCorp Packer Documentation](https://developer.hashicorp.com/packer/docs)
- [Packer Proxmox Builder](https://developer.hashicorp.com/packer/plugins/builders/proxmox/iso)
- [Proxmox VE Documentation](https://pve.proxmox.com/pve-docs/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

---

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/rwgb/hashicorp.packer.builds/issues)
- **Discussions**: [GitHub Discussions](https://github.com/rwgb/hashicorp.packer.builds/discussions)

---

<div align="center">

**Built with ❤️ using HashiCorp Packer**

[![Packer](https://img.shields.io/badge/Packer-1.9.x-02A8EF?style=flat-square&logo=packer)](https://www.packer.io/)
[![Proxmox](https://img.shields.io/badge/Proxmox-VE_7.x-E57000?style=flat-square&logo=proxmox)](https://www.proxmox.com/)

</div>
