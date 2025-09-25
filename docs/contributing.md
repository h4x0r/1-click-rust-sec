# Contributing to 1-Click GitHub Security

Thank you for your interest in contributing to 1-Click GitHub Security! We welcome contributions that improve security for multi-language development ecosystems.

## 🎯 Our Mission

To provide enterprise-grade security controls that are:
- **Easy to install** - One command, zero configuration
- **Fast to execute** - ~60 second pre-push validation
- **Comprehensive** - Cover all major attack vectors
- **Developer-friendly** - Clear feedback, minimal friction

## 📋 Ways to Contribute

### 1. Security Controls
- Add new security checks to the pre-push hook
- Improve detection patterns for existing checks
- Optimize performance of security validations
- Add support for new security tools

### 2. Multi-Language Support
- Add security controls for new programming languages
- Improve existing language-specific integrations (Rust, Node.js, Python, Go, Java)
- Integrate additional security scanners for specific ecosystems
- Improve CI/CD pipeline integrations
- Add IDE plugin support

### 3. Documentation
- Improve installation guides
- Add troubleshooting sections
- Create video tutorials
- Translate documentation

### 4. Bug Reports & Features
- Report security issues (see Security Policy)
- Report bugs with reproduction steps
- Suggest new features with use cases
- Improve error messages

## 🚀 Development Setup

### Prerequisites
- Bash 4.0+
- Git 2.20+
- ShellCheck and shfmt (for shell script linting)
- Language toolchains for testing (optional):
  - Rust toolchain (cargo, rustc, clippy)
  - Node.js (npm, node)
  - Python (pip, python3)
  - Go (go toolchain)
  - Java (mvn, gradle)

### Local Development

1. **Fork and clone the repository**
```bash
git clone https://github.com/YOUR_USERNAME/1-click-github-sec.git
cd 1-click-github-sec
```

2. **Create a feature branch**
```bash
git checkout -b feature/your-feature-name
```

3. **Make your changes**
- Follow existing code style
- Add tests for new functionality
- Update documentation as needed

4. **Test your changes**
```bash
# Run the installer in dry-run mode
./install-security-controls.sh --dry-run

# Test language-specific modes
./install-security-controls.sh --language=rust --dry-run
./install-security-controls.sh --language=nodejs --dry-run
./install-security-controls.sh --language=python --dry-run
./install-security-controls.sh --language=go --dry-run

# Test documentation and functional synchronization
./scripts/validate-docs.sh
./scripts/count-controls.sh
./scripts/sync-security-controls.sh --check

# Test specific security tools
./.security-controls/bin/pinactlite pincheck --dir .github/workflows
./.security-controls/bin/gitleakslite detect --no-banner

# Run shell linting
shellcheck *.sh scripts/*.sh
shfmt -d -i 2 -ci -s .
```

5. **Commit with conventional commits**
```bash
git add .
git commit -m "feat: add new security check for X"
```

## 📝 Code Style Guidelines

### Shell Scripts
- Use bash 4.0+ features responsibly
- Follow ShellCheck recommendations
- Use shfmt with 2-space indentation
- Add error handling with `set -euo pipefail`
- Document complex logic with comments

### Security Checks
- Fail fast on critical issues
- Provide clear, actionable error messages
- Include remediation steps
- Minimize false positives
- Consider performance impact

### Example Security Check
```bash
# Check for hardcoded AWS credentials
check_aws_credentials() {
    local violations=0
    while IFS= read -r file; do
        if grep -qE 'AKIA[0-9A-Z]{16}' "$file"; then
            echo "❌ Hardcoded AWS key found in: $file"
            echo "   Fix: Use environment variables or AWS IAM roles"
            violations=$((violations + 1))
        fi
    done < <(git diff --cached --name-only)

    [[ $violations -eq 0 ]]
}
```

## 🧪 Testing

### Unit Tests
Test individual functions and components:
```bash
# Test secret detection patterns
echo "aws_access_key_id=AKIAIOSFODNN7EXAMPLE" | \
    ./.security-controls/bin/gitleakslite detect --no-banner
```

### Integration Tests
Test end-to-end workflows:
```bash
# Create test repository
mkdir test-repo && cd test-repo
git init
../install-security-controls.sh --force
echo "secret=supersecret123" > test.txt
git add test.txt
git commit -m "test" # Should be blocked by pre-push hook
```

### CI Testing
All PRs automatically run:
- Shell script linting (shellcheck + shfmt)
- GitHub Actions pinning validation
- End-to-end installation tests
- Documentation building

## 🔄 Pull Request Process

1. **Ensure all tests pass**
   - No shellcheck warnings
   - Proper shell formatting
   - All workflows pinned

2. **Update documentation**
   - Update README if adding features
   - Update CHANGELOG (maintainers will handle version)
   - Add inline documentation

3. **Create pull request**
   - Use descriptive title
   - Reference any related issues
   - Provide testing instructions
   - Include before/after examples

4. **Address review feedback**
   - Respond to all comments
   - Push fixes as new commits
   - Request re-review when ready

## 📊 Performance Guidelines

Pre-push checks must be fast to avoid disrupting developer flow:

| Check Type | Target Time | Maximum Time |
|------------|------------|--------------|
| Format | < 2s | 5s |
| Linting | < 15s | 30s |
| Security scan | < 5s | 10s |
| Secret detection | < 2s | 5s |
| Tests | < 20s | 60s |
| **Total** | **< 60s** | **90s** |

## 🔒 Security Considerations

When contributing security features:

1. **Threat Modeling**
   - What attack vectors does this address?
   - What are the bypass scenarios?
   - What's the false positive rate?

2. **Defense in Depth**
   - Don't rely on single points of failure
   - Layer multiple checks when possible
   - Fail securely (block when uncertain)

3. **Cryptographic Verification**
   - Use SHA256 minimum for checksums
   - Verify signatures when available
   - Pin dependencies to specific versions

## 🎨 Commit Message Format

We use conventional commits:

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Code style changes
- `refactor`: Code refactoring
- `perf`: Performance improvement
- `test`: Test additions/changes
- `chore`: Maintenance tasks

### Examples
```bash
feat(hook): add detection for hardcoded API keys
fix(ci): correct SHA pinning in workflow files
docs(readme): update installation instructions
perf(scan): optimize secret detection regex
```

## 📜 License

By contributing, you agree that your contributions will be licensed under Apache 2.0.

## 🙋 Getting Help

- **Questions**: Open a [GitHub Issue](https://github.com/h4x0r/1-click-github-sec/issues)
- **Bugs**: Open an [Issue](https://github.com/h4x0r/1-click-github-sec/issues)
- **Security**: See [Repository Security](REPO_SECURITY.md)

## 🏆 Recognition

Contributors are recognized in:
- CHANGELOG.md (for significant contributions)
- GitHub contributors graph
- Release notes

## 📚 Resources

- [Shell Scripting Best Practices](https://google.github.io/styleguide/shellguide.html)
- [GitHub Actions Security](https://docs.github.com/en/actions/security-guides)
- [OWASP Security Guidelines](https://owasp.org/)
- [Rust Security Guidelines](https://anssi-fr.github.io/rust-guide/)

---

**Thank you for helping make Rust projects more secure!** 🛡️