# Complete Signing Guide

## 🔐 Cryptographic Verification & 4-Mode Setup

This guide covers everything you need to know about cryptographic signing in 1-Click GitHub Security - from understanding why it matters to setting up and verifying signatures across all 4 signing modes.

---

## 🎯 Why Cryptographic Verification Matters

### The Problem: Trust in Software Development

```bash
# Anyone can impersonate any developer
git -c user.name="Maintainer" -c user.email="maintainer@project.com" commit -m "Add backdoor"
```

**Traditional solutions:**
- **GPG signing**: Complex key management, key compromise risk, private verification
- **Trust assumptions**: "This commit came from who it claims"

**Modern solution: Sigstore**
- **Keyless signing**: No long-lived keys to manage or compromise
- **Identity-based**: Tied to your verified GitHub/Google/Microsoft account
- **Certificate transparency**: All signatures publicly auditable
- **Short-lived certificates**: 5-10 minute validity prevents long-term key compromise

---

## 🏗️ How Sigstore Verification Works

### The Complete Flow

**Step-by-step:**
1. **Developer commits** - `git commit` triggers gitsign
2. **Identity verification** - Browser opens for GitHub/Google/Microsoft login
3. **Certificate issuance** - Fulcio CA issues certificate tied to verified identity
4. **Signing** - Commit signed with ephemeral certificate (valid 5-10 minutes)
5. **Transparency logging** - Signature automatically logged to public Rekor ledger
6. **Verification** - Anyone can verify signature against public transparency log

### Security Benefits

✅ **Identity-verified signatures** - No spoofing possible
✅ **Public transparency** - All signatures auditable via Rekor
✅ **Short certificate lifetime** - Compromised certs expire quickly
✅ **No key management** - Certificates issued automatically
✅ **Tamper detection** - Any modification breaks signature verification

---

## 🤔 GPG vs gitsign: Which Should You Choose?

### Quick Decision Matrix

| **Your Priority** | **Recommended Mode** | **Why Choose This** |
|-------------------|---------------------|---------------------|
| **Maximum Security** | gitsign + YubiKey | Short-lived certificates + hardware authentication + transparency logging |
| **High Security + Ease** | gitsign + software | Keyless signing + automatic rotation + no key management |
| **GitHub UI Badges** | GPG + software | Traditional signing with GitHub "Verified" badges |
| **Hardware + Badges** | GPG + YubiKey | Hardware security + GitHub verification display |

### Detailed Security Comparison

| **Feature** | **gitsign** | **GPG** |
|-------------|-------------|---------|
| **Certificate Lifetime** | 5-10 minutes | 2+ years |
| **Key Management** | Automatic, keyless | Manual, complex |
| **Key Compromise Risk** | Minimal (short-lived) | High (long-lived) |
| **Identity Verification** | OIDC-verified (GitHub/Google) | Self-asserted |
| **Transparency Logging** | Automatic (Rekor) | Optional, manual |
| **Revocation** | Automatic expiration | Manual CRL/OCSP |
| **Auditability** | Public transparency log | Private keyring |
| **Setup Complexity** | Minimal | Complex |
| **GitHub "Verified" Badge** | ❌ No (limitation) | ✅ Yes |
| **Cryptographic Security** | ✅ Superior | ⚠️ Weaker |

### GitHub Verification Badge Limitation

**Important Security Note:**

- **gitsign signatures show as "Unverified" on GitHub** due to GitHub's current limitations in supporting X.509/Sigstore signatures
- **This is a display-only issue** - gitsign provides superior cryptographic security compared to traditional GPG
- **GitHub will likely add Sigstore support** in the future as the ecosystem matures
- **Your commits are still cryptographically signed and verifiable** using `gitsign verify` command

### Security Trade-offs Explained

#### Why gitsign is More Secure

1. **Short-lived Certificates**: 5-10 minute validity means stolen certificates become useless quickly
2. **Keyless Design**: No long-lived private keys to steal, lose, or compromise
3. **Automatic Rotation**: New certificates issued for each signing session
4. **Identity Binding**: Tied to verified OAuth identity (GitHub, Google, Microsoft)
5. **Transparency by Default**: All signatures automatically logged in public Rekor ledger
6. **No Key Management**: Eliminates human error in key lifecycle management

#### Why You Might Choose GPG

1. **GitHub UI Integration**: "Verified" badges appear on commits and tags
2. **Legacy Tool Support**: Works with existing GPG-based workflows
3. **Offline Signing**: Can sign without internet connectivity (after key setup)
4. **Enterprise Policies**: Some organizations require traditional PKI
5. **Team Familiarity**: Developers already know GPG workflows

### Recommendation Summary

**For Security-First Projects:**
- Choose **gitsign** (default option) for superior cryptographic security
- Accept that GitHub shows "Unverified" (display issue, not security issue)
- Use `gitsign verify` command for cryptographic verification

**For GitHub-UI-First Projects:**
- Choose **GPG** if you specifically need GitHub "Verified" badges
- Accept the security trade-offs of long-lived keys
- Implement strict key management practices

**For Maximum Security:**
- Choose **gitsign + YubiKey** for hardware-backed authentication
- Combine short-lived certificates with hardware security

---

## 🔑 4 Signing Modes Complete Setup

The installer supports **4 signing modes** combining two signing methods with two authentication types:

### Mode Overview

**Mode 1: gitsign + software** (default - high security):
- **Short-lived certificates**: 5-10 minute validity
- **Browser authentication**: Standard OAuth flow
- **Transparency logging**: All signatures in Rekor
- **Zero key management**: No long-lived keys

**Mode 2: gitsign + YubiKey** (maximum security):
- **Short-lived certificates**: 5-10 minute validity
- **Hardware authentication**: YubiKey touch required
- **Phishing resistance**: FIDO2/WebAuthn security
- **Maximum security**: Hardware root of trust

**Mode 3: GPG + software** (GitHub badges):
- **Traditional GPG**: Long-lived keys (2-year expiration)
- **GitHub verification**: "Verified" badges on commits
- **Software keys**: Standard GPG key management
- **Manual management**: Key rotation required

**Mode 4: GPG + YubiKey** (hardware + badges):
- **Traditional GPG**: Long-lived keys on hardware
- **GitHub verification**: "Verified" badges on commits
- **Hardware keys**: Private keys on YubiKey
- **Touch requirement**: Physical presence for signing

### Installation Commands

```bash
# Mode 1: gitsign + software (default - high security)
./install-security-controls.sh

# Mode 2: gitsign + YubiKey (maximum security)
./install-security-controls.sh --yubikey

# Mode 3: GPG + software (GitHub badges)
./install-security-controls.sh --signing=gpg

# Mode 4: GPG + YubiKey (hardware + badges)
./install-security-controls.sh --signing=gpg --yubikey
```

### Mode Switching After Installation

```bash
# Check current signing mode
./install-security-controls.sh status

# Switch between modes
./install-security-controls.sh switch-to-gitsign
./install-security-controls.sh switch-to-gpg

# Add/remove YubiKey requirement
./install-security-controls.sh enable-yubikey
./install-security-controls.sh disable-yubikey

# Test current configuration
./install-security-controls.sh test
```

---

## 🔧 Setup for Contributors

### Prerequisites

1. **gitsign installed** (included in our installer)
2. **GitHub account** with verified email
3. **Git configured** with matching email

### Quick Setup

```bash
# Install security controls (includes gitsign)
./install-security-controls.sh

# Verify gitsign is configured
git config --get commit.gpgsign  # Should return: true
git config --get gpg.format      # Should return: x509
git config --get gpg.x509.program # Should return: gitsign
```

### First Signed Commit

```bash
# Make a change
echo "Testing signed commits" >> README.md
git add README.md

# Commit (browser will open for authentication)
git commit -m "test: verify gitsign configuration"

# Browser authentication flow:
# 1. GitHub OIDC login screen appears
# 2. Authorize Sigstore access
# 3. Certificate issued and commit signed
# 4. Signature logged to Rekor transparency ledger
```

### Verification Results

```bash
# Check signature
git log --show-signature -1

# Example output:
# tlog index: 567315903
# gitsign: Signature made using certificate ID 0xd1cb...
# gitsign: Good signature from [your-email@domain.com]
# Validated Git signature: true
# Validated Rekor entry: true
```

---

## 🔍 Signature Verification

### Verify Any Commit

```bash
# Verify specific commit
gitsign verify <commit-hash>

# Verify current HEAD
gitsign verify HEAD

# Verify with specific identity
gitsign verify --certificate-identity="expected@email.com" HEAD
```

### What Verification Checks

✅ **Certificate validity** - Was certificate valid at signing time?
✅ **Identity binding** - Does signer identity match expected email?
✅ **Transparency logging** - Is signature recorded in Rekor ledger?
✅ **Signature integrity** - Has commit been tampered with since signing?
✅ **Trust chain** - Is certificate issued by trusted Fulcio CA?

### Verification Examples

**Successful verification:**
```bash
$ gitsign verify HEAD
tlog index: 567315903
gitsign: Signature made using certificate ID 0xd1cb214b2a12f6732a84d1777720903036dbd739
gitsign: Good signature from [albert@securityronin.com](https://github.com/login/oauth)
Validated Git signature: true
Validated Rekor entry: true
```

**Failed verification (tampered commit):**
```bash
$ gitsign verify HEAD
Error: signature verification failed
Details: commit content has been modified after signing
```

### Release Verification

```bash
# Verify signed tag
git tag -v v0.6.5

# Check release artifacts
gitsign verify --artifact install-security-controls.sh v0.6.5

# Verify against Rekor ledger
rekor-cli search --email albert@securityronin.com
```

---

## 🛠️ Troubleshooting

### Common Issues and Solutions

**"failed to sign commit"**
```bash
# Check gitsign configuration
git config --get commit.gpgsign  # Should be: true
git config --get gpg.format      # Should be: x509
git config --get gpg.x509.program # Should be: gitsign

# Test gitsign directly
gitsign --help

# Re-run installer if misconfigured
./install-security-controls.sh switch-to-gitsign
```

**"browser authentication timeout"**
```bash
# Increase timeout
git config --global gitsign.autocloseTimeout 60

# Check browser pop-up blocking
# Ensure oauth2.sigstore.dev is not blocked

# Manual authentication
gitsign verify HEAD  # Opens browser for auth
```

**"certificate verification failed"**
```bash
# Certificate may have expired or identity mismatch
gitsign verify --certificate-identity="expected@email.com" HEAD

# Check Rekor entry status
rekor-cli search --email expected@email.com
```

**"rekor entry not found"**
```bash
# Signature wasn't logged to transparency ledger
# This shouldn't happen with properly configured gitsign

# Check gitsign configuration
git config --get gpg.x509.program  # Should be: gitsign
git config --get gpg.format        # Should be: x509
```

### Getting Help

1. **Check configuration**: `gitsign --help` and verify setup
2. **Review logs**: Look for gitsign error messages during commit
3. **Test signing**: Try signing a test commit to isolate issues
4. **Community support**: Open issue with reproduction steps

---

## 🔗 Additional Resources

- **[Sigstore Documentation](https://docs.sigstore.dev/)** - Complete Sigstore ecosystem guide
- **[gitsign Documentation](https://github.com/sigstore/gitsign)** - Git signing tool details
- **[Rekor Documentation](https://docs.sigstore.dev/rekor/overview/)** - Transparency ledger specifics
- **[Certificate Transparency RFC](https://tools.ietf.org/html/rfc6962)** - Technical specification

---

## 🎯 Key Takeaways

✅ **Sigstore = Signing + Transparency** - They're one integrated security model
✅ **Keyless & automatic** - No GPG key management complexity
✅ **Identity-verified** - Tied to your authenticated GitHub account
✅ **Publicly auditable** - All signatures logged in Rekor transparency ledger
✅ **Short-lived certificates** - 5-10 minute validity prevents long-term compromise
✅ **Supply chain security** - End-to-end verification from development to deployment

**The bottom line:** Every commit and release in this project is cryptographically signed and publicly verifiable. This provides stronger security than traditional GPG with significantly less complexity.

Choose your signing mode based on your security requirements and GitHub UI preferences, then follow the setup instructions above to get started with cryptographically verified commits.