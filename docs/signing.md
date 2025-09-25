# Signed Commits & Tags

## 🔐 Overview

This project uses **keyless signing** with Sigstore and gitsign to provide cryptographic verification for all commits and releases. This ensures the integrity and authenticity of all code changes and releases.

## 🎯 Why Signed Commits Matter

Traditional software development relies on trust that commits come from who they claim to be. However, Git commits can be easily forged:

```bash
# Anyone can impersonate any committer
git -c user.name="Linus Torvalds" -c user.email="torvalds@linux-foundation.org" commit -m "Backdoor added"
```

**Signed commits solve this by providing cryptographic proof** that the commit was created by someone with access to the signing key or identity.

## 🚀 Modern Signing: Sigstore + gitsign

Instead of traditional GPG key management, this project uses **Sigstore** with **gitsign** for:

### ✅ Benefits of Keyless Signing
- **No local key management** - No GPG keys to generate, store, or rotate
- **OIDC identity verification** - Uses your existing GitHub/Google/Microsoft identity
- **Certificate transparency** - All signatures logged in public Rekor ledger
- **Automatic expiration** - Certificates are short-lived (10 minutes) preventing long-term key compromise
- **Public auditability** - Anyone can verify signatures against the public transparency log

### 🔧 How It Works

1. **Identity Verification**: When you sign, gitsign redirects to OIDC provider (GitHub)
2. **Certificate Issuance**: Fulcio CA issues short-lived certificate tied to your identity
3. **Signing**: Your commit/tag gets signed with the ephemeral certificate
4. **Transparency Logging**: Signature is logged to Rekor transparency ledger
5. **Verification**: Anyone can verify against the public ledger

## 🛡️ Implementation in This Project

### Signed Commits

All commits in this repository are signed with gitsign:

```bash
# Check commit signature
git log --show-signature -1

# Example output:
# gitsign: Signature made using certificate ID 0x...
# gitsign: Good signature from [email@domain.com]
# Validated Git signature: true
# Validated Rekor entry: true
```

### Signed Tags (Releases)

All release tags are cryptographically signed:

```bash
# Create signed tag
git tag -s v1.0.0 -m "Release v1.0.0 with security enhancements"

# Verify tag signature
git tag -v v1.0.0

# Example output:
# gitsign: Good signature from [email@domain.com]
# Validated Git signature: true
# Validated Rekor entry: true
```

### Verification Process

**For end users verifying releases:**

```bash
# 1. Verify the tag signature
git tag -v v1.0.0

# 2. Verify the commit signature
git log --show-signature v1.0.0 -1

# 3. Check against Rekor transparency log
gitsign verify --certificate-github-workflow-sha=<sha> v1.0.0
```

## 🔍 Verification Examples

### Verify Latest Release

```bash
# Clone repository
git clone https://github.com/h4x0r/1-click-github-sec.git
cd 1-click-github-sec

# Verify latest tag signature
git tag -v $(git describe --tags --abbrev=0)

# Check commit signatures in recent history
git log --show-signature --oneline -10
```

### Verify Specific Release Artifacts

```bash
# Download release files
curl -O https://github.com/h4x0r/1-click-github-sec/releases/download/v0.4.2/install-security-controls.sh
curl -O https://github.com/h4x0r/1-click-github-sec/releases/download/v0.4.2/checksums.txt

# Verify checksums
sha256sum -c checksums.txt --ignore-missing

# Verify the release tag that generated these artifacts
git tag -v v0.4.2
```

## ⚙️ Setting Up Signing (For Contributors)

### Prerequisites

1. **gitsign installed** (via installer or manual setup)
2. **GitHub account** with email verified
3. **Git configured** with your GitHub email

### Configuration

```bash
# Configure Git to use gitsign
git config --global commit.gpgsign true
git config --global tag.gpgsign true
git config --global gpg.x509.program gitsign
git config --global gpg.format x509

# Set your identity (must match GitHub account)
git config --global user.name "Your Name"
git config --global user.email "your-github-email@example.com"
```

### First Signed Commit

```bash
# Make changes
echo "Test change" >> README.md
git add README.md

# Commit (will trigger OIDC flow)
git commit -m "test: signed commit"

# Browser will open for GitHub authentication
# After auth, commit will be signed automatically
```

### Creating Signed Tags

```bash
# For maintainers creating releases
git tag -s v1.0.0 -m "v1.0.0 - Security improvements and signed releases

Features:
- Enhanced cryptographic verification
- Sigstore certificate transparency
- Keyless signing implementation

This tag is signed with Sigstore for enhanced security verification."

# Push signed tag
git push --tags
```

## 🏛️ Trust Model

### Certificate Chain

```
GitHub OIDC Identity
    ↓
Fulcio CA Certificate (short-lived, 10 minutes)
    ↓
Git Object Signature
    ↓
Rekor Transparency Log Entry
```

### Verification Chain

1. **Identity Binding**: Certificate proves GitHub identity at signing time
2. **Temporal Validity**: Short-lived certificates prevent long-term key compromise
3. **Public Auditability**: Rekor log provides immutable audit trail
4. **Non-repudiation**: Cannot deny having made a signed commit

### Trust Anchors

- **Fulcio Root CA**: Sigstore's certificate authority
- **Rekor Transparency Log**: Immutable signature record
- **OIDC Provider**: GitHub's identity verification

## 🚨 Security Considerations

### Advantages Over GPG

| Aspect | GPG | Sigstore/gitsign |
|--------|-----|------------------|
| **Key Management** | Complex, manual | Automatic, keyless |
| **Key Rotation** | Manual process | Automatic expiration |
| **Identity Binding** | Self-asserted | OIDC verified |
| **Transparency** | Optional | Built-in (Rekor) |
| **Revocation** | Manual, complex | Automatic expiration |
| **Auditability** | Private keyring | Public transparency log |

### Threat Model Protection

✅ **Protects Against:**
- Commit impersonation
- Supply chain attacks via malicious commits
- Backdoor insertion without detection
- Historical tampering detection

⚠️ **Does Not Protect Against:**
- Compromised developer machines (at signing time)
- OIDC provider compromise
- Fulcio CA compromise (but these are monitored and auditable)

### Operational Security

**For maintainers:**
- Use dedicated development environments
- Enable 2FA on all OIDC accounts
- Monitor Rekor logs for unexpected signatures
- Verify all tags before releases

**For users:**
- Always verify signatures before using releases
- Check multiple sources for signature verification
- Monitor security advisories

## 📋 Verification Checklist

### Before Using Any Release

- [ ] **Verify tag signature**: `git tag -v vX.Y.Z`
- [ ] **Check Rekor transparency log**: Look for signature entry
- [ ] **Verify checksums**: `sha256sum -c checksums.txt`
- [ ] **Confirm identity**: Signature matches expected maintainer
- [ ] **Check timestamp**: Signature timestamp is reasonable

### Troubleshooting

**Common Issues:**

```bash
# "no signature found"
# Solution: Tag was not signed, or signature verification failed

# "certificate verification failed"
# Solution: Certificate may have expired or identity mismatch

# "rekor entry not found"
# Solution: Signature not logged to transparency ledger
```

**Getting Help:**

1. Check [Sigstore documentation](https://docs.sigstore.dev/)
2. Review [gitsign documentation](https://github.com/sigstore/gitsign)
3. Open issue in this repository for project-specific problems

---

## 🔗 Additional Resources

- **[Sigstore Documentation](https://docs.sigstore.dev/)**
- **[gitsign GitHub](https://github.com/sigstore/gitsign)**
- **[Certificate Transparency Guide](transparency.md)**
- **[YubiKey Integration](yubikey.md)**

---

*This document is part of the 1-Click GitHub Security project's commitment to transparent, verifiable software development.*