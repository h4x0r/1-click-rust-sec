# This Repository's Security Architecture

This document describes the comprehensive security controls protecting the **1-Click Rust Security** repository itself. These controls go beyond what the installer provides to end users, serving as both protection and validation for the installer project.

## 🎯 Overview

This repository implements a **"dogfooding plus"** approach:
- Uses everything the installer provides
- Adds development-specific security controls
- Implements testing and validation workflows
- Maintains documentation and distribution security

## 🛡️ Security Layers

### Layer 1: Pre-Push Controls (Local)

Same 25+ controls that users get, running via `.git/hooks/pre-push`:

**Blocking Controls:**
- Secret detection (gitleakslite)
- Vulnerability scanning (cargo-deny)
- Test validation
- Format enforcement
- Linting (clippy)
- Large file prevention

**Warning Controls:**
- GitHub Actions SHA pinning
- Commit signatures
- License compliance
- Dependency pinning
- Unsafe code monitoring
- Plus 14 additional checks

### Layer 2: Pre-Commit Controls (Local)

Additional controls via `.pre-commit-config.yaml`:

```yaml
repos:
  - pre-commit-hooks:
    - trailing-whitespace
    - end-of-file-fixer
    - check-yaml
    - check-added-large-files

  - shellcheck-py:
    - shellcheck for bash/sh scripts

  - pre-commit-shfmt:
    - Shell formatting (2-space indent)

  - markdownlint-cli:
    - Markdown linting

  - local:
    - pinactlite sync verification
```

### Layer 3: CI/CD Workflows (GitHub Actions)

Seven specialized workflows for continuous validation:

#### 1. `pinning-validation.yml`
- **Purpose**: Ensures all GitHub Actions use SHA pins
- **Tools**: Official pinact v3.4.2 with cryptographic verification
- **Verification**:
  - Cosign signature verification
  - OpenSSL signature verification (defense in depth)
  - SHA256 checksum verification
  - SLSA provenance validation

#### 2. `shell-lint.yml`
- **Purpose**: Validates all shell scripts
- **Tools**: shellcheck + shfmt
- **Checks**: Syntax, style, security patterns

#### 3. `docs-build.yml` & `docs-deploy.yml`
- **Purpose**: Documentation site generation and deployment
- **Tools**: MkDocs with Material theme
- **Output**: GitHub Pages site

#### 4. `helpers-e2e.yml`
- **Purpose**: End-to-end testing of helper tools
- **Tests**: pinactlite and gitleakslite functionality
- **Coverage**: Detection, auto-fixing, edge cases

#### 5. `installer-self-test.yml`
- **Purpose**: Validates installer integrity
- **Tests**: Installation scenarios, flag combinations
- **Environments**: Multiple OS versions

#### 6. `sync-pinactlite.yml`
- **Purpose**: Ensures tool version consistency
- **Checks**: Script synchronization between installer and repo

### Layer 4: Repository Configuration

#### Branch Protection
- Require PR reviews
- Require status checks to pass
- Require branches to be up to date
- Include administrators in restrictions

#### Security Features
- Dependabot security updates
- Secret scanning enabled
- Code scanning alerts
- Security advisories enabled

#### Dependency Management
- `.github/dependabot.yml` - Automated updates
- `renovate.json` - Additional dependency management
- `deny.toml` - Cargo dependency policies
- Lock files for reproducible builds

## 📊 Metrics & Monitoring

### Workflow Status Badges
All workflows display real-time status in README:
- Pinning Validation
- Shell Lint
- Docs Deploy
- Helpers E2E

### Performance Tracking
- Pre-push: ~60 seconds target
- Pre-commit: < 5 seconds
- CI workflows: < 5 minutes each

### Security Metrics
- 100% GitHub Actions pinned
- 0 known vulnerabilities
- 100% secret detection coverage
- SLSA Level 2 compliance

## 🔧 Maintenance Workflows

### Adding New Security Controls

1. **For installer (affects users)**:
   - Update installer script
   - Test in multiple environments
   - Update documentation
   - Version bump

2. **For this repository only**:
   - Add to appropriate workflow
   - Update this document
   - No version bump needed

### Testing Changes

```bash
# Local testing
./install-security-controls.sh --dry-run

# Pre-commit testing
pre-commit run --all-files

# Workflow testing
act -j <job-name>  # Using act for local workflow testing
```

### Release Process

1. **Security verification**:
   ```bash
   # Update checksums
   sha256sum install-security-controls.sh > install-security-controls.sh.sha256
   sha256sum yubikey-gitsign-toggle.sh > yubikey-gitsign-toggle.sh.sha256
   ```

2. **Version update**:
   ```bash
   ./scripts/bump-version.sh X.Y.Z
   ```

3. **Testing**:
   - All workflows must pass
   - E2E tests must pass
   - Documentation must build

4. **Release**:
   - Tag with version
   - Sign tag (GPG/Sigstore)
   - Create GitHub release
   - Update checksums in release

## 🔐 Cryptographic Chain of Trust

```
Repository Security Chain:

┌─────────────────┐
│ Signed Commits  │ (Sigstore/GPG)
└────────┬────────┘
         │
┌────────▼────────┐
│ SHA256 Checksums│ (Installer verification)
└────────┬────────┘
         │
┌────────▼────────┐
│ Pinned Actions  │ (SHA references)
└────────┬────────┘
         │
┌────────▼────────┐
│ Tool Signatures │ (Cosign verification)
└────────┬────────┘
         │
┌────────▼────────┐
│ SLSA Provenance │ (Build attestation)
└─────────────────┘
```

## 🚨 Incident Response

### Security Issue Detected

1. **Immediate Actions**:
   - Disable affected workflows
   - Revoke compromised credentials
   - Alert maintainers

2. **Investigation**:
   - Review audit logs
   - Check commit signatures
   - Verify checksums

3. **Remediation**:
   - Fix vulnerability
   - Update security controls
   - Document incident

### Compromised Dependency

1. **Detection** via:
   - Dependabot alerts
   - cargo-deny failures
   - Manual audit

2. **Response**:
   - Pin to last known good version
   - Find alternative if critical
   - Update deny.toml rules

## 📋 Security Checklist for Maintainers

### Daily
- [ ] Check workflow status badges
- [ ] Review Dependabot alerts
- [ ] Monitor issue reports

### Weekly
- [ ] Review PR security impact
- [ ] Update dependencies
- [ ] Check security advisories

### Monthly
- [ ] Full security audit
- [ ] Performance review
- [ ] Documentation updates

### Release
- [ ] Update all checksums
- [ ] Sign release artifacts
- [ ] Test on clean environment
- [ ] Update security documentation

## 🔄 Continuous Improvement

### Feedback Loops
- User issue reports → Security improvements
- CI failures → Control refinements
- Performance metrics → Optimization
- Security research → New controls

### Innovation Areas
- WebAssembly sandbox for untrusted code
- Machine learning for anomaly detection
- Formal verification of critical paths
- Zero-trust architecture patterns

---

## 📚 Additional Resources

### Internal Documentation
- [CONTRIBUTING.md](CONTRIBUTING.md) - Development guidelines
- [ARCHITECTURE.md](SECURITY_CONTROLS_ARCHITECTURE.md) - Technical design
- [.github/workflows/](.github/workflows/) - Workflow sources

### External References
- [GitHub Security Best Practices](https://docs.github.com/en/code-security)
- [SLSA Framework](https://slsa.dev/)
- [OpenSSF Scorecard](https://github.com/ossf/scorecard)

---

**Last Updated**: January 2025
**Maintained By**: Repository maintainers
**Security Contact**: security@[domain]