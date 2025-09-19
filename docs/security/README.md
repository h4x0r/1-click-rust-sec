# Security Controls

This directory mirrors the core security documentation provided by 1-Click Rust Security for parity with repositories that install these controls.

Contents
- Installation Guide (root): ../../SECURITY_CONTROLS_INSTALLATION.md
- Architecture: ./ARCHITECTURE.md
- YubiKey + Sigstore guide: ./YUBIKEY_SIGSTORE_GUIDE.md

Quick helper usage
- Secret scan (script helper):
  .security-controls/bin/gitleakslite detect --no-banner

- Pinning check (script helper):
  .security-controls/bin/pincheck pincheck --dir .github/workflows

Notes
- This repo’s installer also generates docs/security in target repos with similar content.
- For end-to-end installation instructions and troubleshooting, see the Installation Guide.
