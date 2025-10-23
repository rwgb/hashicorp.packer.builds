# HashiCorp Packer Builds

<div align="center">

![Packer](https://img.shields.io/badge/Packer-02A8EF?style=for-the-badge&logo=packer&logoColor=white)
![Proxmox](https://img.shields.io/badge/Proxmox-E57000?style=for-the-badge&logo=proxmox&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?style=for-the-badge&logo=github-actions&logoColor=white)

**Automated VM image builds for Proxmox using HashiCorp Packer**

[Features](#-features) • [Quick Start](#-quick-start) • [Builds](#-available-builds) • [CI/CD](#-cicd-automation) • [Documentation](#-documentation)

</div>

---

## 📋 Overview

This repository contains **HashiCorp Packer** configurations for building virtual machine images on **Proxmox VE**. All builds are automated using **GitHub Actions** with support for both manual and scheduled builds.

### Supported Operating Systems

| OS | Version | Status | Build Path |
|---|---|---|---|
| **Debian** | 12 (Bookworm) | ✅ | `builds/linux/debian/12/` |
| **Debian** | 13 (Trixie) | ✅ | `builds/linux/debian/13/` |
| **Windows Server** | 2019 | ✅ | `builds/windows/server/2019/` |
| **Windows Server** | 2022 | ✅ | `builds/windows/server/2022/` |

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
- **Path**: `builds/linux/debian/12/`
- **ISO**: Debian 12 netinstall
- **Features**: Minimal base, cloud-init ready, SSH hardened

#### Debian 13 (Trixie)
- **Path**: `builds/linux/debian/13/`
- **ISO**: Debian 13 netinstall
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
hashicorp.packer/
├── .github/
│   └── workflows/
│       ├── build-all.yml          # Build all images workflow
│       ├── build-debian-13.yml    # Debian 13 specific workflow
│       └── README.md              # Workflow documentation
├── builds/
│   ├── linux/
│   │   └── debian/
│   │       ├── 12/
│   │       │   ├── build.pkr.hcl          # Build configuration
│   │       │   ├── sources.pkr.hcl        # Source definitions
│   │       │   ├── variables.pkr.hcl      # Variable definitions
│   │       │   ├── data/                  # Templates (kickstart, etc.)
│   │       │   └── manifests/             # Build output manifests
│   │       └── 13/
│   │           ├── build.pkr.hcl
│   │           ├── sources.pkr.hcl
│   │           ├── variables.pkr.hcl
│   │           ├── data/
│   │           └── manifests/
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
├── .gitignore
├── .actrc                         # Act (local testing) configuration
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
