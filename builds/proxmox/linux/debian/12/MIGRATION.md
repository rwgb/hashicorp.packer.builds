# Migration Guide: Chained Builds Refactoring

## What Changed

The Debian 12 Packer build has been refactored from a single monolithic build to a modular, chained build system.

### Before (Old Structure)
```
debian/12/
├── build.pkr.hcl           # Single build definition
├── sources.pkr.hcl         # proxmox-iso source only
├── variables.pkr.hcl       # All variables
├── variables.auto.pkrvars.hcl  # Credentials
└── data/
    └── ks.pkrtpl.hcl       # Kickstart template
```

**Problems:**
- Every build reinstalls OS from ISO (slow)
- No reusability between builds
- Ansible provisioning mixed with OS installation
- Hard to create variants (docker, database, etc.)

### After (New Structure)
```
debian/12/
├── base/                      # ISO-based foundation build
│   ├── build.pkr.hcl
│   ├── sources.pkr.hcl       # proxmox-iso
│   ├── variables.pkr.hcl
│   └── data/
│       └── ks.pkrtpl.hcl
├── configured/                # Clone-based layered builds
│   ├── build.pkr.hcl         # Includes Ansible provisioner
│   ├── sources.pkr.hcl       # proxmox-clone
│   └── variables.pkr.hcl
├── common.auto.pkrvars.hcl   # Shared configuration
├── build-chain.sh            # Orchestration script
└── README.md                 # Documentation
```

**Benefits:**
- Base template built once, cloned many times (fast)
- Modular and reusable
- Clear separation of concerns
- Easy to create new variants
- Consistent base across all templates

## Migration Steps

### 1. Update Variables File

The old `variables.auto.pkrvars.hcl` is now `common.auto.pkrvars.hcl`:

```bash
# Old location (still works for backward compatibility)
debian/12/variables.auto.pkrvars.hcl

# New location (recommended)
debian/12/common.auto.pkrvars.hcl
```

**Action:** Copy your existing credentials to the new location:
```bash
cp variables.auto.pkrvars.hcl common.auto.pkrvars.hcl
```

### 2. Use New Build Commands

#### Old Way
```bash
cd debian/12/
packer build .
```

#### New Way - Base Template
```bash
cd debian/12/
./build-chain.sh base
# or manually:
cd base/ && packer build -var-file=../common.auto.pkrvars.hcl .
```

#### New Way - Configured Template
```bash
cd debian/12/
./build-chain.sh configured docker
# or manually:
cd configured/ && packer build -var-file=../common.auto.pkrvars.hcl -var ansible_host_type=docker .
```

### 3. Update Ansible Playbook References

If you were using the old build with Ansible, note that:

**Old:** Ansible provisioner was in the main `build.pkr.hcl`  
**New:** Ansible provisioner is only in `configured/build.pkr.hcl`

The playbook path has changed:
```hcl
# Old (relative to debian/12/)
playbook_file = "../../ansible/playbook.yml"

# New (relative to debian/12/configured/)
playbook_file = "../../../../ansible/playbook.yml"
```

### 4. Update CI/CD Pipelines

If you have CI/CD pipelines, update them to use the new structure:

**Old:**
```yaml
- name: Build template
  run: |
    cd builds/proxmox/linux/debian/12
    packer build .
```

**New:**
```yaml
- name: Build base template
  run: |
    cd builds/proxmox/linux/debian/12
    ./build-chain.sh base

- name: Build configured templates
  run: |
    cd builds/proxmox/linux/debian/12
    ./build-chain.sh configured docker
```

## Backward Compatibility

The old files in `debian/12/` are **preserved** but not actively used:
- `build.pkr.hcl` (old)
- `sources.pkr.hcl` (old)
- `variables.pkr.hcl` (old)
- `data/` (old)

**Recommendation:** Keep these for reference, but use the new structure going forward.

## Template Naming Changes

| Old Name | New Name | Type |
|----------|----------|------|
| `debian12base` | `debian-12-base` | Base |
| N/A | `debian-12-docker` | Configured |
| N/A | `debian-12-database` | Configured |
| N/A | `debian-12-webserver` | Configured |

**Note:** The old template name didn't follow conventions. New names use hyphens and are more descriptive.

## Feature Comparison

| Feature | Old Build | New Build (Base) | New Build (Configured) |
|---------|-----------|------------------|------------------------|
| Source | proxmox-iso | proxmox-iso | proxmox-clone |
| Build Time | ~20 min | ~20 min | ~5 min |
| Ansible | Optional | No | Yes |
| Variants | Manual | N/A | Easy |
| Reusability | Low | High | Very High |

## Common Questions

### Q: Do I need to rebuild everything?
**A:** No. You can keep using old templates. New structure is for future builds.

### Q: Can I still use the old build files?
**A:** Yes, they still work. But the new structure is recommended for maintainability.

### Q: What happens to my existing templates?
**A:** Nothing. They continue to work. New builds create new templates with new names.

### Q: How do I migrate my custom configurations?
**A:** 
1. Base customizations → `base/sources.pkr.hcl` or `base/data/ks.pkrtpl.hcl`
2. Ansible customizations → Update Ansible playbook with new host types
3. Variables → Add to `common.auto.pkrvars.hcl`

### Q: Do I need to delete old templates?
**A:** No, but you can clean them up once new templates are tested.

## Rollback Plan

If you need to revert:

1. The old build files are still present in `debian/12/`
2. Simply use them directly:
   ```bash
   cd debian/12/
   packer build -var-file=variables.auto.pkrvars.hcl .
   ```

## Next Steps

1. ✅ Review the new structure
2. ✅ Test base build: `./build-chain.sh base`
3. ✅ Test configured build: `./build-chain.sh configured`
4. ✅ Update documentation/runbooks
5. ✅ Update CI/CD pipelines
6. ✅ Train team members on new structure

## Support

Questions? Check:
- `README.md` - Full documentation
- `build-chain.sh --help` - Script usage
- Old build files - Reference implementation

## Timeline

- **Phase 1 (Current):** New structure available, old structure still works
- **Phase 2 (Future):** Deprecate old structure
- **Phase 3 (Later):** Remove old build files (after team migration)

No immediate action required - this is a non-breaking change!
