This repository builds Packer images and contains helper scripts and Ansible playbooks used by the maintainer.

Keep guidance concise and concrete. Prefer changes that are minimal, well-tested, and respect existing conventions.

What this repo contains (big picture)
- `builds/` — primary build pipelines organized by platform (linux/, windows/). Each image has a directory containing Packer HCL (`build.pkr.hcl`, `sources.pkr.hcl`, variable files, and a `data/` and `manifests/` directory). Changes here alter image definitions and provisioning.
- `packer/` — user-facing helper scripts (e.g., `run_wrapper.sh`, `wrapper.py`, `setup-github-runner.sh`), `example_usage.sh`, and `requirements.txt` for any Python helpers.
- `ansible/` — Ansible inventory and playbooks used for provisioning built images.

Key workflows (explicit commands and files)
- Local image build: developers run `./packer/run_wrapper.sh` or call `./packer/wrapper.py` from the repo root. Inspect `packer/example_usage.sh` for pattern usage.
- Validate Packer templates: `packer pkinit`, `pkfmt`, and `pkvalidate` aliases are used locally; however CI may call `packer init` and `packer validate` directly.
- Windows image preparation: see `builds/windows/*/data/autounattend.pkrtpl.hcl` and `builds/windows/*/drivers/` for vendor drivers — these files are sensitive to path and encoding.
- Ansible: `ansible/inventory.ini` and `ansible/check_winrm.yml` define how the repository tests Windows remoting. Use `ansible-playbook -i ansible/inventory.ini <playbook>`.

Patterns & conventions
- Packer structure: each image directory follows a consistent layout: `build.pkr.hcl`, `sources.pkr.hcl`, `variables.pkr.hcl`, `variables.auto.pkrvars.hcl`, `data/`, and `manifests/`. When adding a new image, mirror this layout.
- Manifesting builds: `builds/*/*/manifests/*.json` store build metadata — prefer appending new manifest entries rather than rewriting history.
- Drivers and binary blobs: `builds/windows/*/drivers/` contain OEM driver files. Avoid changing names/encodings unless updating matching HCL templates.
- Shell/tooling: the maintainer uses aliases and small wrappers (see `~/.zshrc` in user's home) — keep CLI behavior backward-compatible with `git`, `packer`, and `ansible` defaults.

Integration points and external dependencies
- External services: Packer interacts with cloud and virtualization providers (local hypervisors, possibly Proxmox); check top-level build variables for provider configuration.
- Python helpers: `packer/wrapper.py` expects dependencies in `packer/requirements.txt` (use a virtualenv matching repository conventions). Use `pyenv`/venv as appropriate.
- CI: this repository includes a `.git/` directory but no visible GitHub Actions in this tree; when adding CI, follow current repo layout: validate Packer HCL, run `pkfmt`, and run short Ansible checks.

When editing code
- Make minimal, testable changes. For Packer HCL edits, run `packer init`, `packer fmt -write=true`, then `packer validate` locally (or the provided wrappers in `packer/`).
- For changes affecting image installs (Ansible or scripts in `builds/*/data`), prefer adding a new manifest entry and test via a local build before committing.

Files to inspect when starting work
- `builds/` (start at the target platform subfolder)
- `packer/run_wrapper.sh`, `packer/wrapper.py`, `packer/example_usage.sh`
- `ansible/inventory.ini`, `ansible/check_winrm.yml`
- `WARP.md` — maintainer notes that may include workflow context

Examples
- When asked to update a Packer HCL variable, locate the corresponding `variables.pkr.hcl` and `variables.auto.pkrvars.hcl` in the same image folder and adjust both; run `pkfmt` and `pkvalidate` before committing.
- To add a new Windows driver, add files to `builds/windows/<image>/drivers/` and ensure `sources.pkr.hcl` or `build.pkr.hcl` references them; do not change filenames in-place without updating references.

Avoid
- Proposing large architectural rewrites without an explicit maintainer request. The repo is operational and favors stable, incremental improvements.

If anything is unclear or you need more repository-specific examples (CI commands, secrets handling, or build environment variables), ask for the specific area and I will surface exact files and lines to reference.
