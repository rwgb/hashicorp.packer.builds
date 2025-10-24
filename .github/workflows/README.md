# GitHub Actions Workflows for Packer Builds

This directory contains GitHub Actions workflows for building VM images with Packer.

## Workflows

### 1. `build-all.yml` - Build All Images

**Comprehensive workflow that can build any or all VM images in the repository.**

#### Triggers:
- **Manual (workflow_dispatch)**: Select specific builds or build all
- **Push to main/develop**: Automatically builds all images when builds/ directory changes
- **Scheduled**: Monthly on the 1st at 2 AM UTC

#### Available Builds:
- `debian-12` - Debian Linux 12
- `debian-13` - Debian Linux 13
- `windows-server-2019` - Windows Server 2019
- `windows-server-2022` - Windows Server 2022
- `all` - Build everything

#### Manual Trigger:
```bash
# Via GitHub UI:
# Actions → Packer Build | All Images → Run workflow → Select target

# Via GitHub CLI:
gh workflow run build-all.yml -f build_target=debian-13
gh workflow run build-all.yml -f build_target=all
```

#### Features:
- ✅ Dynamic matrix build strategy
- ✅ Parallel builds (max 2 concurrent to avoid resource exhaustion)
- ✅ Build validation before actual build
- ✅ Artifact uploads (manifests and logs)
- ✅ Build summary generation
- ✅ Fail-fast disabled (continue on individual build failures)

---

### 2. `build-debian-13.yml` - Debian 13 Specific Build

**Dedicated workflow for Debian 13 builds.**

#### Triggers:
- **Manual (workflow_dispatch)**
- **Push to `build/debian13` branch**
- **Changes to `builds/linux/debian/13/**`

---

## Required Secrets

Configure these secrets in your GitHub repository settings:

| Secret | Description |
|--------|-------------|
| `PROXMOX_HOST` | Proxmox server hostname/IP |
| `TOKEN_ID` | Proxmox API token ID |
| `TOKEN_SECRET` | Proxmox API token secret |
| `NODE` | Proxmox node name |
| `POOL` | Proxmox resource pool |
| `USERNAME` | Build user username |
| `PASSWORD` | Build user password |
| `BUILD_KEY` | SSH public key for builds |

### Setting Secrets:

```bash
# Via GitHub UI:
# Settings → Secrets and variables → Actions → New repository secret

# Via GitHub CLI:
gh secret set PROXMOX_HOST
gh secret set TOKEN_ID
gh secret set TOKEN_SECRET
# ... etc
```

---

## Workflow Architecture

### Matrix Strategy

The `build-all.yml` workflow uses a two-stage approach:

1. **Prepare Job**: Determines which builds to run based on trigger type
2. **Build Job**: Executes builds in parallel using matrix strategy

```yaml
matrix:
  build:
    - name: debian-12
      path: builds/linux/debian/12
    - name: debian-13
      path: builds/linux/debian/13
    # ... etc
```

### Artifacts

Each build produces:
- **Manifests** (retained 90 days): Build metadata and results
- **Logs** (retained 30 days): Detailed Packer execution logs

Access via: Actions → Workflow run → Artifacts section

---

## Local Testing with `act`

Test workflows locally using [nektos/act](https://github.com/nektos/act):

```bash
# List available jobs
act -l

# Test the all-builds workflow (dry run)
act workflow_dispatch -W .github/workflows/build-all.yml -n

# Run with secrets
act workflow_dispatch -W .github/workflows/build-all.yml --secret-file .secrets

# Test specific event
act push -W .github/workflows/build-all.yml
```

---

## Troubleshooting

### Build Fails with "repository does not exist"

Ensure `fetch-depth: 0` is set in checkout action (already configured).

### Secrets Not Found

Verify secrets are configured at repository level, not environment level.

### Concurrent Build Limits

The workflow limits concurrent builds to 2. Adjust `max-parallel` if needed:

```yaml
strategy:
  max-parallel: 2  # Increase if your runner can handle it
```

### Self-Hosted Runner Issues

Ensure your self-hosted runner:
- Has Packer installed
- Has network access to Proxmox
- Has sufficient disk space for builds
- Is labeled correctly (`self-hosted`)

---

## Best Practices

1. **Branch Strategy**: 
   - Use feature branches for build development
   - Merge to `main` to trigger production builds

2. **Testing**: 
   - Test with `packer validate` before pushing
   - Use manual workflow triggers for testing

3. **Monitoring**: 
   - Check build summaries in workflow runs
   - Download and review logs for failed builds
   - Monitor artifact storage usage

4. **Security**: 
   - Never commit secrets or `.secrets` file
   - Rotate Proxmox tokens regularly
   - Use least-privilege API tokens

---

## Adding New Builds

To add a new build to `build-all.yml`:

1. Create build directory: `builds/<os>/<distro>/<version>/`
2. Add Packer files: `build.pkr.hcl`, `sources.pkr.hcl`, `variables.pkr.hcl`
3. Update workflow matrix in `build-all.yml`:

```yaml
ALL_BUILDS='[
  ...
  {"name": "new-build", "path": "builds/os/distro/version", "os": "os", "log": "packer-new.log"}
]'
```

4. Commit and push to trigger build
