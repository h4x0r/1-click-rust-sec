# 1-Click GitHub Security 🛡️

<div align="center">
  <img src="./Security Ronin logo.png" alt="Security Ronin" width="200">
</div>

**Enterprise-grade security controls installer for multi-language projects**

*Created by Albert Hui <albert@securityronin.com>*

Deploy comprehensive security controls to any project with a single command. Supports Rust, Node.js, Python, Go, and generic projects. This repository serves two purposes:

1. **Security Installer** - Provides an installer that adds 25+ security controls + GitHub security features to YOUR projects
2. **Reference Implementation** - Demonstrates security best practices with its own enhanced controls

[![Security](https://img.shields.io/badge/Installer%20Provides-35%2B%20Controls-green.svg)](https://github.com/h4x0r/1-click-github-sec)
[![GitHub Security](https://img.shields.io/badge/GitHub%20Security-6%20Features-blue.svg)](#github-security-features)
[![This Repo](https://img.shields.io/badge/This%20Repo%20Has-40%2B%20Controls-purple.svg)](#this-repos-security)
[![Performance](https://img.shields.io/badge/Pre--Push-~60s-orange.svg)](#performance)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-v0.3.0-purple.svg)](https://github.com/h4x0r/1-click-github-sec/releases)

## 📖 [Complete Documentation →](https://h4x0r.github.io/1-click-github-sec/)

**For full installation guides, architecture details, and advanced configuration, visit our documentation site:**
**[https://h4x0r.github.io/1-click-github-sec/](https://h4x0r.github.io/1-click-github-sec/)**

## 📌 Important Distinction

| Aspect | What the Installer Gives You | What This Repository Has |
|--------|------------------------------|--------------------------|
| **Purpose** | Adds security to YOUR project | Protects THIS installer project |
| **Pre-push Controls** | 25+ security checks | 25+ security checks |
| **CI/CD Workflows** | Optional (--no-ci to skip) | 8 specialized workflows |
| **GitHub Security** | 6 features with --github-security | 6 features enabled |
| **Pre-commit Hooks** | Not included | Full pre-commit suite |
| **Documentation** | Basic security guides | Complete documentation site |
| **Helper Tools** | pinactlite, gitleakslite | Same + additional scripts |

**TL;DR**: This repository "eats its own dog food" - it uses an enhanced version of what it installs for others.

---

## 🚀 Quick Start (For YOUR Project)

Install security controls in your project in 30 seconds:

```bash
# Download and verify installer
curl -O https://raw.githubusercontent.com/h4x0r/1-click-github-sec/main/install-security-controls.sh
curl -O https://raw.githubusercontent.com/h4x0r/1-click-github-sec/main/install-security-controls.sh.sha256

# Verify checksum (REQUIRED for security)
sha256sum -c install-security-controls.sh.sha256

# Install in YOUR project (includes GitHub security by default)
chmod +x install-security-controls.sh
./install-security-controls.sh
```

## 🔐 GitHub Security Features {#github-security-features}

Enterprise-grade GitHub repository security is now **enabled by default**:

```bash
# Full installation (includes GitHub security)
./install-security-controls.sh

# Skip GitHub security if not needed
./install-security-controls.sh --no-github-security
```

### ✅ **Automatically Configured**
1. **🔍 Dependabot Vulnerability Alerts** - Automated dependency scanning
2. **🔧 Dependabot Security Fixes** - Automated security update PRs
3. **🛡️ Branch Protection Rules** - PR reviews + status checks required
4. **📊 CodeQL Security Scanning** - Workflow for code analysis
5. **🔐 Secret Scanning** - Server-side secret detection (auto-enabled)
6. **🚫 Secret Push Protection** - Blocks secrets at GitHub level

### 📋 **Manual Setup Required**
- **Security Advisories** - Private vulnerability reporting (web interface)
- **Advanced Security** - ❌ GitHub Enterprise only (not available for public repos)

**Why some features can't be automated:**
- Security Advisories requires repository admin web access
- Advanced Security is a paid GitHub Enterprise feature with organization-level controls

## 🎯 What YOUR Project Gets

### Core Security Controls (Pre-Push Hook)

The installer adds language-specific security checks that run automatically before each `git push`:

#### 🔄 **Universal Checks (All Languages)**
- **Secret Detection** - Blocks AWS keys, GitHub tokens, API keys, private keys
- **GitHub Actions SHA Pinning** - Verifies action security
- **Large File Prevention** - Prevents accidental binary/secret uploads
- **Commit Signature Verification** - Ensures signed commits

#### 🦀 **Rust Projects (25+ Checks)**

- **Vulnerability Scanning** - Blocks known CVEs via cargo-deny
- **Code Formatting** - cargo fmt enforcement
- **Linting** - clippy with security rules
- **Test Suite** - Ensures tests pass
- **License Compliance** - cargo-deny license checks
- **Unsafe Code Monitoring** - cargo-geiger analysis
- **Unused Dependencies** - cargo-machete detection
- Plus 18+ additional Rust-specific security checks

#### 📦 **Node.js Projects (12-Point Security Audit)**
- **Comprehensive npm audit** - Standard + enhanced auditing
- **Vulnerability Scanning** - Snyk + retire.js for JS libraries
- **Dependency Analysis** - Unused deps, circular dependencies
- **License Compliance** - License compatibility checking
- **Package Integrity** - package-lock.json validation
- **Bundle Analysis** - Size monitoring and cost analysis
- **Security Linting** - ESLint with security rules
- **Code Formatting** - Prettier enforcement
- Plus additional Node.js-specific security checks

#### 🐍 **Python Projects**
- **Vulnerability Scanning** - safety + pip-audit for Python packages
- **SAST Analysis** - bandit for security issues
- **Code Formatting** - black formatter enforcement
- **Linting** - flake8/pylint with security rules
- **Test Suite** - pytest/unittest execution
- Plus additional Python-specific security checks

#### 🐹 **Go Projects**
- **Vulnerability Scanning** - govulncheck for Go modules
- **Code Formatting** - gofmt enforcement
- **Linting** - golint with security focus
- **Test Suite** - go test execution
- Plus additional Go-specific security checks

### Helper Tools

Two lightweight bash scripts for security operations:

- **pinactlite** - GitHub Actions SHA pinning verification and auto-fixing
- **gitleakslite** - Fast secret detection with configurable patterns

### Optional Components

- **CI/CD Workflows** - GitHub Actions security workflows (use `--no-ci` to skip)
- **Documentation** - Security guides and architecture docs (use `--no-docs` to skip)
- **Configuration Files** - deny.toml, .cargo/config.toml security settings

---

## 🏰 This Repository's Security {#this-repos-security}

This repository practices what it preaches with ENHANCED security:

### Additional CI/CD Workflows
1. **Pinning Validation** - Ensures all actions use SHA pins
2. **Shell Linting** - shellcheck + shfmt validation
3. **Documentation Building** - MkDocs site generation
4. **E2E Testing** - Full installation testing
5. **Helper Sync Validation** - Ensures tool consistency
6. **Installer Self-Test** - Validates installer integrity
7. **Documentation Deployment** - GitHub Pages automation

### Additional Pre-Commit Hooks
- Trailing whitespace removal
- End-of-file fixing
- YAML validation
- Large file checking
- Markdown linting
- Shell script formatting
- pinactlite sync verification

### Additional Tools
- Full pre-commit framework integration
- MkDocs documentation site
- Automated dependency updates (Dependabot)
- Renovate bot configuration
- EditorConfig for IDE consistency

---

## 📦 Installation Options

### Auto-Detection (Recommended)
```bash
./install-security-controls.sh
```
Automatically detects your project language and installs optimized security controls.

**Supported Languages:**
- **🦀 Rust** - cargo-deny, clippy, fmt, audit, geiger
- **📦 Node.js** - 12-point npm audit, ESLint, Prettier, Snyk
- **🐍 Python** - safety, bandit, black, flake8, pip-audit
- **🐹 Go** - govulncheck, gofmt, golint, go test
- **⚙️ Generic** - Universal security controls for any project

### Force Specific Language
```bash
./install-security-controls.sh --language=nodejs    # Node.js/JavaScript/TypeScript
./install-security-controls.sh --language=python    # Python projects
./install-security-controls.sh --language=go        # Go projects
./install-security-controls.sh --language=rust      # Rust projects
./install-security-controls.sh --language=generic   # Language-agnostic
```

### Polyglot Repository Support
```bash
# For repositories with multiple languages
./install-security-controls.sh --language=rust,nodejs,python
```
**Automatic Detection**: The installer automatically detects multiple languages in your repository and installs appropriate security controls for each detected language.

### Without GitHub Security Features
```bash
./install-security-controls.sh --no-github-security
```
Installs local security only (skips GitHub repository configuration).

### Minimal Installation (Just Hooks)
```bash
./install-security-controls.sh --no-ci --no-docs --no-github-security
```
Installs only the pre-push hook, no workflows, docs, or GitHub security.

### See All Options
```bash
./install-security-controls.sh --help
```

---

## 🔧 Configuration

### Customize Security Controls

Edit `.security-controls/config.env` after installation:

```bash
# Skip specific checks (use with caution)
SKIP_FORMAT_CHECK=false
SKIP_SECURITY_AUDIT=false
SKIP_SECRET_SCAN=false  # NEVER set to true in production

# Tool preferences
CARGO_AUDIT_TOOL="cargo-deny"  # or "cargo-audit"
MAX_FILE_SIZE_MB=10
```

### Secret Detection Tuning

Add false positive patterns to `.security-controls/secret-allowlist.txt`:
```
# One pattern per line
example-api-key-in-docs
test-token-[0-9]+
```

---

## 📊 Performance {#performance}

### Pre-Push Hook Timing
- Format check: ~2s
- Clippy linting: ~15s
- Security audit: ~5s
- Test suite: ~20s (varies)
- Secret scan: ~2s
- Other checks: ~15s
- **Total: ~60 seconds**

### Optimization Tips
- Keep test suites focused
- Use `cargo build --release` before push to warm caches
- Use `--no-verify` only for emergency hotfixes

---

## 🛡️ Security Architecture

### Two-Tier Model

```
┌─────────────────────┐         ┌──────────────────────┐
│ Developer Machine   │  Push   │ CI/CD (Optional)     │
│ ┌─────────────────┐ │ ──────> │ ┌──────────────────┐ │
│ │ Pre-Push Hook   │ │         │ │ Deep Analysis    │ │
│ │ 25+ Checks      │ │         │ │ SAST/DAST       │ │
│ │ ~60 seconds     │ │         │ │ Supply Chain    │ │
│ └─────────────────┘ │         │ │ Compliance      │ │
└─────────────────────┘         │ └──────────────────┘ │
  Fast Local Blocking           └──────────────────────┘
                                  Comprehensive Analysis
```

### Cryptographic Verification
- SHA256 checksums for installer
- Signed commits support
- SHA-pinned GitHub Actions
- Dependency lock files

---

## 📚 Documentation

| Document | Description | Audience |
|----------|-------------|----------|
| [README.md](README.md) | This file - overview and quick start | Everyone |
| [INSTALLATION.md](SECURITY_CONTROLS_INSTALLATION.md) | Detailed installation guide | Users installing controls |
| [ARCHITECTURE.md](SECURITY_CONTROLS_ARCHITECTURE.md) | Technical deep-dive | Security engineers |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Contribution guidelines | Contributors |
| [REPO_SECURITY.md](REPO_SECURITY.md) | This repo's security setup | Maintainers |

---

## 🤝 Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

Key areas:
- New security checks for supported languages
- Performance optimizations
- Additional language support
- Tool integrations and improvements

---

## 🚨 Security

Found a security issue? Please:
1. **DO NOT** open a public issue
2. Email security@[domain] or
3. Use GitHub Security Advisories

---

## 📄 License

Apache 2.0 - See [LICENSE](LICENSE)

---

## 🙏 Acknowledgments

Built on excellent open-source tools:
- [cargo-deny](https://github.com/EmbarkStudios/cargo-deny)
- [cargo-audit](https://github.com/RustSec/rustsec)
- [gitleaks](https://github.com/gitleaks/gitleaks) (inspiration)
- [pinact](https://github.com/suzuki-shunsuke/pinact) (inspiration)

---

## ❓ FAQ

**Q: Why does this repo have more security than what it installs?**
A: This repository is the development environment for the installer. It needs additional workflows for testing, documentation, and validation that end users don't need.

**Q: Can I get ALL the security this repo has?**
A: Yes! Clone this repo and copy the additional workflows and pre-commit config. But most projects don't need all of these.

**Q: What's the minimum I should install?**
A: Just run the basic installer - it provides comprehensive security appropriate for most projects.

**Q: How do I know the installer is safe?**
A: Always verify the SHA256 checksum. The installer is also open source for full transparency.

---

## 👨‍💻 Author

**Albert Hui** <albert@securityronin.com>
*Security Ronin*

---

**🛡️ Secure your projects with confidence**

*Install in seconds, protect forever*