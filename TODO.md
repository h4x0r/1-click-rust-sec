# 1-Click Rust Security - TODO

## 🚀 JavaScript/TypeScript Security Controls Implementation

### Research Findings

#### Current State Analysis
- ✅ Project already has `--non-rust` flag that sets `RUST_PROJECT=false`
- ✅ Provides "generic" security controls for non-Rust projects (basic)
- ✅ Node.js projects acknowledged (node_modules filtering) but no npm-specific controls
- ❌ No actual npm security controls implemented yet

#### npm/JavaScript/TypeScript Security Landscape 2024-2025
- **Critical**: JavaScript ecosystem faced "Shai-Hulud" worm compromising 18+ foundational npm packages
- **Evolution**: Sophisticated supply chain attacks require AI-based detection tools
- **Gap**: No direct cargo-deny equivalent exists for npm ecosystem
- **Best Alternative**: Semgrep Supply Chain provides closest functionality

### Recommended Security Controls

#### Pre-Push Tier (Fast, <60s total)
1. **`npm audit --audit-level high`** - Essential vulnerability scanning (~10s)
2. **`npm outdated --depth=0`** - Check for outdated dependencies (~5s)
3. **License compliance** with `license-checker-rseidelsohn` (~10s)
4. **Unused dependencies** with `depcheck` (~15s)
5. **Basic SAST** with `eslint-plugin-sonarjs` (~15s)
6. **Package.json validation** - Check for suspicious scripts (~5s)

#### CI Tier (Comprehensive Analysis)
1. **`semgrep --config=p/javascript-audit`** - Advanced SAST
2. **Supply chain security** with Socket.dev or Snyk
3. **OSSF Scorecard** for dependency security metrics
4. **Comprehensive license reporting**
5. **SBOM generation** for transparency

#### Additional No-Brainer Controls
- **Lockfile validation** - Ensure package-lock.json/yarn.lock consistency
- **Script security** - Check for suspicious npm scripts in package.json
- **Typosquatting detection** - Check for suspicious package names (TypoSmart)
- **Bundle size monitoring** - Detect unexpectedly large dependencies
- **Postinstall script auditing** - Flag packages with postinstall scripts
- **Malicious package detection** - Socket.dev API real-time scanning

### Essential Tools Research

#### Tier 1 (Pre-Push, <30s each)
- **npm audit** - Built-in vulnerability scanning
- **Snyk CLI** - Fast vulnerability detection with lockfile v3 support
- **audit-ci** - CI-optimized auditing for npm/yarn/pnpm
- **Socket.dev API** - Real-time malicious package detection

#### Tier 2 (CI Pipeline)
- **Semgrep Supply Chain** - Comprehensive dependency intelligence with reachability analysis
- **Snyk Open Source** - Deep vulnerability analysis with automated remediation
- **OSSF Scorecard** - Supply chain security metrics for dependencies
- **TypoSmart** - Advanced typosquatting detection (86% malware detection rate)

#### License Compliance Tools
- **license-checker-rseidelsohn** - Enhanced version of original license-checker
- **license-report** - Comprehensive license reporting (actively maintained)
- **Semgrep Supply Chain** - Integrated license compliance enforcement

#### Static Analysis (SAST)
- **Semgrep** - Most comprehensive, supports custom rules, license compliance
- **CodeQL** - Advanced semantic analysis (GitHub native)
- **eslint-plugin-sonarjs** - Actively maintained SonarSource rules

### Implementation Strategy

#### Phase 1: Essential Pre-Push Security
- [ ] Implement `npm audit` with `--audit-level high`
- [ ] Add Socket.dev integration for malicious package detection
- [ ] Include `license-checker-rseidelsohn` for license compliance
- [ ] Add `eslint-plugin-sonarjs` for basic SAST
- [ ] Implement package.json script validation

#### Phase 2: Enhanced CI Security
- [ ] Deploy Semgrep Supply Chain full integration
- [ ] Add OSSF Scorecard integration
- [ ] Implement CodeQL or Snyk Code for deep SAST
- [ ] Set up automated dependency updates with security review

#### Phase 3: Advanced Supply Chain Protection
- [ ] Deploy TypoSmart for typosquatting detection
- [ ] Create custom Semgrep rules for project-specific patterns
- [ ] Implement SBOM generation and monitoring
- [ ] Add continuous security metrics collection

### Implementation Questions

#### Architecture Decisions
1. **Flag Design**: Should we add specific `--javascript`/`--typescript` flags, or enhance existing `--non-rust` to auto-detect JS/TS projects?

2. **Package Manager Support**: Support npm, yarn, and pnpm, or focus on one initially?
   - npm (most common)
   - yarn (performance focus)
   - pnpm (security focus, disables postinstall scripts by default)

3. **Tool Installation Strategy**: Auto-install npm security tools or require user installation?
   - Auto-install: Better UX, potential version conflicts
   - User-install: More control, requires documentation

4. **Integration Level**: Separate mode vs integrate with existing non-rust mode?
   - Separate: Clean separation, more flags
   - Integrated: Simpler UX, auto-detection logic needed

#### Performance Considerations
- **ESLint + Security Plugins**: 5-15s typical
- **Semgrep Fast Rules**: 10-30s depending on codebase size
- **npm audit**: 3-10s for most projects
- **Socket.dev API**: 2-5s per package check

#### Detection Strategy
Auto-detect JavaScript/TypeScript projects by checking for:
- [ ] `package.json` existence
- [ ] `node_modules/` directory
- [ ] `*.js`, `*.ts`, `*.jsx`, `*.tsx` files
- [ ] `yarn.lock`, `package-lock.json`, `pnpm-lock.yaml`

### Code Architecture Changes Needed

#### Variables to Add
```bash
JAVASCRIPT_PROJECT=false
TYPESCRIPT_PROJECT=false
PACKAGE_MANAGER="" # npm, yarn, pnpm
NODE_MODULES_EXISTS=false
```

#### Functions to Implement
- `detect_javascript_project()`
- `detect_package_manager()`
- `install_npm_security_tools()`
- `run_npm_audit()`
- `check_npm_licenses()`
- `validate_package_json()`
- `check_unused_dependencies()`

#### Pre-Push Hook Integration
Add JavaScript/TypeScript specific checks to existing pre-push validation pipeline.

#### Configuration Files
- `.security-controls/js-config.env` - JavaScript-specific settings
- `.security-controls/npm-allowlist.txt` - Allowed npm packages/licenses
- `.security-controls/eslint-security.json` - ESLint security configuration

---

## 🔍 Outstanding Issues

### README Link Question
- [ ] **User Question**: "is it common to prominently disable link to gh-page of the project in README?"
  - Need clarification on which specific link is being referenced
  - Should review README.md for any disabled/commented gh-pages links
  - Assess if any links need to be re-enabled or updated

### Technical Debt
- [ ] Review and potentially address remaining minor shellcheck warnings
- [ ] Consider implementing cargo.toml unused config warnings cleanup
- [ ] Evaluate performance optimizations for large JavaScript projects

---

## 📋 Next Steps

1. **Immediate**: Clarify README gh-pages link question
2. **Short-term**: Implement Phase 1 JavaScript/TypeScript security controls
3. **Medium-term**: Full npm ecosystem support with advanced supply chain protection
4. **Long-term**: Consider support for other languages (Python, Go, etc.)

---

*Last Updated: 2025-09-23*
*Created by: Claude Code Assistant*