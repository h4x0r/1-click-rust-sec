# 1-Click GitHub Security 🛡️

<div align="center">
  <img src="./1-click-github-sec Logo.png" alt="1-Click GitHub Security" width="200">
</div>

**Multi-language security controls installer for GitHub projects**

*Created by Albert Hui <albert@securityronin.com>* [![LinkedIn](https://img.shields.io/badge/LinkedIn-0077B5?style=flat-square&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/alberthui) [![Website](https://img.shields.io/badge/Website-4285F4?style=flat-square&logo=google-chrome&logoColor=white)](https://www.securityronin.com/)

Deploy security controls to any project with a single command. Supports Rust, Node.js, Python, Go, and generic projects. This repository serves two purposes:

1. **Security Installer** - Provides an installer that adds 35+ security controls + GitHub security features to YOUR projects
2. **Reference Implementation** - Demonstrates security best practices with its own enhanced controls

[![Security](https://img.shields.io/badge/Installer%20Provides-35%2B%20Controls-green.svg)](https://github.com/h4x0r/1-click-github-sec)
[![GitHub Security](https://img.shields.io/badge/GitHub%20Security-6%20Features-blue.svg)](#github-security-features)
[![This Repo](https://img.shields.io/badge/This%20Repo%20Has-40%2B%20Controls-purple.svg)](#this-repos-security)
[![Performance](https://img.shields.io/badge/Pre--Push-~60s-orange.svg)](#performance)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-v0.4.1-purple.svg)](https://github.com/h4x0r/1-click-github-sec/releases)

## 📖 [Complete Documentation →](https://h4x0r.github.io/1-click-github-sec/)

**For full installation guides, architecture details, and advanced configuration, visit our documentation site:**
**[https://h4x0r.github.io/1-click-github-sec/](https://h4x0r.github.io/1-click-github-sec/)**

## 📌 Important Distinction

| Aspect | What the Installer Gives You | What This Repository Has |
|--------|------------------------------|--------------------------|
| **Purpose** | Adds security to YOUR project | Protects THIS installer project |
| **Pre-push Controls** | 35+ security checks | 35+ security checks |
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

## 🔐 GitHub Security Features

GitHub repository security features are **enabled by default**:

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

#### 🦀 **Rust Projects (35+ Checks)**

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

## 🏰 This Repository's Security

This repository practices what it preaches with ENHANCED security:

### Core Security Controls (Included in Installer)
1. **Trivy Vulnerability Scanning** - Multi-language vulnerability detection (provided to all users)
2. **CodeQL Security Scanning** - GitHub-native SAST analysis (provided to all users)
3. **Secret Detection** - Gitleaks-powered credential scanning (provided to all users)
4. **Supply Chain Security** - SHA pinning and dependency auditing (provided to all users)
5. **Pre-Push Hooks** - 35+ security checks before code reaches remote (provided to all users)

### Additional Repository-Specific Workflows
1. **Comprehensive Quality Assurance** - Advanced ShellCheck, shfmt, and code formatting
2. **Documentation Building** - MkDocs site generation and GitHub Pages deployment
3. **Release Automation** - Cryptographic signing and artifact generation
4. **Helper Tool Synchronization** - pinactlite and gitleakslite maintenance
5. **Advanced CI Integration** - Blocking vs non-blocking validation gates

### Additional Pre-Commit Hooks
- Trailing whitespace removal
- End-of-file fixing
- YAML validation
- Large file checking
- Markdown linting
- Shell script formatting
- pinactlite sync verification
- gitleakslite sync verification

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

> **⚠️ Testing Status**: Currently, **Rust** and **Generic** profiles have been extensively tested in production environments. Node.js, Python, and Go profiles are functional but have received less comprehensive testing. We recommend thorough validation in your specific environment before production deployment.

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

## 📊 Performance

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
│ │ 35+ Checks      │ │         │ │ SAST/DAST       │ │
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

## 🎯 Design Philosophy

### True 1-Click Installation

**"1-Click" means exactly that**: Download one script, run one command, get enterprise security.

```bash
# This is ALL you need:
curl -O https://raw.githubusercontent.com/h4x0r/1-click-github-sec/main/install-security-controls.sh
curl -O https://raw.githubusercontent.com/h4x0r/1-click-github-sec/main/install-security-controls.sh.sha256
sha256sum -c install-security-controls.sh.sha256
chmod +x install-security-controls.sh
./install-security-controls.sh
```

**No account creation. No external service registration. No GitHub App installations.**

### Core Design Principles

#### 🚀 **Zero External Dependencies**
- **Single shell script** with embedded framework
- **No account signups** or external service dependencies
- **No GitHub Apps** requiring marketplace installation
- **Works offline** after initial download

#### 🛡️ **Security Without Compromise**
- **Cryptographic verification** for all components (SHA256)
- **GitHub-native tools** preferred (CodeQL, Dependabot, etc.)
- **Downloadable binaries** over external services
- **Fail secure** - blocks rather than allows on errors

#### ⚡ **Performance First**
- **Sub-60 second** pre-push validation
- **Parallel execution** of independent checks
- **Smart caching** for repeated operations
- **No waiting** for external API calls in critical path

#### 🍽️ **Dogfooding Plus Philosophy**
- **We use what we build**: This repository implements ALL security controls that the installer provides
- **Plus enhanced controls**: Additional development-specific workflows (tool sync, docs, releases)
- **Alpha testing**: We are the first to discover issues with our own security controls
- **Functional synchronization**: Automated tools ensure repo controls stay in sync with installer templates

**Why This Matters:**
- **Quality assurance**: If it's not good enough for us, it's not good enough for users
- **Rapid bug discovery**: Issues surface in our development workflow before user deployment
- **Continuous validation**: Our daily development validates the installer's security effectiveness
- **Trust building**: Users can inspect our repository to see the exact security controls in action

### Tool Selection Criteria

We carefully evaluate each security tool against our principles:

#### ✅ **INCLUDED - Meets All Criteria**

| Tool | Why Included | 1-Click Compatible |
|------|--------------|-------------------|
| **CodeQL** | GitHub-native, zero setup, universal SAST | ✅ Auto-generates workflows |
| **gitleaks** | Downloadable binary, works offline | ✅ Embedded in installer |
| **cargo-deny** | Language toolchain, no external deps | ✅ Pure Rust cargo tool |
| **npm audit** | Built into npm, no accounts needed | ✅ Native Node.js tooling |

#### ❌ **REJECTED - Violates Core Principles**

| Tool | Why Rejected | Violates Principle |
|------|--------------|-------------------|
| **Socket.dev** | Requires account + GitHub App install | ❌ External dependencies |
| **Snyk** | Account creation + authentication setup | ❌ Multi-step registration |
| **Semgrep Cloud** | Account + app installation required | ❌ External service signup |

#### ✅ **IMPLEMENTED - Additional Analysis Tools**

| Tool | Status | Implementation |
|------|--------|----------------|
| **Trivy** | ✅ Implemented | Multi-language vulnerability scanning in CI workflows |
| **CodeQL** | ✅ Implemented | GitHub-native SAST analysis for security scanning |

#### 🟡 **UNDER CONSIDERATION - Future Tools**

| Tool | Consideration | Condition for Inclusion |
|------|---------------|------------------------|
| **SonarQube CE** | Comprehensive analysis | 🟡 Only if self-hosted option viable |

### Why This Matters

**Corporate Environment Friendly**: No need to request IT approval for external accounts or marketplace apps.

**Individual Developer Friendly**: Works identically on personal repos (`user/project`) and organizational repos (`org/project`).

**Security Focused**: External service dependencies increase attack surface and create supply chain risks.

**Reliability**: No network dependencies in critical security path means it works in air-gapped environments.

### Examples in Practice

#### ✅ **How We Add New Security Tools**

```bash
# Example: Adding Trivy (perfect 1-click candidate)
# 1. Download Trivy binary during installation
# 2. Generate GitHub workflow that uses downloaded binary
# 3. No user accounts or external setup required
# 4. Works immediately after installation
```

#### ❌ **What We Don't Do**

```bash
# This would violate our principles:
# "Please create an account at security-service.com"
# "Install our GitHub App from the marketplace"
# "Authenticate with your API key"
# "Configure your organization settings"
```

**Result**: Our installer works for everyone, everywhere, immediately. That's true 1-click security.

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
2. Email **security@securityronin.com** or
3. Use GitHub Security Advisories

We take security seriously and will respond to legitimate security reports promptly.

---

## 📄 License

Apache 2.0 - See [LICENSE](LICENSE)

---

## 🙏 Acknowledgments

This project stands on the shoulders of giants. We're grateful to the amazing open-source security community:

### 🛠️ **Core Security Tools**
- [**CodeQL**](https://github.com/github/codeql) - GitHub's semantic code analysis engine
- [**Trivy**](https://github.com/aquasecurity/trivy) - Comprehensive vulnerability scanner by Aqua Security
- [**cargo-deny**](https://github.com/EmbarkStudios/cargo-deny) - Rust dependency security by Embark Studios
- [**cargo-audit**](https://github.com/RustSec/rustsec) - Rust security advisory database by RustSec
- [**Dependabot**](https://github.com/dependabot) - GitHub's automated dependency updates

### 💡 **Inspiration and Architecture**
- [**gitleaks**](https://github.com/gitleaks/gitleaks) - Secret detection inspiration by Zachary Rice
- [**pinact**](https://github.com/suzuki-shunsuke/pinact) - GitHub Actions pinning inspiration by Shunsuke Suzuki
- [**OpenSSF Scorecard**](https://github.com/ossf/scorecard) - Supply chain security methodology
- [**SLSA Framework**](https://slsa.dev/) - Supply-chain security framework

### 🌐 **Language Ecosystem Tools**
- **Rust**: [clippy](https://github.com/rust-lang/rust-clippy), [rustfmt](https://github.com/rust-lang/rustfmt), [cargo-geiger](https://github.com/geiger-rs/cargo-geiger)
- **Node.js**: [ESLint](https://eslint.org/), [Prettier](https://prettier.io/), [npm audit](https://docs.npmjs.com/cli/v8/commands/npm-audit)
- **Python**: [safety](https://github.com/pyupio/safety), [bandit](https://github.com/PyCQA/bandit), [black](https://github.com/psf/black)
- **Go**: [govulncheck](https://pkg.go.dev/golang.org/x/vuln/cmd/govulncheck), [golangci-lint](https://golangci-lint.run/)

### 🏗️ **Infrastructure and CI/CD**
- [**GitHub Actions**](https://github.com/features/actions) - CI/CD platform and security workflows
- [**ShellCheck**](https://github.com/koalaman/shellcheck) - Shell script analysis by Vidar Holen
- [**shfmt**](https://github.com/mvdan/sh) - Shell formatting by Daniel Martí

**Special thanks to all maintainers and contributors who make secure software development possible. 🙌**

---

## ❓ FAQ

**Q: Why does this repo have more security than what it installs?**
A: This repository is the development environment for the installer. It needs additional workflows for testing, documentation, and validation that end users don't need.

**Q: Can I get ALL the security this repo has?**
A: Yes! Clone this repo and copy the additional workflows and pre-commit config. But most projects don't need all of these.

**Q: What's the minimum I should install?**
A: Just run the basic installer - it provides security controls suitable for most projects (note the testing status for your language above).

**Q: How do I know the installer is safe?**
A: Always verify the SHA256 checksum. The installer is also open source for full transparency.

---

## 👨‍💻 Author

**Albert Hui** <albert@securityronin.com>
*Security Ronin*

[![LinkedIn](https://img.shields.io/badge/LinkedIn-0077B5?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/alberthui) [![Website](https://img.shields.io/badge/Website-4285F4?style=for-the-badge&logo=google-chrome&logoColor=white)](https://www.securityronin.com/)

---

**🛡️ Secure your projects with confidence**

*Install in seconds, protect forever*