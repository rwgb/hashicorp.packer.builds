# Contributing to HashiCorp Packer Builds

Thank you for your interest in contributing! This guide will help you get started.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
- [Development Workflow](#development-workflow)
- [Adding New Builds](#adding-new-builds)
- [Testing](#testing)
- [Style Guide](#style-guide)
- [Commit Messages](#commit-messages)
- [Pull Request Process](#pull-request-process)

---

## Code of Conduct

This project adheres to a code of conduct. By participating, you are expected to:
- Be respectful and inclusive
- Accept constructive criticism
- Focus on what is best for the community
- Show empathy towards other community members

---

## Getting Started

### Prerequisites

- Git
- HashiCorp Packer (1.9.x or later)
- Access to a Proxmox VE server for testing
- Basic knowledge of HCL (HashiCorp Configuration Language)

### Setting Up Your Development Environment

```bash
# Fork and clone the repository
git clone https://github.com/YOUR-USERNAME/hashicorp.packer.builds.git
cd hashicorp.packer.builds

# Add upstream remote
git remote add upstream https://github.com/rwgb/hashicorp.packer.builds.git

# Create a branch for your work
git checkout -b feature/your-feature-name
```

---

## How to Contribute

### Reporting Bugs

If you find a bug, please create an issue with:
- **Clear title**: Describe the issue concisely
- **Description**: Detailed description of the problem
- **Steps to reproduce**: List exact steps
- **Expected behavior**: What should happen
- **Actual behavior**: What actually happens
- **Environment**: OS, Packer version, Proxmox version
- **Logs**: Relevant error messages or logs

### Suggesting Enhancements

For feature requests or enhancements:
- Check existing issues to avoid duplicates
- Provide clear use case and benefits
- Include examples if possible
- Be open to discussion and feedback

### Documentation Improvements

Documentation contributions are highly valued:
- Fix typos or unclear explanations
- Add examples
- Improve formatting
- Update outdated information

---

## Development Workflow

### 1. Create a Feature Branch

```bash
# Start from main branch
git checkout main
git pull upstream main

# Create your feature branch
git checkout -b feature/amazing-feature
```

### 2. Make Your Changes

- Write clean, readable code
- Follow existing patterns and conventions
- Add comments where necessary
- Update documentation as needed

### 3. Test Your Changes

```bash
# Navigate to the build directory
cd builds/path/to/build

# Initialize Packer
packer init .

# Validate configuration
packer validate \
  -var-file="test.auto.pkrvars.hcl" \
  .

# Test build (if possible)
packer build \
  -var-file="test.auto.pkrvars.hcl" \
  .
```

### 4. Commit Your Changes

```bash
git add .
git commit -m "feat: add amazing feature"
```

### 5. Push and Create Pull Request

```bash
git push origin feature/amazing-feature
```

Then create a pull request on GitHub.

---

## Adding New Builds

### Directory Structure

Create the following structure for new builds:

```
builds/<os>/<distro>/<version>/
├── build.pkr.hcl           # Build configuration
├── sources.pkr.hcl         # Source definitions
├── variables.pkr.hcl       # Variable definitions
├── variables.auto.pkrvars.hcl  # Default values (optional)
├── data/                   # Template files
│   ├── ks.pkrtpl.hcl      # Kickstart (Linux)
│   ├── user-data.pkrtpl.hcl   # Cloud-init
│   └── autounattend.pkrtpl.hcl  # Windows answer file
└── manifests/              # Build output (auto-generated)
```

### Required Files

#### `variables.pkr.hcl`
Define all required and optional variables:

```hcl
variable "proxmox_host" {
  type        = string
  description = "Proxmox server hostname or IP"
}

variable "custom_option" {
  type        = string
  description = "Your custom option"
  default     = "default-value"
}
```

#### `sources.pkr.hcl`
Define the Proxmox source:

```hcl
source "proxmox-iso" "example" {
  proxmox_url              = "https://${var.proxmox_host}:8006/api2/json"
  username                 = "${var.token_id}"
  token                    = var.token_secret
  node                     = var.node
  # ... more configuration
}
```

#### `build.pkr.hcl`
Define plugins, locals, and build process:

```hcl
packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.3"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

build {
  name = "example-build"
  sources = ["source.proxmox-iso.example"]
  
  # Provisioners, post-processors, etc.
}
```

### Update Workflows

Add your build to `.github/workflows/build-all.yml`:

```yaml
ALL_BUILDS='[
  ...
  {"name": "new-build", "path": "builds/os/distro/version", "os": "os", "log": "packer-new.log"}
]'
```

---

## Testing

### Local Testing

```bash
# Validate syntax
packer fmt -check .
packer validate .

# Test with specific variable file
packer build -var-file="test.auto.pkrvars.hcl" .
```

### Testing Workflows Locally

Use `nektos/act` to test GitHub Actions:

```bash
# Install act
brew install act  # macOS

# Test workflow
act workflow_dispatch -W .github/workflows/build-all.yml -n

# Test with secrets
act workflow_dispatch --secret-file .secrets
```

---

## Style Guide

### HCL Formatting

- Use `packer fmt` to format files
- 2-space indentation
- Meaningful variable names
- Add descriptions to all variables
- Group related settings together

### Comments

```hcl
// Single line comment for brief explanations

/*
 * Multi-line comment for
 * longer explanations
 */

variable "example" {
  type        = string
  description = "Clear description of purpose"  # Inline comment if needed
}
```

### File Organization

1. Packer required_plugins block
2. Data sources
3. Locals
4. Sources
5. Build blocks
6. Post-processors

---

## Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

### Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Formatting, missing semicolons, etc.
- `refactor`: Code restructuring
- `test`: Adding tests
- `chore`: Maintenance tasks

### Examples

```bash
feat(debian13): add cloud-init support

Add cloud-init configuration to Debian 13 build for automated
provisioning in cloud environments.

Closes #42

---

fix(windows2022): correct VirtIO driver path

The driver path was incorrect, causing installation failures.
Updated to use the correct path from the VirtIO ISO.

---

docs(readme): update quick start guide

Added more detailed examples for local development setup
and improved variable file documentation.
```

---

## Pull Request Process

### Before Submitting

- [ ] Code follows style guidelines
- [ ] All tests pass locally
- [ ] Documentation is updated
- [ ] Commit messages follow conventions
- [ ] No merge conflicts with main branch
- [ ] Self-review completed

### PR Template

When creating a PR, include:

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Refactoring

## Testing
How was this tested?

## Checklist
- [ ] Packer validate passes
- [ ] Documentation updated
- [ ] Follows style guide
- [ ] Tested locally

## Screenshots (if applicable)
Add screenshots or logs
```

### Review Process

1. Automated checks will run (linting, validation)
2. At least one maintainer will review
3. Address any requested changes
4. Once approved, a maintainer will merge

### After Merge

- Your branch will be deleted
- Close any related issues
- Update your fork:

```bash
git checkout main
git pull upstream main
git push origin main
```

---

## Questions?

- Open a [Discussion](https://github.com/rwgb/hashicorp.packer.builds/discussions)
- Contact maintainers
- Check existing issues and PRs

---

**Thank you for contributing! 🎉**
