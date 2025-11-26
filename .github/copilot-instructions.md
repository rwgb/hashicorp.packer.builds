# GitHub Copilot Instructions for HashiCorp Packer Builds Repository

## Repository Context

This repository contains **HashiCorp Packer configurations** for building virtual machine images and AMIs across multiple cloud providers (Proxmox VE and AWS). All builds are automated using GitHub Actions with CI/CD workflows.

## Code Style and Standards

### HCL (HashiCorp Configuration Language)

- **File Organization**: Separate Packer configurations into three files:
  - `variables.pkr.hcl` - Variable definitions with descriptions and defaults
  - `sources.pkr.hcl` - Builder source configurations
  - `build.pkr.hcl` - Build blocks, provisioners, and post-processors

- **Naming Conventions**:
  - Use snake_case for variable names: `proxmox_host`, `disk_storage_pool`
  - Use descriptive names that clearly indicate purpose
  - Prefix OS-specific resources: `debian_12_base`, `windows_2022_base`

- **Variable Definitions**:
  - Always include `type`, `description`, and appropriate `default` values
  - Mark sensitive variables with `sensitive = true`
  - Group related variables with comments (e.g., "// AWS Configuration", "// Network Settings")
  - Provide sensible defaults when possible to minimize required user input

- **Comments**:
  - Use `//` for single-line comments
  - Place explanatory comments above configuration blocks
  - Document non-obvious configuration choices

### Directory Structure

Follow the established pattern:
```
builds/
  <provider>/          # proxmox or aws
    <os-type>/         # linux or windows
      <os-family>/     # debian, ubuntu, windows
        <version>/     # 12, 22, 2019, etc.
          build.pkr.hcl
          sources.pkr.hcl
          variables.pkr.hcl
          data/        # Template files and scripts
```

## Packer-Specific Guidance

### Proxmox Builds

- **Authentication**: Always use API tokens (not username/password)
  - `username` field should reference `var.token_id` in format `user@pve!token_name`
  - `token` field should reference `var.token_secret`

- **Required Variables**:
  - `proxmox_host` - Proxmox server hostname/IP
  - `token_id` - API token ID (format: `username@pve!token_name`)
  - `token_secret` - API token secret
  - `node` - Proxmox node name
  - `pool` - Resource pool name
  - `iso_storage_pool`, `disk_storage_pool`, `cloud_init_storage_pool`

- **SSH Configuration**:
  - Use `ssh_username`, `ssh_password`, and `ssh_private_key_file` for communicator
  - Generate ephemeral SSH keys using the `sshkey` plugin data source
  - Set reasonable `ssh_timeout` (e.g., "90m" for large builds)

- **Boot Commands**: Use proper timing and escape sequences for automated installations

### AWS Builds

- **Source AMI Selection**:
  - Use `source_ami_filter` with proper filters for architecture, virtualization, and root-device-type
  - Always set `most_recent = true` to get latest AMI
  - Use official owner account IDs

- **Networking**:
  - Support both VPC subnet and default VPC scenarios
  - Use conditional expressions for optional parameters: `var.subnet_id != "" ? var.subnet_id : null`

- **AMI Configuration**:
  - Include timestamp in AMI names: `"${var.ami_name_prefix}-{{timestamp}}"`
  - Set appropriate encryption and KMS settings
  - Configure sharing via `ami_regions`, `ami_users`, `ami_groups`

### Build Blocks

- **Plugins**: Always declare required plugins in `packer` block with version constraints:
  ```hcl
  packer {
    required_plugins {
      proxmox = {
        version = ">= 1.1.3"
        source  = "github.com/hashicorp/proxmox"
      }
    }
  }
  ```

- **Locals**: Use locals for:
  - Generating unique IDs: `uuidv4()`, `substr(replace(uuid, "-", ""), 0, 8)`
  - Template file processing
  - Build metadata (version, date, git commit info)
  - Conditional logic that needs to be reused

- **Data Sources**:
  - Use `data "sshkey" "install"` for ephemeral SSH key generation
  - Use `data "git-commit" "build"` for version tracking
  - Include fallbacks for CI/CD environments: `try(data.git-commit.build.hash, env("GITHUB_SHA"), "unknown")`

- **Manifest Post-Processor**:
  - Always include for tracking build artifacts
  - Store in `./manifests/` directory with timestamp
  - Include custom metadata: version, author, build date

## GitHub Actions Workflows

### Structure
- Use descriptive workflow names: "Build Debian 12 Base Image"
- Set `workflow_dispatch` for manual triggers
- Add appropriate timeouts (e.g., `timeout-minutes: 90`)
- Use `self-hosted` runners for Proxmox builds

### Environment Variables
- Set Packer variables using `PKR_VAR_` prefix: `PKR_VAR_proxmox_host`
- Reference GitHub Secrets for sensitive values: `${{ secrets.PROXMOX_TOKEN_ID }}`
- Enable verbose logging: `PACKER_LOG: "1"`

### Required Secrets (Proxmox)
- `PROXMOX_HOST`, `PROXMOX_TOKEN_ID`, `PROXMOX_TOKEN_SECRET`
- `PROXMOX_NODE`, `PROXMOX_POOL`
- `PROXMOX_ISO_STORAGE`, `PROXMOX_DISK_STORAGE`, `PROXMOX_CLOUDINIT_STORAGE`
- `PROXMOX_USERNAME`, `PROXMOX_PASSWORD` (for VM access during build)

### Workflow Steps Pattern
1. System updates (if self-hosted)
2. Checkout repository
3. Setup Packer
4. Verify Packer installation
5. Initialize Packer (`packer init .`)
6. Validate configuration (`packer validate .`)
7. Build image (`packer build .`)
8. Upload artifacts/logs on failure
9. Generate build summary

### Artifact Handling
- Upload Packer logs on failure with 7-day retention
- Upload manifest files on success
- Include build summaries in `$GITHUB_STEP_SUMMARY`

## Common Patterns

### Template Files
- Use `.pkrtpl.hcl` extension for template files in `data/` directories
- Process with `templatefile()` function
- Pass variables as map to template: `{ username = var.username, password = var.password }`

### Kickstart/Preseed Configurations
- Store automated installation configs in `data/` directory
- Name appropriately: `ks.cfg` (Kickstart), `preseed.cfg` (Debian), `user-data` (cloud-init)
- Serve via Packer's built-in HTTP server using `http_content` or `http_directory`

### Error Handling
- Always check for required variables being set
- Provide helpful error messages for common misconfigurations
- Use validation blocks where appropriate

## Troubleshooting Guidance

When helping debug build failures:

1. **"username must be specified"**: Check that `token_id` variable is set and in correct format (`user@pve!token`)
2. **SSH timeout errors**: Verify network connectivity, firewall rules, and boot commands
3. **ISO not found**: Verify ISO path matches storage pool naming convention
4. **API authentication failures**: Validate token permissions and Proxmox API endpoint
5. **Build timeouts**: Check `task_timeout` and overall workflow timeout settings

## Version Information

- Current repository version: Check `VERSION` file
- Packer version: 1.9.x or later recommended
- Proxmox plugin: >= 1.1.3
- Target Proxmox VE: 7.x or later

## Best Practices

1. **Security**: Never commit secrets; always use GitHub Secrets or variable files in `.gitignore`
2. **Testing**: Validate configurations locally before pushing
3. **Documentation**: Update README.md when adding new builds or changing structure
4. **Versioning**: Update `VERSION` and `CHANGELOG.md` for significant changes
5. **CI/CD**: Test workflow changes in a separate branch first
6. **Idempotency**: Ensure builds can be repeated reliably
7. **Resource Cleanup**: Configure Packer to clean up on failure

## When Generating Code

- Follow existing patterns in similar build configurations
- Include comprehensive variable descriptions
- Add inline comments for complex logic
- Ensure proper error handling and validation
- Consider both manual and CI/CD execution contexts
- Test with `packer validate` before committing
