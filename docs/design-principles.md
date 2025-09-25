# CLAUDE.md - Design Principles for 1-Click GitHub Security

*Created by Albert Hui <albert@securityronin.com>*
*Security Ronin*

## 🎯 Project Mission

**1-Click GitHub Security** provides cryptographically verified, comprehensive security controls for multi-language projects with zero compromise on developer experience. We democratize enterprise-grade security for all development ecosystems - starting with Rust, Node.js, Python, and Go.

---

## 🏗️ Core Design Principles

### 1. **Security Without Compromise**
> "Security tools must be more secure than the problems they solve"

- **Cryptographic Verification First**: Every installer, update, and component must be cryptographically verified
- **No Pipe-to-Bash**: Force conscious verification before execution
- **Supply Chain Paranoia**: Assume all external dependencies are compromised until proven otherwise
- **Defense in Depth**: Multiple overlapping security controls, not single points of failure
- **Fail Secure**: When in doubt, block rather than allow

**Implementation Guidelines:**
- SHA256 checksums for all downloadable components
- GPG signatures for critical releases
- Signed commits for all repository changes
- Reproducible builds with deterministic outputs
- Audit trails for all security decisions

### 2. **Developer Experience as Security Feature**
> "Friction is the enemy of security adoption"

- **Sub-80 Second Pre-Push**: Fast feedback prevents security bypass behavior
- **Clear Fix Instructions**: Every failure provides specific remediation steps
- **Progressive Enhancement**: Start minimal, add security incrementally
- **Sensible Defaults**: Secure-by-default configuration requiring no expertise
- **Emergency Escape Hatches**: `--no-verify` available but discouraged

**Performance Budget:**
- Pre-push hook: < 60 seconds total
- Individual checks: < 30 seconds each
- Tool installation: < 5 minutes
- First-time setup: < 10 minutes

### 3. **Two-Tier Security Architecture**
> "Fast blocking for critical issues, comprehensive analysis for everything else"

**Pre-Push Tier (< 60s):**
- Blocks secrets, vulnerabilities, and critical policy violations
- Provides immediate feedback to developers
- Optimized for speed and zero false positives
- Essential security controls only

**Post-Push Tier (CI Pipeline):**
- Comprehensive security analysis and reporting
- SAST, vulnerability scanning, compliance checks
- Artifact generation (SBOMs, reports, metrics)
- Human review workflows

### 4. **Cryptographic Trust Model**
> "Trust but verify, with emphasis on verify"

**Chain of Trust:**
```
GPG Root Key → Repository Signing → Release Signing → Component Verification
```

**Verification Levels:**
1. **SHA256 Checksums**: Minimum verification (integrity)
2. **GPG Signatures**: Recommended verification (authenticity + integrity)  
3. **Repository Clone**: Maximum verification (full transparency)

**Trust Boundaries:**
- Package managers (cargo, npm, brew) - considered trusted
- GitHub releases - verify signatures
- Direct downloads - require checksums
- User-generated content - never trusted

### 5. **Ecosystem Integration**
> "Work with each language ecosystem, not against it"

- **Language-Native Tooling**: Leverage existing tooling and conventions for each language
  - **Rust**: Cargo, rustc, clippy, deny, audit
  - **Node.js**: npm, ESLint, Prettier, Snyk, retire.js
  - **Python**: pip, safety, bandit, black, flake8
  - **Go**: go toolchain, govulncheck, gofmt, golint
- **Standard Tool Chain**: Use community-standard security tools for each ecosystem
- **Backward Compatibility**: Don't break existing workflows in any language
- **Cross-Platform**: Support Linux, macOS, Windows (WSL) across all languages
- **CI/CD Friendly**: Integrate seamlessly with GitHub Actions, GitLab CI, etc.

### 6. **Observable Security**
> "Security you can't measure is security you don't have"

- **Comprehensive Logging**: All security decisions logged with context
- **Metrics Collection**: Performance, adoption, effectiveness metrics
- **Audit Trails**: Complete history of security control evolution
- **Reporting**: Clear, actionable security reports for all stakeholders
- **Alerting**: Proactive notification of security issues

### 7. **Single-Script Architecture**
> "True 1-click means zero external dependencies"

- **Standalone Installer**: Single shell script with no external dependencies
- **Built-in Components Only**: Uses only bash, curl, git, and standard Unix tools
- **Self-Contained Framework**: Error handling, logging, and rollback embedded within installer
- **Zero Configuration**: Works out-of-the-box on any Unix-like system
- **Offline Capable**: Core functionality works without internet (after initial download)

**Architectural Constraints:**
- No Python/Node.js/Ruby dependencies
- No package manager requirements beyond system defaults
- No external configuration files or databases
- No separate framework or library installations
- No multi-file deployments or complex directory structures

**Benefits:**
- **Universal Compatibility**: Works on any system with bash 3.2+
- **Zero Installation Friction**: Download one file, run one command
- **Corporate Firewall Friendly**: No complex dependency resolution
- **Airgap Compatible**: Can be transferred and run offline
- **Minimal Attack Surface**: No external code execution or network dependencies

**Implementation Strategy:**
- Embed all framework code directly in `install-security-controls.sh`
- Use bash built-ins and standard Unix utilities only
- Inline all configuration and templates as heredocs
- Self-contained error handling, logging, and rollback systems
- Progressive enhancement: add features without breaking simplicity

### 8. **Dogfooding Plus Philosophy**
> "If it's not good enough for us, it's not good enough for users"

- **Repository as Alpha Test**: This repository implements ALL security controls that the installer provides to users
- **Enhanced Development Controls**: Additional controls specific to our development needs (tool sync, docs, releases)
- **Functional Synchronization**: Automated verification that repo controls match installer templates
- **Quality Assurance Through Use**: We discover issues in our daily development before users encounter them
- **Trust Through Transparency**: Users can inspect our repository to see security controls in action

**Implementation Requirements:**
- Every security control in installer templates must exist in repository workflows
- Repository-only controls are clearly documented and justified
- Automated sync tools prevent functional drift between installer and repository
- Regular audits ensure dogfooding plus philosophy is maintained

**Benefits:**
- **Rapid Bug Discovery**: Issues surface during development before user deployment
- **Continuous Validation**: Daily development workflow validates security control effectiveness
- **User Trust**: Transparent demonstration of security controls in practice
- **Quality Assurance**: Maintains high standards through self-use

---

## 🔧 Implementation Standards

### Code Quality
- **Rust Best Practices**: Idiomatic Rust code following community standards
- **Security-First**: All code assumes hostile input and environments
- **Error Handling**: Comprehensive error handling with user-friendly messages
- **Testing**: Unit, integration, and security tests for all components
- **Documentation**: Inline documentation explaining security decisions

### Engineering Best Practices
> "Quality code is security code"

**Core Programming Principles:**
- **DRY (Don't Repeat Yourself)**: Extract common patterns into reusable functions/modules
- **YAGNI (You Aren't Gonna Need It)**: Implement only what's needed now, avoid over-engineering
- **KISS (Keep It Simple, Stupid)**: Choose simple solutions over complex ones when both work
- **SINE (Simple Is Not Easy)**: Simple solutions require more effort and thought than complex ones
- **Single Responsibility**: Each function/module has one clear purpose
- **No Special Cases**: Design general solutions rather than hardcoded exceptions
- **Fail Fast**: Validate inputs early and provide clear error messages
- **Immutable by Default**: Prefer immutable data structures and functional approaches

**External Integration Standards:**
- **Documentation-First**: Study API documentation thoroughly before implementation
- **Version Pinning**: Always pin external dependencies to specific versions
- **Graceful Degradation**: Handle external service failures without breaking core functionality
- **Rate Limiting**: Respect external API limits and implement backoff strategies
- **Timeout Handling**: Set reasonable timeouts for all external calls

**Code Organization:**
- **Modular Architecture**: Organize code into logical, testable modules
- **Clear Interfaces**: Define explicit contracts between components
- **Separation of Concerns**: Keep business logic separate from I/O operations
- **Configuration Management**: Externalize configuration, never hardcode values
- **Resource Management**: Proper cleanup of files, connections, and other resources

**Security-Focused Development:**
- **Input Validation**: Validate all inputs at system boundaries
- **Least Privilege**: Request minimal permissions necessary
- **Defense in Depth**: Layer multiple validation and security checks
- **Audit Trail**: Log security-relevant operations with sufficient detail
- **Secret Management**: Never commit secrets; use secure storage mechanisms

**Performance and Reliability:**
- **Early Optimization**: Profile before optimizing, measure impact
- **Caching Strategy**: Cache expensive operations with proper invalidation
- **Memory Management**: Be conscious of memory usage and potential leaks
- **Concurrent Safety**: Design for thread safety when applicable
- **Idempotency**: Operations should be safe to retry

### Tool Integration
- **Tool Selection Criteria**:
  - Community adoption and maintenance
  - Performance characteristics
  - Integration complexity
  - False positive rates
  - Security effectiveness

- **Tool Configuration**:
  - Sensible security-focused defaults
  - Customizable for different project needs
  - Performance-optimized settings
  - Clear documentation of trade-offs

### Performance Requirements
- **Pre-Push Hook Performance**:
  - Total time: < 60 seconds
  - Individual tools: < 30 seconds
  - Parallel execution where possible
  - Caching for repeated operations

- **Installation Performance**:
  - Full setup: < 10 minutes
  - Tool downloads: Progress indicators
  - Network resilience: Retry logic
  - Offline operation: Cached tools when possible

---

## 📋 Security Control Framework

### Control Categories

**Tier 1 - Critical (Pre-Push Blocking)**
- Secret detection (gitleaks)
- Known vulnerabilities (cargo-deny)
- Code quality (cargo clippy)
- Test failures (cargo test)
- License violations (cargo-deny)
- Supply chain attacks (pinact)

**Tier 2 - Important (CI Analysis)**
- Static analysis (Semgrep, CodeQL)
- Unsafe code detection (cargo-geiger)
- SBOM generation (cargo-auditable)
- Compliance checks (various)
- Security metrics (OpenSSF Scorecard)

**Tier 3 - Valuable (Optional/Advanced)**
- Fuzzing (cargo-fuzz)
- Binary analysis
- Container scanning
- Infrastructure analysis

### Control Selection Criteria

**Pre-Push Controls Must:**
- Execute in < 30 seconds individually
- Have < 1% false positive rate
- Block genuine security risks
- Provide clear remediation guidance
- Work reliably across platforms

**CI Controls May:**
- Take longer execution time
- Generate complex reports
- Require human review
- Have higher false positive rates
- Depend on external services

---

## 🎨 User Experience Principles

### Installation Experience
- **Verification-First**: Never allow unverified execution
- **Progressive Disclosure**: Show basic options first, advanced on request
- **Sensible Defaults**: Work out-of-the-box for 80% of projects
- **Clear Feedback**: Progress indicators and status messages
- **Graceful Degradation**: Partial installation better than complete failure

### Developer Workflow
- **Invisible When Working**: Security runs automatically without intervention
- **Visible When Broken**: Clear, actionable error messages with fixes
- **Respectful of Time**: Fast feedback loops, no waiting
- **Learning Oriented**: Help developers understand security concepts
- **Emergency Friendly**: Bypass mechanisms for critical fixes

### Error Messages and Guidance
```bash
❌ Security vulnerabilities found in dependencies
   
   Affected crates:
   • serde_json 1.0.50 (RUSTSEC-2020-0001: Stack overflow in Value::clone)
   
   Fix: cargo update serde_json
   
   For emergency bypass: git push --no-verify
   (Use bypass only for critical hotfixes)
```

---

## 🚀 Development Workflow

### Adding New Security Controls

**Evaluation Criteria:**
1. **Security Value**: Does it prevent real attacks?
2. **Performance Impact**: Fits within tier performance budgets?
3. **False Positive Rate**: < 1% for pre-push, < 10% for CI?
4. **Community Adoption**: Widely used and maintained?
5. **Integration Complexity**: Reasonable implementation effort?
6. **Single-Script Compatibility**: Can be embedded without external dependencies?

**Implementation Process:**
1. **Research**: Tool capabilities, community feedback, alternatives
2. **Prototype**: Minimal implementation and testing
3. **Performance Test**: Measure impact on different project sizes
4. **Documentation**: Update architecture and usage documentation
5. **Rollout**: Gradual deployment with monitoring

### Preserving Single-Script Architecture

**Critical Design Decision**: The installer must remain a single, standalone shell script with zero external dependencies.

**Why This Matters:**
- **Enterprise Adoption**: Corporate environments often restrict external dependencies
- **Security Posture**: Minimizes attack surface and supply chain risks
- **Reliability**: No complex dependency resolution or version conflicts
- **Universality**: Works on any Unix-like system without preparation

**Development Guidelines:**
- **Embed, Don't Import**: All framework code must be inline within the installer
- **Standard Tools Only**: bash, curl, git, awk, sed - no Python/Node.js/Ruby
- **Self-Contained Templates**: Use heredocs for all configuration templates
- **No External Files**: All logic, configuration, and data embedded in script
- **Progressive Degradation**: Features work without internet when possible

**Rejected Approaches:**
- ❌ Separate framework files that must be sourced
- ❌ Package manager dependencies (pip, npm, gem)
- ❌ External configuration databases or files
- ❌ Multi-file installer packages
- ❌ Docker containers or virtual environments

**Approved Enhancements:**
- ✅ Embedded error handling frameworks
- ✅ Inline logging and rollback systems
- ✅ Heredoc-based configuration templates
- ✅ Built-in retry and timeout mechanisms
- ✅ Self-contained testing and validation

### Testing Strategy
- **Unit Tests**: Individual component functionality
- **Integration Tests**: End-to-end workflow validation
- **Performance Tests**: Timing and resource usage
- **Security Tests**: Verify security controls actually work
- **User Acceptance Tests**: Real-world usage scenarios

### Release Process
1. **Version Bumping**: Semantic versioning (security fixes = patch)
2. **Testing**: Full test suite on multiple platforms
3. **Documentation**: Update all relevant documentation
4. **Signing**: GPG sign all release artifacts
5. **Checksums**: Generate and publish SHA256 hashes
6. **Announcement**: Security-focused release notes

---

## 🏛️ Architectural Decision Records (ADRs)

Our design philosophy represents formal architectural decisions that guide all development. These decisions are captured across multiple documents:

### ADR-001: Single-Script Architecture (CLAUDE.md § 7)
**Decision**: Installer must be a single shell script with zero external dependencies
**Status**: ✅ Accepted
**Context**: Enterprise adoption, security posture, reliability, universality
**Consequences**:
- ✅ Works in any Unix environment without preparation
- ✅ Minimal attack surface and supply chain risks
- ❌ Cannot use external frameworks or multi-file architectures
- ❌ All functionality must be embedded inline

### ADR-002: External Service Rejection (README.md § Design Philosophy)
**Decision**: Reject security tools requiring external account registration or GitHub App installation
**Status**: ✅ Accepted
**Context**: True 1-click installation requires zero out-of-band setup
**Consequences**:
- ✅ Works identically for personal and organizational repositories
- ✅ No corporate approval barriers or individual friction
- ❌ Cannot integrate with Socket.dev, Snyk Cloud, Semgrep Cloud
- ❌ Limited to GitHub-native and downloadable tools

### ADR-003: GitHub-Native Tool Preference (Multiple Documents)
**Decision**: Prefer GitHub-native security features over third-party services
**Status**: ✅ Accepted
**Context**: Zero setup, universal availability, no external dependencies
**Consequences**:
- ✅ CodeQL, Dependabot, secret scanning work immediately
- ✅ No authentication or configuration required
- ❌ Limited to GitHub's security feature set
- ❌ Cannot leverage specialized third-party analytics

### ADR-004: Performance Budget for Pre-Push (CLAUDE.md § 2)
**Decision**: Pre-push hook must complete in under 60 seconds total
**Status**: ✅ Accepted
**Context**: Developer experience is a security feature - friction leads to bypass
**Consequences**:
- ✅ Fast feedback prevents security bypass behavior
- ✅ Parallel execution and caching required
- ❌ Cannot run comprehensive analysis in pre-push
- ❌ Deep scanning must be deferred to CI tier

### ADR-005: Cryptographic Verification First (CLAUDE.md § 1)
**Decision**: Every installer, update, and component must be cryptographically verified
**Status**: ✅ Accepted
**Context**: Security tools must be more secure than problems they solve
**Consequences**:
- ✅ SHA256 checksums for all downloadable components
- ✅ Supply chain attack prevention
- ❌ Additional complexity in release process
- ❌ Cannot use tools without verifiable checksums

### ADR-006: Multi-Language Universal Design (CLAUDE.md § 5)
**Decision**: Work with each language ecosystem, not against it
**Status**: ✅ Accepted
**Context**: Leverage existing tooling and conventions for maximum effectiveness
**Consequences**:
- ✅ Use cargo for Rust, npm for Node.js, pip for Python, etc.
- ✅ Backward compatibility with existing workflows
- ❌ More complex installer logic for language detection
- ❌ Must maintain expertise across multiple ecosystems

### Decision Documentation Strategy

**Primary Documentation**: CLAUDE.md (authoritative design principles)
**User Documentation**: README.md (philosophy explanation with examples)
**Technical Documentation**: SECURITY_CONTROLS_ARCHITECTURE.md (implementation details)

**Review Process**: All architectural decisions must align with documented principles
**Change Process**: Principle changes require updating all three documents
**Rationale Capture**: Tool inclusion/rejection decisions documented with specific principle violations

---

## 📊 Success Metrics

### Security Effectiveness
- Vulnerabilities blocked (pre-push)
- Secrets prevented from reaching repositories
- Compliance violations caught
- Supply chain attacks prevented
- Time to security issue resolution

### Developer Experience
- Pre-push hook performance (< 60s target)
- Installation success rate (> 95% target)
- False positive rates (< 1% pre-push, < 10% CI)
- Developer satisfaction surveys
- Security tool adoption rates

### Ecosystem Impact
- Projects using 1-click-rust-sec
- Security issues prevented ecosystem-wide  
- Community contributions and feedback
- Enterprise adoption metrics
- Integration with other security tools

---

## 🔮 Future Vision

### ✅ **Recently Implemented (v0.3.7)**
- ✅ **Multi-language support** - Rust, Node.js, Python, Go, Java, Generic projects
- ✅ **Advanced SAST integration** - CodeQL + Trivy defense-in-depth
- ✅ **Enhanced CI/CD integrations** - 6 specialized workflows with comprehensive security
- ✅ **Documentation synchronization** - Automated consistency validation
- ✅ **Functional synchronization** - Dogfooding plus philosophy implementation
- ✅ **Container security controls** - Trivy vulnerability scanning
- ✅ **GitHub security features** - Dependabot, CodeQL, secret scanning, branch protection

### Short-Term (3-6 months)
- **Enterprise policy management** - Custom policy templates and enforcement
- **Performance optimizations** - Sub-30 second pre-push targets
- **Community ecosystem** - Plugin system for custom security controls
- **SLSA Level 3 compliance** - Enhanced supply chain security
- **Security metrics dashboard** - Real-time security posture visualization

### Medium-Term (6-12 months)
- **AI-assisted security analysis** - LLM-powered vulnerability assessment
- **Automated security remediation** - Self-healing security controls
- **Zero-trust architecture patterns** - Advanced access control frameworks
- **WebAssembly sandbox** - Isolated execution for untrusted code
- **Formal verification** - Mathematical proof of critical security properties

### Long-Term (1-2 years)
- **Predictive vulnerability detection** - Machine learning for threat prediction
- **Industry standard compliance automation** - SOC2, FedRAMP, NIST frameworks
- **Cross-platform mobile support** - iOS/Android security control integration
- **Blockchain integration** - Immutable security audit trails
- **Quantum-resistant cryptography** - Future-proof security algorithms

---

## 🤝 Community Guidelines

### Contribution Principles
- **Security First**: All contributions must maintain or improve security posture
- **Performance Conscious**: Consider impact on developer workflow
- **Backward Compatible**: Don't break existing installations
- **Well Tested**: Include tests demonstrating security effectiveness
- **Documented**: Explain security rationale and trade-offs

### Code Review Standards
- **Security Review**: All changes reviewed for security implications
- **Performance Review**: Timing impact measured and approved
- **Usability Review**: Consider developer experience impact
- **Documentation Review**: Ensure guides remain accurate

### Issue Triage
- **Security Issues**: Highest priority, private disclosure process
- **Performance Regressions**: High priority, block releases
- **Feature Requests**: Evaluated against design principles
- **Bug Reports**: Prioritized by user impact

---

## 🔒 Security Considerations for Development

### Development Environment Security
- Use signed commits for all changes
- Require 2FA for all maintainers
- Regular security audits of the development process
- Secure key management for signing operations
- Principle of least privilege for repository access

### Third-Party Dependencies
- All dependencies security audited before inclusion
- Prefer dependencies with active maintenance
- Pin specific versions with hash verification
- Regular dependency updates with security review
- Alternative dependencies evaluated for critical components

### Release Security
- Reproducible builds with deterministic outputs
- Multiple independent verification of releases
- Signed releases with published checksums
- Security-focused release notes highlighting security changes
- Post-release monitoring for security issues

---

## 📝 Maintenance Philosophy

### Tool Lifecycle Management
- **Evaluation**: Continuous assessment of tool effectiveness
- **Integration**: Thoughtful integration minimizing disruption
- **Maintenance**: Regular updates and security patches
- **Deprecation**: Graceful removal when tools become obsolete
- **Migration**: Smooth transitions between tool versions

### Breaking Changes
- **Avoid When Possible**: Maintain backward compatibility
- **Migrate Gradually**: Provide migration paths and tools
- **Communicate Clearly**: Advanced notice and documentation
- **Support Legacy**: Maintain security updates for previous versions
- **Learn from Experience**: Feedback-driven improvement process

---

**This document serves as the foundation for all development decisions in 1-click-github-sec. When in doubt, refer to these principles to guide technical and product choices.**

---

*Last Updated: January 2025*
*Version: 1.1.0*
*Maintainers: @4n6h4x0r and community contributors*