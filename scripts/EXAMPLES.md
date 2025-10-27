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

### GitHub Actions

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

### Shell Script Automation

```bash
#!/bin/bash
# build-all.sh - Build all OS templates

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

```bash
for os in debian-12 debian-13 windows-server-2019 windows-server-2022; do
    echo "Validating $os..."
    ./scripts/buildManager.py --os "$os" --validate-only || echo "FAILED: $os"
done
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
