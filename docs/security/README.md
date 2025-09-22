# Security Controls

This repository includes comprehensive security controls with industry-leading architecture.

See the main installation guide in SECURITY_CONTROLS_INSTALLATION.md for details.

## 🚀 Quick Start

### Shell compatibility
- Hooks and helpers run with /bin/bash and work with Bash 3.2+ (macOS default).
- Scripts avoid Bash 4-only constructs (declare -A, mapfile/readarray, nameref) for portability.
- zsh is fine: the scripts themselves invoke bash via shebangs.

- Install: run install-security-controls.sh as described in the installation guide.
- Verify: make a test commit and push to trigger CI.

### Uninstall
If you need to remove the installed controls, run in the repository root:

```bash
./uninstall-security-controls.sh --dry-run   # preview
./uninstall-security-controls.sh -y          # remove without prompt
```