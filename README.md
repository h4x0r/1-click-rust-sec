# 1-Click Rust Security 🛡️

**Enterprise-grade security controls for Rust projects - installed in seconds, protecting in minutes**

Deploy 25+ comprehensive security controls with cryptographic verification and zero configuration. Built for developers who take security seriously.

[![Security](https://img.shields.io/badge/Security-25%2B%20Controls-green.svg)](https://github.com/h4x0r/1-click-rust-sec)
[![Performance](https://img.shields.io/badge/Pre--Push-~60s-blue.svg)](#performance)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-v0.1.0-orange.svg)](https://github.com/h4x0r/1-click-rust-sec/releases)
[![Pinning Validation](https://github.com/h4x0r/1-click-rust-sec/actions/workflows/pinning-validation.yml/badge.svg?branch=main)](https://github.com/h4x0r/1-click-rust-sec/actions/workflows/pinning-validation.yml)
[![Shell Lint](https://github.com/h4x0r/1-click-rust-sec/actions/workflows/shell-lint.yml/badge.svg?branch=main)](https://github.com/h4x0r/1-click-rust-sec/actions/workflows/shell-lint.yml)

## 🚀 Quick Start (30 Seconds)

**⚠️ Always verify security tools before installation!**

```bash
# Download and verify installer
curl -O https://raw.githubusercontent.com/h4x0r/1-click-rust-sec/main/install-security-controls.sh
curl -O https://raw.githubusercontent.com/h4x0r/1-click-rust-sec/main/install-security-controls.sh.sha256

# Verify checksum (REQUIRED for security)
sha256sum -c install-security-controls.sh.sha256

# Install
chmod +x install-security-controls.sh
./install-security-controls.sh
```

That's it! Your repository now has enterprise-grade security controls.

## 🎯 What You Get

### Immediate Protection (Pre-Push Hook)

Every `git push` automatically runs 25 security checks in ~60 seconds:

**🔴 Critical Controls (Blocking)**
- **Secret Detection** - Prevents credentials, tokens, and keys from entering git history
- **Security Vulnerabilities** - Blocks known CVEs via cargo-deny
- **GitHub Actions Pinning** - Ensures all actions use immutable SHA references
- **Large File Detection** - Prevents accidental secrets in binary files
- **Test Suite Validation** - Ensures tests pass before code ships
- **Format Enforcement** - Maintains consistent code style

**🟡 Important Controls (Warning)**
- Unsafe code monitoring with cargo-geiger
- License compliance validation
- Commit signature verification (Sigstore/GPG)
- Dependency version pinning checks
- Build script security analysis
- Documentation secret scanning
- Environment variable hardcoding detection
- Technical debt tracking
- File permission auditing
- Network address validation

### Lightweight Helper Tools

The installer includes two efficient helper scripts:

**pinactlite** - GitHub Actions SHA pinning verification
- Validates all workflow files use SHA-pinned actions
- Provides automatic pinning with `autopin` command
- Zero dependencies, pure bash implementation

**gitleakslite** - Secret detection
- Scans for AWS keys, GitHub tokens, API keys, private keys
- Configurable allow-listing for false positives
- Integrated with pre-commit and pre-push workflows

## 🏗️ Architecture

### Two-Tier Security Model

```
Developer Workstation                    CI/CD Pipeline
┌─────────────────────┐                 ┌──────────────────────┐
│   Pre-Push Hook     │                 │   GitHub Actions     │
│   (~60 seconds)     │      Push       │   (Comprehensive)    │
├─────────────────────┤      ──────>    ├──────────────────────┤
│ • Secret Detection  │                 │ • Pinning Validation │
│ • Vulnerability Scan│                 │ • Shell Linting      │
│ • Test Validation   │                 │ • Documentation Build│
│ • Format Check      │                 │ • E2E Testing        │
│ • License Compliance│                 │ • Installer Tests    │
│ • SHA Pinning       │                 │ • Helper Validation  │
│ • + 19 more checks  │                 │                      │
└─────────────────────┘                 └──────────────────────┘
    Block Bad Code                          Deep Analysis
```

### Why This Architecture?

**Fast Feedback** - Issues caught in 60 seconds, not after 10-minute CI runs
**Developer-Friendly** - Warnings don't block urgent fixes
**Security-First** - Critical issues always blocked
**Comprehensive** - 25+ checks cover all major attack vectors

## 📦 Installation Options

### Standard Installation (Recommended)
```bash
./install-security-controls.sh
```
Installs all security controls for Rust projects.

### Non-Rust Projects
```bash
./install-security-controls.sh --non-rust
```
Installs universal security controls (secrets, pinning, licenses).

### Custom Installation
```bash
./install-security-controls.sh --help
```
See all installation options including CI-only, documentation, and force modes.

## 🔧 Configuration

### Pre-Push Hook Configuration

Edit `.security-controls/config.env` to customize:

```bash
# Skip specific checks (use with caution)
SKIP_FORMAT_CHECK=false
SKIP_SECURITY_AUDIT=false
SKIP_SECRET_SCAN=false  # NEVER set to true in production

# Tool behavior
CARGO_AUDIT_TOOL="cargo-deny"  # or "cargo-audit"
MAX_FILE_SIZE_MB=10
```

### Secret Detection Allow-listing

For false positives, add patterns to `.security-controls/secret-allowlist.txt`:
```
# Example entries (one per line)
example-api-key-in-docs
test-token-[0-9]+
```

### Helper Tools Usage

```bash
# Check GitHub Actions pinning
.security-controls/bin/pinactlite pincheck --dir .github/workflows

# Auto-pin unpinned actions
.security-controls/bin/pinactlite autopin --dir .github/workflows --actions

# Scan for secrets
.security-controls/bin/gitleakslite detect --no-banner

# Check staged changes for secrets
.security-controls/bin/gitleakslite protect --staged --no-banner
```

## 🛡️ Security Features

### Cryptographic Verification
- SHA256 checksums for installer verification
- Signed commits with Sigstore/GPG
- Pinned dependencies with lock files
- Immutable GitHub Actions references

### Supply Chain Protection
- All GitHub Actions SHA-pinned to specific commits
- Dependency vulnerability scanning with cargo-deny
- License compliance validation
- SBOM generation support (when tools available)

### Secret Prevention
- Pre-push secret scanning (blocks push)
- Pre-commit secret detection (optional)
- Historical git content scanning
- Documentation secret detection

## 📊 Performance

### Typical Timings (Pre-Push)
- Format check: ~2s
- Clippy linting: ~15s
- Security audit: ~5s
- Test suite: ~20s (varies by project)
- Secret scan: ~2s
- Other checks: ~15s combined
- **Total: ~60 seconds**

### Optimization Tips
- Use `--no-verify` only for emergency hotfixes
- Run `cargo build --release` before push to warm caches
- Keep test suites fast and focused
- Use parallel test execution

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [Installation Guide](SECURITY_CONTROLS_INSTALLATION.md) | Detailed setup instructions |
| [Architecture](SECURITY_CONTROLS_ARCHITECTURE.md) | Technical deep-dive |
| [Contributing](CONTRIBUTING.md) | How to contribute |
| [Changelog](CHANGELOG.md) | Version history |

## 🤝 Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

Key areas for contribution:
- Additional security checks
- Performance optimizations
- Tool integrations
- Documentation improvements
- Multi-language support

## 📄 License

Apache 2.0 - See [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

This project leverages excellent open-source security tools:
- [cargo-deny](https://github.com/EmbarkStudios/cargo-deny) - Dependency checking
- [cargo-audit](https://github.com/RustSec/rustsec) - Vulnerability database
- [gitleaks](https://github.com/gitleaks/gitleaks) - Secret detection inspiration
- [pinact](https://github.com/suzuki-shunsuke/pinact) - Action pinning inspiration

## 🚨 Security Policy

Found a security issue? Please email security@[domain] or open a GitHub Security Advisory.

## 🎯 Roadmap

### v0.2.0 (Planned)
- [ ] SAST integration (Semgrep/CodeQL)
- [ ] Container scanning support
- [ ] SBOM generation
- [ ] Multi-language support (Python, Go, Node.js)

### v0.3.0 (Future)
- [ ] Cloud security posture management
- [ ] Compliance reporting (SOC2, ISO27001)
- [ ] IDE integrations
- [ ] Security metrics dashboard

---

**🛡️ Secure your Rust projects with confidence - Install in seconds, protect forever**

*Questions? Issues? → [GitHub Issues](https://github.com/h4x0r/1-click-rust-sec/issues)*