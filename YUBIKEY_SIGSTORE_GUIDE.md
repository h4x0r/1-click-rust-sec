# YubiKey + Sigstore Integration Guide

## 🔑 Hardware-Backed Git Commit Signing

This guide explains how to use YubiKey hardware security keys with Sigstore for keyless, short-lived credential Git commit signing.

---

## 🎯 Overview

### What is YubiKey + Sigstore Signing?

**YubiKey + Sigstore** combines:
- **Hardware Security**: Private keys never leave your YubiKey
- **Keyless Signing**: No long-lived private keys to manage
- **Short-lived Credentials**: Certificates valid for only 5-10 minutes
- **Transparency**: All signatures logged publicly in Rekor
- **OIDC Authentication**: Identity verified via GitHub/Google/etc.

### Security Model

```
YubiKey (Hardware Root of Trust)
    ↓
GitHub OIDC (Identity Provider) 
    ↓
Fulcio CA (Short-lived Certificate Authority)
    ↓
gitsign (Git Signing Tool)
    ↓
Signed Commit + Rekor Transparency Log
```

---

## 🛡️ Security Benefits

### **Hardware Security (YubiKey)**
- **Tamper-resistant**: Hardware-based cryptographic operations
- **Phishing-resistant**: FIDO2/WebAuthn prevents credential theft
- **Physical presence**: Touch required for every signature
- **Private keys never exposed**: Keys generated and stored in hardware

### **Keyless Architecture (Sigstore)**
- **No key management**: No long-lived private keys to rotate/backup
- **Short-lived certificates**: 5-10 minute validity reduces exposure
- **Identity-based**: Certificates tied to verified OIDC identity
- **Transparency logging**: All signatures publicly auditable

### **Combined Benefits**
- **Non-repudiation**: Cryptographic proof of authorship
- **Supply chain security**: Verify commit authenticity
- **Compliance ready**: Meets enterprise security requirements
- **Zero maintenance**: No key lifecycle management

---

## 🏗️ Technical Architecture

### OIDC Flow with YubiKey

1. **Commit Attempt**: Developer runs `git commit`
2. **gitsign Triggers**: Git calls gitsign for signing
3. **OIDC Challenge**: gitsign opens browser for authentication
4. **YubiKey Authentication**: GitHub requires YubiKey touch
5. **Token Exchange**: Valid OIDC token received
6. **Certificate Request**: gitsign requests cert from Fulcio
7. **Short-lived Certificate**: Fulcio issues 5-10 minute certificate
8. **Commit Signing**: Certificate signs commit
9. **Transparency Log**: Signature recorded in Rekor

### Key Components

| Component | Purpose | Technology |
|-----------|---------|------------|
| **YubiKey** | Hardware root of trust | FIDO2/WebAuthn |
| **GitHub** | OIDC identity provider | OAuth 2.0 + WebAuthn |
| **Fulcio** | Certificate authority | X.509 certificates |
| **gitsign** | Git signing integration | Sigstore client |
| **Rekor** | Transparency log | Merkle tree logging |

---

## 🚀 Quick Setup

### **Prerequisites**
- YubiKey 5 series with FIDO2 support
- GitHub account with YubiKey registered as security key
- Go installed (for gitsign installation)

### **1-Command Setup**
```bash
# Download the YubiKey toggle script
curl -O https://raw.githubusercontent.com/4n6h4x0r/1-click-rust-sec/main/yubikey-gitsign-toggle.sh
curl -O https://raw.githubusercontent.com/4n6h4x0r/1-click-rust-sec/main/yubikey-gitsign-toggle.sh.sha256

# Verify integrity
sha256sum -c yubikey-gitsign-toggle.sh.sha256

# Run interactive setup
chmod +x yubikey-gitsign-toggle.sh
./yubikey-gitsign-toggle.sh setup
```

### **Manual Setup**
```bash
# Install gitsign
go install github.com/sigstore/gitsign@latest

# Configure Git for Sigstore
git config --global gitsign.fulcio-url "https://fulcio.sigstore.dev"
git config --global gitsign.rekor-url "https://rekor.sigstore.dev"
git config --global gitsign.oidc-issuer "https://token.actions.githubusercontent.com"
git config --global gitsign.oidc-client-id "sigstore"

# Enable signing
git config --global commit.gpgsign true
git config --global tag.gpgsign true
git config --global gpg.x509.program gitsign
git config --global gpg.format x509
```

---

## 🔧 Configuration Details

### Sigstore Endpoints

| Endpoint | Purpose | URL |
|----------|---------|-----|
| **Fulcio** | Certificate Authority | `https://fulcio.sigstore.dev` |
| **Rekor** | Transparency Log | `https://rekor.sigstore.dev` |
| **OIDC Issuer** | GitHub Identity Provider | `https://token.actions.githubusercontent.com` |

### Git Configuration

```bash
# Core signing configuration
commit.gpgsign=true                    # Sign all commits
tag.gpgsign=true                       # Sign all tags
gpg.format=x509                        # Use X.509 certificates
gpg.x509.program=gitsign               # Use gitsign as signing program

# Sigstore-specific configuration
gitsign.fulcio-url=https://fulcio.sigstore.dev
gitsign.rekor-url=https://rekor.sigstore.dev
gitsign.oidc-issuer=https://token.actions.githubusercontent.com
gitsign.oidc-client-id=sigstore
```

---

## 🎮 Usage Workflow

### **Daily Development**

1. **Regular Development**: Code, stage changes normally
2. **Commit**: Run `git commit -m "Your commit message"`
3. **Browser Opens**: gitsign opens browser for GitHub OAuth
4. **YubiKey Touch**: GitHub prompts for YubiKey authentication
5. **Touch YubiKey**: Physical touch authenticates your identity
6. **Automatic Signing**: gitsign receives certificate and signs commit
7. **Transparency Logging**: Signature automatically logged to Rekor

### **Verification**

```bash
# Verify your signed commits
git log --show-signature

# Check specific commit
git log --show-signature -1 HEAD

# Output example:
# gitsign: Good signature from [your-github-email]
# gitsign: Certificate was issued by Fulcio
# gitsign: Certificate identity: https://github.com/your-username
```

### **Toggle On/Off**

```bash
# Check current status
./yubikey-gitsign-toggle.sh status

# Disable temporarily
./yubikey-gitsign-toggle.sh disable

# Re-enable
./yubikey-gitsign-toggle.sh enable

# Test signing
./yubikey-gitsign-toggle.sh test
```

---

## 🔒 Security Considerations

### **Threat Model Protection**

| Threat | Traditional GPG | YubiKey + Sigstore |
|--------|----------------|-------------------|
| **Key theft** | ❌ Long-lived keys vulnerable | ✅ Keys never leave hardware |
| **Phishing** | ❌ Passwords can be phished | ✅ FIDO2 prevents phishing |
| **Key compromise** | ❌ Permanent until revoked | ✅ Certificates expire in minutes |
| **Key management** | ❌ Complex backup/rotation | ✅ No key management needed |
| **Supply chain attacks** | ⚠️ Hard to verify authenticity | ✅ Public transparency log |

### **Certificate Lifecycle**

```
Certificate Request → Fulcio Issues Cert (5-10 min validity) → Sign Commit → Certificate Expires
                                    ↓
                            Signature + Identity logged to Rekor (permanent)
```

### **Identity Verification**

- **OIDC Token**: Contains verified GitHub identity
- **Hardware Attestation**: YubiKey proves physical presence
- **Certificate Transparency**: All certificates publicly logged
- **Rekor Entry**: Permanent record of signature + identity

---

## 🚨 Troubleshooting

### **Common Issues**

#### YubiKey Not Recognized
```bash
# Check YubiKey detection
ykman list

# If not found:
# - Try different USB port
# - Update YubiKey Manager: pip install --upgrade yubikey-manager
# - Check if YubiKey is registered with GitHub
```

#### GitHub Authentication Fails
```bash
# Clear cached credentials
gitsign initialize --oidc-issuer=https://token.actions.githubusercontent.com

# Verify GitHub security key setup:
# GitHub → Settings → Security → Two-factor authentication
```

#### gitsign Not Found
```bash
# Install gitsign
go install github.com/sigstore/gitsign@latest

# Ensure GOPATH/bin is in PATH
echo $PATH | grep go
export PATH="$PATH:$(go env GOPATH)/bin"
```

#### Browser Doesn't Open
```bash
# Manual OIDC flow
gitsign initialize

# Check firewall/proxy settings
# Ensure port 61023 is available for local callback
```

### **Verification Issues**

#### "Bad signature" Error
```bash
# Check Git configuration
git config --list | grep -E "(gpg|sign)"

# Verify gitsign installation
gitsign version

# Check certificate validity
git log --show-signature -1
```

#### Certificate Expired
```bash
# This is normal - certificates are short-lived
# Old commits remain valid due to Rekor transparency log
# New commits will get fresh certificates automatically
```

---

## 🔬 Advanced Configuration

### **Custom OIDC Provider**

```bash
# Use custom OIDC provider (e.g., Google)
git config --global gitsign.oidc-issuer "https://accounts.google.com"
git config --global gitsign.oidc-client-id "your-client-id"
```

### **Enterprise Fulcio Instance**

```bash
# Use private Fulcio instance
git config --global gitsign.fulcio-url "https://fulcio.your-company.com"
git config --global gitsign.rekor-url "https://rekor.your-company.com"
```

### **CI/CD Integration**

```bash
# GitHub Actions automatically provides OIDC tokens
# No additional configuration needed in GitHub Actions
# gitsign will automatically detect and use runner identity
```

### **Multiple YubiKeys**

```bash
# YubiKeys are registered per-identity (GitHub account)
# Multiple YubiKeys on same account work automatically
# No additional configuration required
```

---

## 📊 Comparison with Other Signing Methods

### **vs Traditional GPG**

| Aspect | Traditional GPG | YubiKey + Sigstore |
|--------|----------------|-------------------|
| **Key Management** | Complex (backup, expiry, revocation) | None (keyless) |
| **Hardware Security** | Optional (can use YubiKey) | Required (YubiKey mandatory) |
| **Certificate Lifetime** | Years (until manually revoked) | Minutes (automatic expiry) |
| **Identity Verification** | Web of trust / manual | OIDC provider verified |
| **Transparency** | None | Public Rekor log |
| **Phishing Resistance** | No (password-based) | Yes (FIDO2/WebAuthn) |
| **Setup Complexity** | High | Medium |
| **Enterprise Support** | Good | Excellent |

### **vs SSH Signing**

| Aspect | SSH Signing | YubiKey + Sigstore |
|--------|-------------|-------------------|
| **Hardware Support** | Yes (SSH keys on YubiKey) | Yes (YubiKey required) |
| **Key Lifetime** | Long-lived SSH keys | Short-lived certificates |
| **Identity Binding** | SSH key → GitHub account | OIDC token → Certificate |
| **Transparency** | None | Public Rekor log |
| **Verification** | GitHub knows your SSH key | Anyone can verify via Rekor |
| **Compliance** | Basic | Enterprise-grade |

---

## 🎯 Best Practices

### **Development Workflow**
- **Keep YubiKey Connected**: Avoid constant plug/unplug
- **Test Signing**: Use `./yubikey-gitsign-toggle.sh test` regularly
- **Monitor Certificates**: Short-lived nature means frequent renewals
- **Backup Strategy**: No keys to backup (keyless architecture)

### **Security Practices**
- **Register Multiple YubiKeys**: Backup YubiKey for redundancy
- **Monitor Rekor Logs**: Verify your signatures appear correctly
- **Review GitHub Security**: Regularly audit registered security keys
- **Update gitsign**: Keep tooling current for security patches

### **Team Adoption**
- **Gradual Rollout**: Start with volunteers, expand gradually
- **Documentation**: Share this guide with team members
- **Support Process**: Establish help channels for setup issues
- **Policy Creation**: Define when YubiKey signing is required

---

## 📈 Adoption Strategy

### **Individual Developer**
1. **Personal Projects**: Start with personal repositories
2. **Learn the Flow**: Get comfortable with YubiKey + browser flow
3. **Test Thoroughly**: Verify signatures are working correctly
4. **Professional Usage**: Apply to work projects once confident

### **Team/Organization**
1. **Pilot Program**: Select early adopters for initial testing
2. **Infrastructure**: Ensure all developers have YubiKey 5 series
3. **Training**: Conduct setup sessions and troubleshooting workshops
4. **Policy**: Establish guidelines for when signing is required
5. **Monitoring**: Track adoption metrics and support requests

### **Enterprise**
1. **Security Review**: Validate Sigstore against enterprise policies  
2. **Infrastructure**: Consider private Fulcio/Rekor instances
3. **Integration**: Connect with existing identity providers
4. **Compliance**: Map to regulatory requirements (SOX, etc.)
5. **Rollout**: Phased deployment with comprehensive support

---

## 🔗 Resources

### **Documentation**
- [Sigstore Documentation](https://docs.sigstore.dev/)
- [gitsign Repository](https://github.com/sigstore/gitsign)
- [YubiKey Developer Guides](https://developers.yubico.com/)
- [FIDO2/WebAuthn Specs](https://webauthn.io/)

### **Tools**
- [gitsign](https://github.com/sigstore/gitsign) - Git signing with Sigstore
- [YubiKey Manager](https://developers.yubico.com/yubikey-manager/) - YubiKey management
- [Rekor CLI](https://github.com/sigstore/rekor) - Transparency log interaction
- [Cosign](https://github.com/sigstore/cosign) - Container signing

### **Community**
- [Sigstore Slack](https://sigstore.slack.com/) - Community support
- [OpenSSF](https://openssf.org/) - Open source security foundation
- [YubiKey Community](https://community.yubico.com/) - Hardware support

---

**🔑 Transform your Git workflow with hardware-backed, keyless, transparent commit signing!**

*No more key management. No more credential theft. Just secure, verifiable commits with a simple YubiKey touch.*