# Build Manager Examples

Real-world examples for using `buildManager.py` in various scenarios.

## Quick Start

### 1. First Time Setup

```bash
# List all available builds
./scripts/buildManager.py --list

# Initialize a build (downloads Packer plugins)
./scripts/buildManager.py --os debian-12 --init-only
```

### 2. Simple Build

```bash
# Build Debian 12 using default variables
./scripts/buildManager.py --os debian-12
```

## Common Workflows

### Development Workflow

```bash
# 1. Validate configuration
./scripts/buildManager.py --os debian-13 --validate-only

# 2. If validation passes, build
./scripts/buildManager.py --os debian-13
```

### AWS Builds

Build AMIs for AWS using the same workflow:

```bash
# List all AWS builds
./scripts/buildManager.py --list | grep -A 3 "AWS"

# Build Debian 11 AMI
./scripts/buildManager.py --os debian-11-aws

# Build Ubuntu 22.04 AMI
./scripts/buildManager.py --os ubuntu-22-aws

# Build Windows Server 2022 AMI
./scripts/buildManager.py --os windows-server-2022-aws
```

### Testing Configuration Changes

```bash
# Dry run to see what would be executed
./scripts/buildManager.py --os debian-12 --dry-run

# Validate with custom variables
./scripts/buildManager.py --os debian-12 \
    --vars ./test-vars.auto.pkrvars.hcl \
    --validate-only
```

### Multi-Source Builds

Windows Server builds have both ISO and clone sources:

```bash
# List sources for a build
./scripts/buildManager.py --list | grep -A 3 "windows_server"

# Build from ISO (fresh install)
./scripts/buildManager.py --source proxmox-iso.windows_server_2k22_data_center_base

# Build from clone (faster, uses existing template)
./scripts/buildManager.py --source proxmox-clone.windows_server_2k22_data_center_base
```

## Advanced Usage

### Custom Variables

#### Proxmox Builds

```bash
# Create custom variables file
cat > custom-build.auto.pkrvars.hcl <<EOF
proxmox_host = "pve.custom.local"
node         = "pve-node2"
pool         = "TestPool"
EOF

# Build with custom variables
./scripts/buildManager.py --os debian-12 \
    --vars ./custom-build.auto.pkrvars.hcl
```

#### AWS Builds

```bash
# Use the example variables file
cd builds/aws
cp example.pkrvars.hcl my-aws-config.pkrvars.hcl

# Edit with your settings
vim my-aws-config.pkrvars.hcl

# Build with custom AWS configuration
../../scripts/buildManager.py --os debian-11-aws \
    --vars my-aws-config.pkrvars.hcl
```

### AWS-Specific Examples

#### Build with Encryption and Multi-Region

```bash
# Create encrypted AMI and copy to multiple regions
cat > aws-prod.pkrvars.hcl <<EOF
aws_region   = "us-west-2"
encrypt_boot = true
kms_key_id   = "arn:aws:kms:us-west-2:123456789012:key/your-key-id"

ami_regions = [
  "us-east-1",
  "us-east-2",
  "eu-west-1"
]

ami_users = ["123456789012"]  # Share with production account

tags = {
  Environment = "Production"
  Compliance  = "SOC2"
  CostCenter  = "Engineering"
}
EOF

./scripts/buildManager.py --os ubuntu-22-aws --vars aws-prod.pkrvars.hcl
```

#### Build in Custom VPC

```bash
# Build in specific VPC/subnet
cat > aws-custom-network.pkrvars.hcl <<EOF
aws_region        = "us-east-1"
vpc_id            = "vpc-0123456789abcdef0"
subnet_id         = "subnet-0123456789abcdef0"
security_group_id = "sg-0123456789abcdef0"
EOF

./scripts/buildManager.py --os debian-12-aws --vars aws-custom-network.pkrvars.hcl
```

#### Fast Development Build (No Encryption)

```bash
# Faster, cheaper build for testing
cat > aws-dev.pkrvars.hcl <<EOF
aws_region    = "us-east-1"
instance_type = "t3.medium"
volume_size   = 20
encrypt_boot  = false

tags = {
  Environment = "Development"
  AutoDelete  = "7-days"
}
EOF

./scripts/buildManager.py --os ubuntu-24-aws --vars aws-dev.pkrvars.hcl
```

#### Windows AMI with Larger Instance

```bash
# Windows builds benefit from larger instances
cat > aws-windows.pkrvars.hcl <<EOF
aws_region         = "us-west-2"
instance_type      = "t3.xlarge"  # Faster Windows Updates
volume_size        = 50
encrypt_boot       = true
winrm_timeout      = "45m"        # Windows needs longer timeout
communicator_timeout = "20m"
EOF

./scripts/buildManager.py --os windows-server-2022-aws --vars aws-windows.pkrvars.hcl
```

### Force Plugin Update

```bash
# Force re-download/upgrade Packer plugins
./scripts/buildManager.py --os debian-12 --force-init
```

### Pass Extra Packer Arguments

```bash
# Build with parallel builds
./scripts/buildManager.py --os debian-12 -- -parallel-builds=2

# Build with error handling
./scripts/buildManager.py --os debian-12 -- -on-error=ask

# Enable debug mode
./scripts/buildManager.py --os debian-12 -- -debug
```

## CI/CD Examples

### GitHub Actions - Proxmox Builds

```yaml
name: Build All Templates

jobs:
  build:
    runs-on: self-hosted
    strategy:
      matrix:
        os: [debian-12, debian-13, windows-server-2019, windows-server-2022]
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Packer
        uses: hashicorp/setup-packer@main
      
      - name: Initialize
        run: python3 scripts/buildManager.py --os ${{ matrix.os }} --init-only
      
      - name: Validate
        run: python3 scripts/buildManager.py --os ${{ matrix.os }} --validate-only
      
      - name: Build
        run: python3 scripts/buildManager.py --os ${{ matrix.os }}
```

### GitHub Actions - AWS AMI Builds

```yaml
name: Build AWS AMIs

on:
  push:
    branches: [main]
    paths:
      - 'builds/aws/**'
  workflow_dispatch:

jobs:
  build-linux:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        os: [debian-11-aws, debian-12-aws, ubuntu-22-aws, ubuntu-24-aws]
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      
      - name: Setup Packer
        uses: hashicorp/setup-packer@main
      
      - name: Initialize Packer
        run: python3 scripts/buildManager.py --os ${{ matrix.os }} --init-only
      
      - name: Validate Configuration
        run: python3 scripts/buildManager.py --os ${{ matrix.os }} --validate-only
      
      - name: Build AMI
        run: python3 scripts/buildManager.py --os ${{ matrix.os }}
      
      - name: Upload Manifest
        uses: actions/upload-artifact@v4
        with:
          name: manifest-${{ matrix.os }}
          path: builds/aws/**/*/manifests/*.json

  build-windows:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        os: [windows-server-2019-aws, windows-server-2022-aws]
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      
      - name: Setup Packer
        uses: hashicorp/setup-packer@main
      
      - name: Initialize Packer
        run: python3 scripts/buildManager.py --os ${{ matrix.os }} --init-only
      
      - name: Validate Configuration
        run: python3 scripts/buildManager.py --os ${{ matrix.os }} --validate-only
      
      - name: Build AMI
        run: |
          python3 scripts/buildManager.py --os ${{ matrix.os }} -- -timestamp-ui
        timeout-minutes: 120  # Windows builds take longer
      
      - name: Upload Manifest
        uses: actions/upload-artifact@v4
        with:
          name: manifest-${{ matrix.os }}
          path: builds/aws/**/*/manifests/*.json
```

### Shell Script Automation

#### Build All Proxmox Templates

```bash
#!/bin/bash
# build-all-proxmox.sh - Build all Proxmox OS templates

set -e

SCRIPT="./scripts/buildManager.py"
BUILDS=("debian-12" "debian-13" "windows-server-2019" "windows-server-2022")

for build in "${BUILDS[@]}"; do
    echo "=== Building $build ==="
    
    # Initialize
    "$SCRIPT" --os "$build" --init-only
    
    # Validate
    if ! "$SCRIPT" --os "$build" --validate-only; then
        echo "ERROR: Validation failed for $build"
        exit 1
    fi
    
    # Build
    "$SCRIPT" --os "$build"
    
    echo "=== Completed $build ==="
done

echo "All builds completed successfully!"
```

#### Build All AWS AMIs

```bash
#!/bin/bash
# build-all-aws.sh - Build all AWS AMIs with custom configuration

set -e

SCRIPT="./scripts/buildManager.py"
VARS_FILE="./builds/aws/production.pkrvars.hcl"

# Linux AMIs
LINUX_BUILDS=(
    "debian-11-aws"
    "debian-12-aws"
    "ubuntu-22-aws"
    "ubuntu-24-aws"
)

# Windows AMIs (need longer timeout)
WINDOWS_BUILDS=(
    "windows-server-2019-aws"
    "windows-server-2022-aws"
    "windows-desktop-10-aws"
    "windows-desktop-11-aws"
)

echo "=== Building Linux AMIs ==="
for build in "${LINUX_BUILDS[@]}"; do
    echo "Building $build..."
    "$SCRIPT" --os "$build" --vars "$VARS_FILE" --init-only
    "$SCRIPT" --os "$build" --vars "$VARS_FILE" --validate-only
    "$SCRIPT" --os "$build" --vars "$VARS_FILE"
done

echo "=== Building Windows AMIs ==="
for build in "${WINDOWS_BUILDS[@]}"; do
    echo "Building $build (this will take longer)..."
    "$SCRIPT" --os "$build" --vars "$VARS_FILE" --init-only
    "$SCRIPT" --os "$build" --vars "$VARS_FILE" --validate-only
    "$SCRIPT" --os "$build" --vars "$VARS_FILE" -- -timestamp-ui
done

echo "All AWS AMI builds completed successfully!"

# Output manifest summary
echo ""
echo "=== Build Manifests ==="
find builds/aws -name "*.json" -type f -path "*/manifests/*" -mtime -1 | while read manifest; do
    echo "  - $manifest"
    jq -r '.builds[0].artifact_id' "$manifest" 2>/dev/null || echo "    (manifest parse error)"
done
```

### Environment-Specific Builds

```bash
#!/bin/bash
# Build for different environments

ENVIRONMENT="${1:-dev}"
VARS_FILE="./vars/${ENVIRONMENT}.auto.pkrvars.hcl"

if [ ! -f "$VARS_FILE" ]; then
    echo "Error: Variables file not found: $VARS_FILE"
    exit 1
fi

./scripts/buildManager.py \
    --os debian-12 \
    --vars "$VARS_FILE"
```

## Interactive Mode

```bash
# Run without arguments for interactive menu
./scripts/buildManager.py
```

Interactive flow:
1. Select build from numbered list
2. Select source (if multiple available)
3. Choose action:
   - Initialize
   - Validate
   - Build
   - Validate + Build

## Troubleshooting

### Check What Variables Are Being Used

```bash
# Dry run shows exact command
./scripts/buildManager.py --os debian-12 --dry-run

# Output shows:
#   Working Directory: /path/to/build
#   Command: packer build -var-file /path/to/variables.auto.pkrvars.hcl .
```

### Verify Build Discovery

```bash
# Make sure your build is detected
./scripts/buildManager.py --list

# If build isn't found, check:
# 1. build.pkr.hcl exists in build directory
# 2. Directory structure matches: builds/{provider}/{os_type}/.../
```

### Initialize Fails

```bash
# Force upgrade of plugins
./scripts/buildManager.py --os debian-12 --force-init

# Check packer version
packer version
```

## Tips and Tricks

### Quick Validation of All Builds

#### Proxmox Builds
```bash
for os in debian-12 debian-13 windows-server-2019 windows-server-2022; do
    echo "Validating $os..."
    ./scripts/buildManager.py --os "$os" --validate-only || echo "FAILED: $os"
done
```

#### AWS Builds
```bash
# Validate all AWS Linux builds
for os in debian-11-aws debian-12-aws ubuntu-22-aws ubuntu-24-aws; do
    echo "Validating $os..."
    ./scripts/buildManager.py --os "$os" --validate-only || echo "FAILED: $os"
done

# Validate all AWS Windows builds
for os in windows-server-2019-aws windows-server-2022-aws windows-desktop-10-aws windows-desktop-11-aws; do
    echo "Validating $os..."
    ./scripts/buildManager.py --os "$os" --validate-only || echo "FAILED: $os"
done
```

### Check AWS Credentials

```bash
# Verify AWS credentials before building
aws sts get-caller-identity

# Test Packer can access AWS
cd builds/aws/linux/debian/11
packer validate .
```

### Extract AMI IDs from Manifests

```bash
# Get the latest AMI ID for a build
LATEST_MANIFEST=$(ls -t builds/aws/linux/debian/11/manifests/*.json | head -1)
AMI_ID=$(jq -r '.builds[0].artifact_id' "$LATEST_MANIFEST" | cut -d':' -f2)
echo "Latest Debian 11 AMI: $AMI_ID"

# Get all AMI IDs from today
find builds/aws -name "*.json" -mtime -1 | while read manifest; do
    AMI=$(jq -r '.builds[0].artifact_id' "$manifest" 2>/dev/null | cut -d':' -f2)
    BUILD=$(dirname "$(dirname "$manifest")")
    echo "$BUILD: $AMI"
done
```

### Compare Source AMI vs Built AMI

```bash
# See what base AMI was used
jq -r '.builds[0].custom_data.source_ami_name' builds/aws/linux/ubuntu/22/manifests/*.json | tail -1

# See build timestamp
jq -r '.builds[0].custom_data.build_time' builds/aws/linux/ubuntu/22/manifests/*.json | tail -1

# See git commit used for build
jq -r '.builds[0].custom_data.git_commit' builds/aws/linux/ubuntu/22/manifests/*.json | tail -1
```

### Build Only Changed OS

```bash
# Get changed files from git
CHANGED_OS=$(git diff --name-only HEAD~1 | grep "builds/" | cut -d'/' -f3-4 | sort -u)

if [ -n "$CHANGED_OS" ]; then
    ./scripts/buildManager.py --os "$CHANGED_OS"
fi
```

### Use with Make

```makefile
# Makefile
.PHONY: list init validate build clean

list:
	python3 scripts/buildManager.py --list

init-%:
	python3 scripts/buildManager.py --os $* --init-only

validate-%:
	python3 scripts/buildManager.py --os $* --validate-only

build-%:
	python3 scripts/buildManager.py --os $*

# Usage:
# make list
# make init-debian-12
# make validate-debian-12
# make build-debian-12
```

## Pattern Matching

The script supports flexible pattern matching:

```bash
# All of these work for Debian 12:
./scripts/buildManager.py --os debian-12
./scripts/buildManager.py --os debian_12
./scripts/buildManager.py --os "debian 12"
./scripts/buildManager.py --os deb12        # partial match

# Source matching:
./scripts/buildManager.py --source windows_server_2k22    # partial match
./scripts/buildManager.py --source proxmox-iso.windows    # partial match
```

## Getting Help

```bash
# Show full help
./scripts/buildManager.py --help

# Show version info
./scripts/buildManager.py --version
```
