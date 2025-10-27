# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.4] - 2025-10-27

### Added
- **AWS Support**: Complete boilerplate Packer configurations for AWS AMI builds
  - Linux builds: Debian 11/12, Ubuntu 22.04/24.04
  - Windows builds: Server 2019/2022, Desktop 10/11
  - Each build includes variables.pkr.hcl, sources.pkr.hcl, build.pkr.hcl
  - Windows builds include userdata.ps1 for WinRM enablement
- **Build Manager**: Comprehensive Python build automation tool (`buildManager.py`)
  - Auto-discovery of all Packer builds
  - Interactive and CLI modes
  - Source selection for multi-source builds
  - Variable file support
  - Init, validate, and build operations
- **Documentation**: 
  - Comprehensive `EXAMPLES.md` with AWS and Proxmox examples
  - `example.pkrvars.hcl` demonstrating all AWS configuration options
  - GitHub Actions workflows for CI/CD
  - Shell script automation examples
- **AWS Features**:
  - EBS encryption support with optional KMS keys
  - Multi-region AMI copying
  - Cross-account AMI sharing
  - SSM and CloudWatch agents pre-installed
  - Automated Windows Updates (excluding Preview builds)
  - Chocolatey package manager on Windows
  - Proper cleanup and Sysprep for Windows AMIs
  - Manifest generation with git commit tracking

### Changed
- **Repository Structure**: Reorganized to support multi-cloud providers
  - Changed from `builds/{os_type}/` to `builds/{provider}/{os_type}/`
  - Enables support for AWS, Proxmox, Azure, etc.
- **Manifest Filenames**: Updated timestamp format for cross-platform compatibility
  - Changed from `YYYY-MM-DD hh:mm:ss.json` to `YYYY-MM-DD-hh-mm-ss.json`
  - Fixes GitHub Actions artifact upload on Windows runners
- **Git Datasource Paths**: Updated all build.pkr.hcl files after repository reorganization
  - Changed from `${path.root}/../../../` to `${path.root}/../../../../`

### Fixed
- GitHub Actions artifact upload failures on Windows (invalid filename characters)
- Removed unsupported `vm_notes` argument from Proxmox sources

## [0.1.3] - Previous Release
- Initial Proxmox-only configurations
- Debian 11/12/13 builds
- Windows Server 2019/2022 builds
- Basic GitHub Actions workflows

---

## Release Notes

### Version 0.1.4 Highlights

This release marks a significant expansion of the project with **multi-cloud support** and comprehensive **automation tooling**. The addition of AWS AMI builds alongside existing Proxmox configurations makes this a true multi-cloud Packer automation repository.

**Key Achievements:**
- 🌩️ **7 new AWS AMI configurations** (4 Linux, 3 Windows)
- 🤖 **Build Manager tool** for easy automation
- 📚 **Enhanced documentation** with 40+ examples
- 🔒 **Security features**: encryption, KMS, cross-account sharing
- 🏗️ **Improved architecture**: multi-provider structure

**Migration Guide:**
If updating from 0.1.3, note the repository structure change:
- Old: `builds/linux/debian/12/`
- New: `builds/proxmox/linux/debian/12/`
- AWS builds: `builds/aws/linux/debian/11/`

Update any scripts or workflows referencing the old paths.

**Next Steps:**
- Azure support (planned for 0.2.0)
- Google Cloud Platform support (planned for 0.2.0)
- Terraform modules for deployment (planned for 0.3.0)
