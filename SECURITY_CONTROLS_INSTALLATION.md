# Security Controls Installation Guide

## ⚠️ What This Installer Provides

This installer adds security controls to **YOUR** Rust project. It provides:
- **25+ pre-push security checks** (run locally before each push)
- **2 helper tools** (pinactlite, gitleakslite)
- **Optional CI workflows** (can be skipped with --no-ci)
- **Configuration files** for security tools
- **🆕 GitHub security features** (with --github-security option)

**Note**: This repository itself has additional development-specific controls. See [REPO_SECURITY.md](REPO_SECURITY.md) for details about this repo's enhanced security.

---

## 🚀 Quick Start (Verified Installation)

**Never run unverified installers!** Always check the SHA256 checksum:

```bash
# Download installer and checksum
curl -O https://raw.githubusercontent.com/h4x0r/1-click-rust-sec/main/install-security-controls.sh
curl -O https://raw.githubusercontent.com/h4x0r/1-click-rust-sec/main/install-security-controls.sh.sha256

# VERIFY CHECKSUM (Critical!)
sha256sum -c install-security-controls.sh.sha256

# Run installer (includes GitHub security by default)
chmod +x install-security-controls.sh
./install-security-controls.sh

# Optional: Skip GitHub security features
./install-security-controls.sh --no-github-security
```

---

## 🛡️ What Gets Installed in YOUR Project

### 1. Pre-Push Hook (`~60 seconds` runtime)

A Git hook that runs 25+ security checks before each push:

#### Critical Checks (Blocking)
- **Secret Detection** - Prevents AWS keys, GitHub tokens, API keys, private keys from being pushed
- **Vulnerability Scanning** - Blocks known CVEs in dependencies (cargo-deny)
- **Test Validation** - Ensures all tests pass
- **Format Enforcement** - Maintains code style consistency
- **Linting** - Catches bugs and bad patterns (clippy)
- **Large File Prevention** - Blocks files >10MB

#### Important Checks (Warning Only)
- GitHub Actions SHA pinning verification
- Commit signature verification (if configured)
- License compliance checking
- Dependency version pinning
- Unsafe code monitoring (cargo-geiger)
- Unused dependencies (cargo-machete)
- Build script security
- Documentation secret scanning
- Environment variable hardcoding
- Rust edition checks
- Import validation
- File permissions
- Dependency count monitoring
- Network address validation
- Commit message security
- Technical debt tracking
- Empty file detection
- Cargo.lock validation

### 2. Helper Tools

Located in `.security-controls/bin/`:

#### pinactlite
```bash
# Check if GitHub Actions are SHA-pinned
.security-controls/bin/pinactlite pincheck --dir .github/workflows

# Auto-pin unpinned actions
.security-controls/bin/pinactlite autopin --dir .github/workflows --actions
```

#### gitleakslite
```bash
# Scan repository for secrets
.security-controls/bin/gitleakslite detect --no-banner

# Check staged changes before commit
.security-controls/bin/gitleakslite protect --staged --no-banner
```

### 3. Configuration Files

#### `.security-controls/config.env`
Controls which checks run and how:
```bash
# Example settings (defaults shown)
SKIP_FORMAT_CHECK=false
SKIP_SECRET_SCAN=false  # NEVER set to true!
CARGO_AUDIT_TOOL="cargo-deny"
MAX_FILE_SIZE_MB=10
```

#### `.security-controls/secret-allowlist.txt`
Patterns to exclude from secret detection (one per line):
```
example-api-key-[0-9]+
test-token-.*
```

#### `.security-controls/gitleaks.toml`
Full gitleaks configuration for secret detection patterns.

### 4. Optional: CI Workflows (--no-ci to skip)

Basic GitHub Actions workflows for continuous security validation.

### 5. Optional: Documentation (--no-docs to skip)

Security guides and architecture documentation.

### 6. 🔐 GitHub Security Features (enabled by default)

Comprehensive GitHub repository security configuration (use `--no-github-security` to skip):

#### ✅ **Automatically Configured**
- **Dependabot Vulnerability Alerts** - Automated dependency scanning
- **Dependabot Automated Security Fixes** - Automated security update PRs
- **Branch Protection Rules** - Requires PR reviews and status checks
- **CodeQL Security Scanning** - Adds `.github/workflows/codeql.yml`
- **Secret Scanning** - Server-side secret detection (auto-enabled for public repos)
- **Secret Push Protection** - Blocks secret pushes at GitHub level

#### 📋 **Manual Setup Required**
- **Security Advisories** - Private vulnerability reporting (requires repository admin web access)
- **Advanced Security** - ❌ GitHub Enterprise only (not available for public repositories)

#### 🛠️ **Requirements**
- GitHub CLI (`gh`) installed and authenticated
- Repository admin permissions for branch protection
- GitHub repository (not local-only)

#### 💡 **Smart Fallbacks**
If requirements aren't met, the installer provides detailed manual setup instructions.

---

## 📦 Installation Options

### Standard (Rust Projects)
```bash
./install-security-controls.sh
```
Full installation with all Rust-specific checks.

### Non-Rust Projects
```bash
./install-security-controls.sh --non-rust
```
Universal checks + GitHub security features.

### Without GitHub Security Features
```bash
./install-security-controls.sh --no-github-security
```
Local security only (skips GitHub repository configuration).

### Minimal (Hooks Only)
```bash
./install-security-controls.sh --no-ci --no-docs --no-github-security
```
Just the pre-push hook, no extras.

### Preview Mode
```bash
./install-security-controls.sh --dry-run
```
See what would be installed without making changes.

### Force Reinstall
```bash
./install-security-controls.sh --force
```
Overwrite existing security controls.

### Advanced Options
```bash
./install-security-controls.sh --help
```
See all available options.

---

## 📋 Prerequisites

### Always Required
- Git repository (`git init`)
- Bash 4.0+
- curl
- jq

### For Rust Projects
- Rust toolchain (rustup)
- Cargo

### Optional But Recommended
- cargo-deny or cargo-audit
- cargo-geiger
- cargo-machete
- cargo-license

---

## 🔧 Post-Installation Configuration

### 1. Test the Installation
```bash
# Create a test file with a fake secret
echo "aws_access_key_id=AKIAIOSFODNN7EXAMPLE" > test.txt
git add test.txt
git commit -m "test"
git push  # Should be blocked!
```

### 2. Customize Security Controls
Edit `.security-controls/config.env`:
```bash
# Skip specific checks if needed (not recommended)
SKIP_FORMAT_CHECK=true  # Skip format checking
SKIP_TESTS=true         # Skip test execution

# Choose audit tool
CARGO_AUDIT_TOOL="cargo-audit"  # or "cargo-deny"
```

### 3. Handle False Positives
Add patterns to `.security-controls/secret-allowlist.txt`:
```
# Example: Allow test API keys
test-api-key-[a-z0-9]+
```

### 4. Configure Commit Signing (Optional)
```bash
# For Sigstore/gitsign
git config --global gpg.x509.program gitsign
git config --global gpg.format x509
git config --global commit.gpgsign true
```

---

## 🚨 Troubleshooting

### Pre-push Hook Takes Too Long
- Run tests before push: `cargo test`
- Build in release mode: `cargo build --release`
- Skip non-critical checks in config

### False Positive Secret Detection
- Add pattern to `.security-controls/secret-allowlist.txt`
- Use environment variables instead of hardcoded values

### Missing Tools
The installer will show instructions for installing missing tools:
```bash
# Example: Install cargo-deny
cargo install cargo-deny

# Example: Install cargo-geiger
cargo install cargo-geiger
```

### Emergency Bypass
**Use only for critical hotfixes:**
```bash
git push --no-verify
```

---

## 🔄 Updating

### Check for Updates
```bash
./install-security-controls.sh --check-update
```

### Upgrade to Latest
```bash
./install-security-controls.sh --upgrade
```

### Manual Update
```bash
# Download latest installer
curl -O https://raw.githubusercontent.com/h4x0r/1-click-rust-sec/main/install-security-controls.sh
curl -O https://raw.githubusercontent.com/h4x0r/1-click-rust-sec/main/install-security-controls.sh.sha256

# Verify and run
sha256sum -c install-security-controls.sh.sha256
chmod +x install-security-controls.sh
./install-security-controls.sh --force
```

---

## 🗑️ Uninstallation

```bash
# Download uninstaller
curl -O https://raw.githubusercontent.com/h4x0r/1-click-rust-sec/main/uninstall-security-controls.sh

# Run uninstaller
chmod +x uninstall-security-controls.sh
./uninstall-security-controls.sh
```

Or manually remove:
```bash
rm -rf .security-controls/
rm .git/hooks/pre-push
rm -rf .github/workflows/security-*.yml  # If CI was installed
rm -rf docs/security/  # If docs were installed
```

---

## 📊 Performance Optimization

### Expected Timings
| Check | Typical Time | Optimization |
|-------|-------------|--------------|
| Format | ~2s | Run `cargo fmt` regularly |
| Clippy | ~15s | Fix warnings promptly |
| Tests | ~20s | Keep tests focused |
| Security Audit | ~5s | Update dependencies regularly |
| Secret Scan | ~2s | Use allowlist for false positives |
| Other | ~15s | - |
| **Total** | **~60s** | **Target: Under 90s** |

### Speed Tips
1. **Warm caches**: Run `cargo build --release` before pushing
2. **Fix issues early**: Don't let warnings accumulate
3. **Optimize tests**: Use `#[ignore]` for slow integration tests
4. **Update regularly**: Keep dependencies current

---

## 🆘 Getting Help

### Resources
- [README](README.md) - Project overview
- [CONTRIBUTING](CONTRIBUTING.md) - Contribution guide
- [Issues](https://github.com/h4x0r/1-click-rust-sec/issues) - Report problems

### Common Issues
- **"Command not found"**: Install missing tools per instructions
- **"Permission denied"**: Run `chmod +x` on scripts
- **"Not a git repository"**: Run `git init` first
- **"Checksum mismatch"**: Re-download both files

---

## 🔒 Security Notes

1. **Always verify checksums** before running the installer
2. **Never skip secret detection** in production
3. **Use --no-verify sparingly** and only for emergencies
4. **Keep tools updated** for latest security patches
5. **Review configuration** regularly

---

**Questions?** Open an issue at https://github.com/h4x0r/1-click-rust-sec/issues