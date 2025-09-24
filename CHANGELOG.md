# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2025-01-24

### 🚀 Major Version Update

**Transform to 1-Click GitHub Security** - Multi-language support and comprehensive security framework.

### Added
- **Multi-language support** - Rust, Node.js, Python, Go support
- **Enhanced installer architecture** - Improved single-script design
- **Advanced security controls** - Expanded from Rust-specific to universal
- **Improved documentation** - Comprehensive CLAUDE.md design principles
- **Better error handling** - Enhanced user experience and debugging

### Changed
- **Project scope expansion** - From 1-click-rust-sec to 1-click-github-sec
- **Architecture improvements** - Single-script with zero external dependencies
- **Performance optimizations** - Faster pre-push hook execution
- **Documentation updates** - Complete redesign of project documentation

### Security
- **Enhanced cryptographic verification** - Stronger supply chain protection
- **Improved secret detection** - Advanced gitleaks integration
- **Better vulnerability scanning** - Multi-language vulnerability detection

---

## [0.1.0] - 2025-01-21

### 🎉 Initial Release

**1-Click Rust Security** - Enterprise-grade security controls for Rust projects, installed in seconds.

### Added

#### Core Features
- **25+ Security Controls** in pre-push hook validation
- **Cryptographic verification** for all components (SHA256 checksums)
- **Two-tier security architecture** (pre-push blocking + CI deep analysis)
- **Zero-configuration installation** with sensible defaults
- **Multi-project support** (Rust, non-Rust, hybrid projects)

#### Security Controls (Pre-Push Hook)
- Secret detection (AWS keys, GitHub tokens, API keys, private keys)
- Vulnerability scanning via cargo-deny
- GitHub Actions SHA pinning verification
- Test suite validation
- Code formatting enforcement
- License compliance checking
- Large file detection
- Commit signature verification
- Dependency version pinning checks
- Build script security analysis
- Documentation secret scanning
- Environment variable security
- Unsafe code monitoring
- File permission auditing
- Technical debt tracking
- And 10+ additional checks

#### Helper Tools
- **pinactlite** - Lightweight GitHub Actions pinning verifier and auto-pinner
- **gitleakslite** - Efficient secret scanner with configurable allow-listing

#### CI/CD Workflows
- Pinning validation workflow (ensures all actions are SHA-pinned)
- Shell script linting (shfmt + shellcheck)
- Documentation building and deployment
- End-to-end testing suite
- Installer self-test validation

#### Documentation
- Comprehensive README with quick-start guide
- Installation guide with multiple verification methods
- Architecture documentation
- Security controls reference
- Contributing guidelines
- YubiKey/Sigstore integration guide

#### Configuration
- Customizable security controls via `.security-controls/config.env`
- Secret detection allow-listing support
- Configurable tool selection (cargo-deny vs cargo-audit)
- Skip options for specific checks

### Security Features
- All GitHub Actions workflows use SHA-pinned actions
- Signed commits with Sigstore support
- Dependency lock file validation
- Supply chain attack prevention
- Comprehensive secret detection patterns

### Performance
- Pre-push validation completes in ~60 seconds
- Parallel execution of independent checks
- Smart caching for repeated operations
- Minimal overhead for developer workflow

### Platform Support
- Linux (primary)
- macOS (tested)
- Windows (via WSL)
- GitHub Actions CI/CD
- GitLab CI (basic support)

### Known Limitations
- Requires bash 4.0+
- Some Rust-specific checks require cargo toolchain
- GPG signature verification not yet implemented
- SBOM generation requires additional tools

---

### Installation

```bash
# Quick install with verification
curl -O https://raw.githubusercontent.com/h4x0r/1-click-rust-sec/main/install-security-controls.sh
curl -O https://raw.githubusercontent.com/h4x0r/1-click-rust-sec/main/install-security-controls.sh.sha256
sha256sum -c install-security-controls.sh.sha256
chmod +x install-security-controls.sh
./install-security-controls.sh
```

### Feedback

Please report issues at: https://github.com/h4x0r/1-click-rust-sec/issues

### Contributors

- Primary development team
- Open source community
- Security tool maintainers (cargo-deny, gitleaks, pinact)

---

[0.3.0]: https://github.com/h4x0r/1-click-github-sec/releases/tag/v0.3.0
[0.1.0]: https://github.com/h4x0r/1-click-rust-sec/releases/tag/v0.1.0