# Contributing Guide

Thank you for your interest in contributing! This project provides a fast pre-push security layer and comprehensive CI validation for Rust and general repositories.

## Getting Started
- Fork and clone the repository.
- Create a feature branch from main.
- Install local tooling (optional but recommended):
  - pre-commit (shell, markdown, hygiene checks)

## Pre-commit hooks
Use pre-commit to run checks locally before committing/pushing.

Quick start:

```bash
# Install pre-commit
# macOS (Homebrew):
brew install pre-commit
# or: pipx install pre-commit

# Install hooks
override_dir=$(git rev-parse --show-toplevel)
cd "$override_dir"
pre-commit install

# Run against all files once
pre-commit run --all-files
```

Hooks enabled:
- shellcheck (lint shell scripts)
- shfmt (format shell scripts, 2-space indent)
- markdownlint (Markdown style)
- trailing whitespace, EOF fixes, YAML validation, large file checks

## Development workflow
- Make targeted changes and keep commits focused (semantic commit messages preferred).
- Run local checks:
  - Shell lint: shellcheck and shfmt (via pre-commit), or directly:
    ```bash
    find . -name "*.sh" -print0 | xargs -0 -r shellcheck
    shfmt -d -i 2 -ci -s .
    ```
  - Pre-push hook dry-run:
    ```bash
    # install / update hooks
    bash ./install-security-controls.sh --force
    # simulate a push
    git push --dry-run
    ```
  - Installer self-test (see CI for full flow). Locally you can create a sandbox repo and run:
    ```bash
    mkdir -p /tmp/sc-sandbox && cp install-security-controls.sh /tmp/sc-sandbox/
    cd /tmp/sc-sandbox && git init -q && git config user.email you@example.com && git config user.name You
    bash ./install-security-controls.sh --non-rust --no-ci --no-docs --force
    .git/hooks/pre-push
    ```

## CI overview
- Shell Lint: shellcheck + shfmt
- Installer Self-Test: runs installer in a sandbox repo
- Helpers E2E: exercises pincheck and gitleakslite helpers
- Pinning Validation: cosign + checksum + optional SLSA verification, then pinact --check

## Versioning and releases
- Bump version using the helper script:
  ```bash
  scripts/bump-version.sh 1.5.0
  git add install-security-controls.sh VERSION CHANGELOG.md
  git commit -m "release: bump to v1.5.0"
  git push
  git tag -a v1.5.0 -m "Release v1.5.0"
  git push origin v1.5.0
  ```
  Adjust the version number as appropriate (SemVer).

## Code of Conduct
- Please read and follow our CODE_OF_CONDUCT.md. We are committed to a welcoming, inclusive community.

## Security
- Please report security issues privately via GitHub Security Advisories.
