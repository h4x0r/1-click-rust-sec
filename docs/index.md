# 1-Click GitHub Security Controls

<div align="center">
  <img src="../1-click-github-sec Logo.png" alt="1-Click GitHub Security" width="150">
  <br><br>
  <em>Created by Albert Hui &lt;albert@securityronin.com&gt;</em>
</div>

[![Documentation](https://github.com/h4x0r/1-click-github-sec/actions/workflows/docs.yml/badge.svg?branch=main)](https://github.com/h4x0r/1-click-github-sec/actions/workflows/docs.yml)
[![Quality Assurance](https://github.com/h4x0r/1-click-github-sec/actions/workflows/quality-assurance.yml/badge.svg?branch=main)](https://github.com/h4x0r/1-click-github-sec/actions/workflows/quality-assurance.yml)
[![CodeQL](https://github.com/h4x0r/1-click-github-sec/actions/workflows/codeql.yml/badge.svg?branch=main)](https://github.com/h4x0r/1-click-github-sec/actions/workflows/codeql.yml)
[![Pinactlite Sync](https://github.com/h4x0r/1-click-github-sec/actions/workflows/sync-pinactlite.yml/badge.svg?branch=main)](https://github.com/h4x0r/1-click-github-sec/actions/workflows/sync-pinactlite.yml)

**Cryptographically Signed & Verified Security Controls**

Deploy security controls to any project with a single command. Supports Rust, Node.js, Python, Go, and generic projects with **cryptographic verification** for supply chain security.

## 🔐 Key Security Features

- **35+ Security Controls** - Comprehensive coverage for all project types
- **Cryptographic Signing** - All commits and releases signed with Sigstore
- **Certificate Transparency** - Public audit trail via Rekor ledger
- **Keyless Verification** - No GPG key management required
- **Supply Chain Protection** - End-to-end verification of security tools

## 📚 Quick Navigation

Use the navigation menu to explore:

- **[Installation Guide](installation/)** - Get started in minutes
- **[Security Architecture](architecture/)** - Technical deep-dive
- **[Cryptographic Signing](signing/)** - Learn about our keyless signing
- **[Certificate Transparency](transparency/)** - Understand public verification
- **[YubiKey Integration](yubikey/)** - Hardware-backed signing

## 🔗 External Links

- **[GitHub Repository](https://github.com/h4x0r/1-click-github-sec)** - Source code & releases
- **[Report Issues](https://github.com/h4x0r/1-click-github-sec/issues)** - Bug reports & feature requests
- **[Latest Release](https://github.com/h4x0r/1-click-github-sec/releases/latest)** - Download installer

## 🛡️ Verification

Every release is cryptographically signed:

```bash
# Verify the installer authenticity
git tag -v v0.4.2

# Expected output:
# gitsign: Good signature from [maintainer@email.com]
# Validated Git signature: true
# Validated Rekor entry: true
```

---

*Updated: September 25, 2025 - Enhanced with cryptographic signing documentation*
