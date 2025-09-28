# This Repository's Security Architecture

This document describes the comprehensive security controls protecting the **1-Click GitHub Security** repository itself. These controls go beyond what the installer provides to end users, serving as both protection and validation for the installer project.

## 🎯 Overview

This repository implements a **"dogfooding plus philosophy"** approach:
- Uses everything the installer provides (35+ security controls)
- Adds development-specific security controls (5+ additional controls)
- Implements 6 specialized CI/CD workflows
- Maintains documentation and distribution security
- Provides reference implementation for security best practices

**Total Security Controls in This Repository: 40+ comprehensive security checks**

## 📊 Security Controls Comparison Tables

### Table 1: Controls Available in Both Installer and This Repo

| Control Type | Category | Description | Installer Provides | This Repo Has |
|-------------|----------|-------------|:-----------------:|:-------------:|
| **PRE-PUSH HOOK CONTROLS** |
| Secret Detection | Critical | Blocks AWS keys, GitHub tokens, API keys | ✅ | ✅ |
| Vulnerability Scan | Critical | Blocks known CVEs (cargo-deny) | ✅ | ✅ |
| Test Validation | Critical | Ensures tests pass | ✅ | ✅ |
| Format Check | Critical | Enforces code style (cargo fmt) | ✅ | ✅ |
| Linting | Critical | Catches bugs (clippy) | ✅ | ✅ |
| Large Files | Critical | Blocks files >10MB | ✅ | ✅ |
| SHA Pinning Check | Warning | Verifies GitHub Actions pins | ✅ | ✅ |
| Commit Signing | Warning | Verifies signatures | ✅ | ✅ |
| License Check | Warning | License compliance | ✅ | ✅ |
| Dependency Pinning | Warning | Ensures deps are pinned | ✅ | ✅ |
| Unsafe Code | Warning | Monitors unsafe blocks | ✅ | ✅ |
| Unused Dependencies | Warning | Detects unused deps | ✅ | ✅ |
| Build Scripts | Warning | Security analysis | ✅ | ✅ |
| Doc Secrets | Warning | Scans documentation | ✅ | ✅ |
| Env Variables | Warning | Hardcoding detection | ✅ | ✅ |
| Rust Edition | Warning | Edition specification | ✅ | ✅ |
| Import Security | Warning | Validates imports | ✅ | ✅ |
| File Permissions | Warning | Permission audit | ✅ | ✅ |
| Dependency Count | Warning | Monitors dep count | ✅ | ✅ |
| Network Addresses | Warning | IP/URL validation | ✅ | ✅ |
| Commit Messages | Warning | Message security | ✅ | ✅ |
| Tech Debt | Warning | TODO/FIXME tracking | ✅ | ✅ |
| Empty Files | Warning | Incomplete detection | ✅ | ✅ |
| Cargo.lock | Warning | Lock file validation | ✅ | ✅ |
| **HELPER TOOLS** |
| pinactlite | Tool | SHA pinning verifier | ✅ | ✅ |
| gitleakslite | Tool | Secret scanner | ✅ | ✅ |
| **CI/CD WORKFLOWS** |
| Basic Security | CI | Optional workflows | ✅ (optional) | ✅ |
| CodeQL Scanning | CI | Security code analysis | ✅ (with --github-security) | ✅ |
| **CONFIGURATION** |
| .security-controls/ | Config | Security configs | ✅ | ✅ |
| deny.toml | Config | Cargo deny config | ✅ | ✅ |
| .cargo/config.toml | Config | Cargo security | ✅ | ✅ |

### Table 2: Additional Controls ONLY in This Repository

| Control Type | Category | Description | Installer Has | This Repo Has | Why Not in Installer |
|-------------|----------|-------------|:-------------:|:-------------:|----------------------|
| **PRE-COMMIT HOOKS** |
| Trailing Whitespace | Formatting | Removes trailing spaces | ❌ | ✅ | Too opinionated for general use |
| End-of-File Fixer | Formatting | Ensures newline at EOF | ❌ | ✅ | Minor formatting preference |
| YAML Check | Validation | Validates YAML syntax | ❌ | ✅ | Not all projects use YAML |
| Large File Check | Validation | Pre-commit large file check | ❌ | ✅ | Redundant with pre-push |
| ShellCheck | Linting | Shell script validation | ❌ | ✅ | Development-specific |
| shfmt | Formatting | Shell script formatting | ❌ | ✅ | Development-specific |
| Markdown Lint | Linting | Markdown validation | ❌ | ✅ | Documentation-heavy repo |
| pinactlite Sync | Validation | Tool version sync | ❌ | ✅ | Installer development only |
| **CI/CD WORKFLOWS (SPECIALIZED)** |
| Pinning Validation | Security | Validates SHA pinning with pinact v3.4.2 | ❌ | ✅ | Development validation |
| Shell Lint | Quality | shellcheck + shfmt CI | ❌ | ✅ | Script-heavy development |
| Docs Build | Documentation | MkDocs site generation | ❌ | ✅ | Documentation repo |
| Docs Deploy | Documentation | GitHub Pages deployment | ❌ | ✅ | Documentation hosting |
| Helpers E2E | Testing | End-to-end tool testing | ❌ | ✅ | Tool development testing |
| Installer Self-Test | Testing | Installation validation | ❌ | ✅ | Installer development |
| Sync Validation | Testing | Tool consistency check | ❌ | ✅ | Development validation |
| **DEVELOPMENT TOOLS** |
| Pre-commit Framework | Tool | Pre-commit hook manager | ❌ | ✅ | Additional complexity |
| MkDocs | Tool | Documentation generator | ❌ | ✅ | Not needed by users |
| **DEPENDENCY MANAGEMENT** |
| **MANUAL GITHUB FEATURES** |
| Security Advisories | Security | Private vulnerability reporting | ❌ | ❌ | Requires manual web setup |
| Advanced Security | Security | Enterprise code scanning | ❌ | ❌ | GitHub Enterprise only |

## 📈 Summary Statistics

| Metric | Installer Provides | This Repository Has |
|--------|-------------------|---------------------|
| **Pre-push Checks** | 25+ | 25+ |
| **Pre-commit Checks** | 0 | 8 |
| **CI/CD Workflows** | 1-2 (optional), +1 with --github-security | 4 |
| **Helper Tools** | 2 | 2 + scripts |
| **Configuration Files** | 5 | 7 |
| **GitHub Security Features** | 6 with --github-security | 6 |
| **Total Security Controls** | ~35 with --github-security | ~40 |

## 🎯 Why the Difference?

The additional controls in this repository serve specific purposes:

1. **Development Validation**: Test the installer itself works correctly
2. **Documentation**: Build and deploy comprehensive docs
3. **Quality Assurance**: Ensure shell scripts are properly formatted
4. **Tool Synchronization**: Keep helper tools in sync
5. **Enhanced CI/CD**: Validate everything works end-to-end

Most projects don't need these development-specific controls, which is why the installer focuses on universal security controls that benefit all projects.

**NEW**: The installer now provides comprehensive GitHub security features with `--github-security`, bringing user repositories much closer to this repository's security level!

## 🛡️ Security Layers

### Layer 1: Pre-Push Controls (Local)

Same 25+ controls that users get, running via `.git/hooks/pre-push`:

**Enhanced with --github-security**: Users can now also get GitHub repository security features automatically configured.

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

Four specialized workflows for continuous validation:

#### 1. `quality-assurance.yml`
- **Purpose**: Comprehensive quality and functional validation with dogfooding plus compliance
- **Tools**: pinactlite, documentation validation scripts, functional synchronization
- **Jobs**:
  - Critical validation (dogfooding plus compliance)
  - Helper tools E2E testing
  - Installer self-testing
  - SHA pinning validation
  - Documentation validation
- **Security**: Validates repository implements ALL security controls from installer templates
- **Dogfooding Plus**: Ensures we use everything we provide to users

#### 2. `security-scan.yml`
- **Purpose**: Unified security scanning and threat detection
- **Tools**: CodeQL, Trivy, gitleaks, cargo-deny
- **Jobs**:
  - **SAST Analysis**: CodeQL static code analysis for JavaScript/TypeScript (blocking)
  - **Vulnerability Scanning**: Trivy filesystem vulnerability detection (blocking)
  - **Secret Detection**: Comprehensive gitleaks scanning with full repository history (blocking)
  - **Dependency Security**: cargo-deny security audit with license compliance (blocking)
  - **Supply Chain Security**: GitHub Actions pinning analysis and dependency integrity (blocking)
- **Security**: SARIF uploads to GitHub Security tab, comprehensive threat coverage, ALL BLOCKING
- **Architecture**: Parallel execution with zero-compromise security posture

#### 3. `docs.yml`
- **Purpose**: Documentation site generation and deployment
- **Tools**: MkDocs with Material theme, lychee link validation
- **Output**: GitHub Pages site deployment
- **Triggers**: Push to main, PR validation
- **Validation**: Cross-reference consistency, link checking

#### 4. `release.yml`
- **Purpose**: Automated release process with security validation
- **Dependencies**: Waits for Quality Assurance + Security Scanning workflows
- **Checks**: Version consistency, changelog updates, artifact generation
- **Security**: Cryptographic signing, checksum generation, supply chain protection
- **Artifacts**: Installer scripts, checksums, release notes with security focus

### Layer 4: Repository Configuration

#### Secret Detection (Two-Layer Defense)
- **gitleakslite** (local): ✅ Pre-push hook blocks secrets before they leave your machine
- **GitHub Secret Scanning**: ✅ Server-side detection and partner notification
- **GitHub Push Protection**: ✅ Additional blocking at GitHub level

#### GitHub Security Features (Enabled)
- Branch protection: ✅ Enabled (PR reviews required, status checks, admin enforcement)
- Issues tracking: ✅ Enabled
- Dependabot vulnerability alerts: ✅ Enabled via API
- Dependabot automated security fixes: ✅ Enabled via API
- Dependabot config: ✅ Present (GitHub Actions + Cargo)
- Code scanning: ✅ CodeQL workflow added

#### GitHub Features (Require Manual Web Interface)
- Security advisories: ❌ Not enabled (requires manual web setup)
- Advanced security: ❌ Not available (public repo)

#### Dependency Management
- `.github/dependabot.yml` - Config for GitHub Actions + Cargo updates
- `renovate.json` - Additional dependency management
- `deny.toml` - Cargo dependency policies
- `Cargo.lock` - Lock files for reproducible builds
- **Workflow**: Dependabot updates → pinactlite auto-pins → Secure updates

## 📊 Metrics & Monitoring

### Workflow Status Badges
All workflows display real-time status in README:
- Quality Assurance
- Documentation
- CodeQL Security Scanning
- Pinactlite Sync

### Performance Tracking
- Pre-push: ~60 seconds target
- Pre-commit: < 5 seconds
- CI workflows: < 5 minutes each

### Security Metrics
- 100% GitHub Actions pinned ✅
- 0 known vulnerabilities ✅
- Secret detection coverage ✅ (GitHub + gitleakslite)
- Push protection enabled ✅
- SLSA Level 2 compliance 🔄 (in progress)

## 🔧 Maintenance Workflows

### Documentation Synchronization Automation

The repository includes comprehensive automation to maintain documentation consistency:

**Automation Scripts:**
- `scripts/version-sync.sh` - Synchronizes version numbers across all files
- `scripts/count-controls.sh` - Audits actual security control counts vs marketing claims
- `scripts/validate-docs.sh` - Cross-reference and consistency validation
- `scripts/sync-security-controls.sh` - **NEW**: Functional synchronization of security controls

**CI Integration:**
- Documentation validation runs automatically in quality-assurance.yml workflow
- Prevents documentation drift through automated checks
- Validates version consistency, control counts, cross-references, and embedded documentation

**Maintenance Commands:**
```bash
# Check all documentation consistency
./scripts/validate-docs.sh

# Verify security control counts
./scripts/count-controls.sh

# Sync version across all files
./scripts/version-sync.sh --check

# Check functional synchronization (dogfooding plus validation)
./scripts/sync-security-controls.sh --check

# Apply missing security controls to repository
./scripts/sync-security-controls.sh --sync
```

### Functional Synchronization (Dogfooding Plus Implementation)

**Critical Issue Identified**: We had Trivy vulnerability scanning in installer templates but missing from our actual repository workflows. This violates our dogfooding plus philosophy.

**Functional Sync Tool**: `scripts/sync-security-controls.sh`
- **Purpose**: Ensures our repository implements ALL security controls that the installer provides to users
- **Philosophy**: "If it's not good enough for us, it's not good enough for users"
- **Process**: Extracts security controls from installer templates, compares with repo implementation, identifies gaps

**Sync Categories:**
1. **Installer → Repo**: Controls that should exist in both (vulnerability scanning, secret detection, etc.)
2. **Repo Only**: Development-specific controls (tool sync, docs, releases)
3. **Missing**: Controls in installer templates but missing from repo workflows

**Why This Matters:**
- **Quality Assurance**: We become alpha testers of our own security controls
- **Bug Discovery**: Issues surface in our development before user deployment
- **Trust Building**: Users can inspect our repository to see controls in action
- **Consistency**: Prevents functional drift between what we build and what we use

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
   ./scripts/version-sync.sh X.Y.Z
   ```

3. **Testing**:
   - All workflows must pass
   - E2E tests must pass
   - Documentation must build

4. **Release**:
   - Tag with version
   - Sign tag (Sigstore/gitsign)
   - Create GitHub release
   - Update checksums in release

## 🔐 Cryptographic Chain of Trust

```
Repository Security Chain:

┌─────────────────┐
│ Signed Commits  │ (Sigstore/gitsign)
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
- [Security Controls Architecture](architecture.md) - Technical design
- [Installation Guide](installation.md) - Setup instructions
- [4-Mode Signing Guide](installation.md#4-configure-commit-signing-4-modes-available) - Complete signing configuration
- [Workflow Sources](https://github.com/h4x0r/1-click-github-sec/tree/main/.github/workflows) - GitHub Actions workflows

### External References
- [GitHub Security Best Practices](https://docs.github.com/en/code-security)
- [SLSA Framework](https://slsa.dev/)
- [OpenSSF Scorecard](https://github.com/ossf/scorecard)

---

**Last Updated**: January 2025
**Maintained By**: Repository maintainers
**Security Contact**: security@[domain]