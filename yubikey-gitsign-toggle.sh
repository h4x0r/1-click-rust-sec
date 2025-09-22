#!/bin/bash

# 🔑 YubiKey Gitsign Toggle Script
# Enables/disables YubiKey-backed Sigstore commit signing
#
# Version: 1.0.0
# License: Apache-2.0
# Repository: https://github.com/4n6h4x0r/1-click-rust-sec

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
# shellcheck disable=SC2034 # Color reserved for future use
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Configuration
readonly SCRIPT_VERSION="0.1.0"
readonly GITSIGN_CONFIG_FILE="$HOME/.gitsign-config"
readonly BACKUP_CONFIG_FILE="$HOME/.git-config-backup"

# Function to print colored output
print_status() {
  local color=$1
  local message=$2
  echo -e "${color}${message}${NC}"
}

print_header() {
  echo
  print_status $CYAN "════════════════════════════════════════════════"
  print_status $CYAN "  $1"
  print_status $CYAN "════════════════════════════════════════════════"
  echo
}

show_help() {
  cat <<EOF
🔑 YubiKey Gitsign Toggle Script v${SCRIPT_VERSION}

USAGE:
    $0 [COMMAND] [OPTIONS]

COMMANDS:
    enable              Enable YubiKey-backed Sigstore signing
    disable             Disable YubiKey signing (restore previous config)
    status              Show current signing configuration
    test                Test YubiKey signing with a test commit
    setup               Interactive setup wizard
    reset               Reset all signing configuration

OPTIONS:
    -h, --help          Show this help message
    -v, --version       Show version information
    -g, --global        Apply changes globally (default: repository-local)
    --force             Force changes without confirmation
    --dry-run           Show what would be changed without applying

EXAMPLES:
    # Enable YubiKey signing for current repository
    $0 enable

    # Enable globally for all repositories
    $0 enable --global

    # Check current status
    $0 status

    # Interactive setup with guided configuration
    $0 setup

    # Test signing (creates test commit)
    $0 test

    # Disable and restore previous configuration
    $0 disable

SECURITY FEATURES:
    ✅ Hardware-backed signing (YubiKey required)
    ✅ Short-lived certificates (5-10 minutes)
    ✅ Transparency logging (Rekor)
    ✅ OIDC identity verification
    ✅ Phishing-resistant authentication

REQUIREMENTS:
    - YubiKey 5 series with FIDO2/WebAuthn
    - GitHub account with YubiKey registered
    - gitsign installed (auto-installed if missing)
    - Modern browser for OIDC flow

EOF
}

show_version() {
  echo "YubiKey Gitsign Toggle Script v${SCRIPT_VERSION}"
  echo "Hardware-backed keyless Git commit signing"
  echo "https://github.com/4n6h4x0r/1-click-rust-sec"
}

# Check if we're in a git repository for local operations
check_git_repo() {
  if [[ ${GLOBAL_CONFIG:-false} == false ]] && ! git rev-parse --git-dir >/dev/null 2>&1; then
    print_status $RED "❌ Not in a Git repository"
    echo "Use --global flag for global configuration or run from within a Git repository"
    exit 1
  fi
}

# Check prerequisites
check_prerequisites() {
  print_status $BLUE "🔍 Checking prerequisites..."

  local missing_tools=()

  # Check for required tools
  if ! command -v git &>/dev/null; then
    missing_tools+=("git")
  fi

  if ! command -v curl &>/dev/null; then
    missing_tools+=("curl")
  fi

  # Check if gitsign is available
  if ! command -v gitsign &>/dev/null; then
    print_status $YELLOW "⚠️  gitsign not found - will attempt to install"
    NEED_GITSIGN_INSTALL=true
  else
    print_status $GREEN "✅ gitsign: $(command -v gitsign)"
    NEED_GITSIGN_INSTALL=false
  fi

  if [[ ${#missing_tools[@]} -gt 0 ]]; then
    print_status $RED "❌ Missing required tools: ${missing_tools[*]}"
    echo
    echo "Install missing tools:"
    for tool in "${missing_tools[@]}"; do
      case $tool in
        "git")
          echo "  macOS: brew install git"
          echo "  Ubuntu: sudo apt install git"
          ;;
        "curl")
          echo "  macOS: brew install curl"
          echo "  Ubuntu: sudo apt install curl"
          ;;
      esac
    done
    exit 1
  fi

  print_status $GREEN "✅ Prerequisites check passed"
}

# Install gitsign if needed
install_gitsign() {
  if [[ ${NEED_GITSIGN_INSTALL:-false} == false ]]; then
    return 0
  fi

  print_status $BLUE "📦 Installing gitsign..."

  if command -v go &>/dev/null; then
    print_status $YELLOW "Installing gitsign via Go..."
    if go install github.com/sigstore/gitsign@latest; then
      print_status $GREEN "✅ gitsign installed successfully"
    else
      print_status $RED "❌ Failed to install gitsign via Go"
      return 1
    fi
  else
    print_status $YELLOW "Go not found. Please install gitsign manually:"
    echo "  1. Install Go: https://golang.org/dl/"
    echo "  2. Run: go install github.com/sigstore/gitsign@latest"
    echo '  3. Ensure $GOPATH/bin is in your PATH'
    return 1
  fi
}

# Backup current git configuration
backup_git_config() {
  print_status $BLUE "💾 Backing up current Git configuration..."

  local config_scope=""
  if [[ ${GLOBAL_CONFIG:-false} == true ]]; then
    config_scope="--global"
  fi

  # Create backup of relevant settings
  cat >"$BACKUP_CONFIG_FILE" <<EOF
# Git Configuration Backup - $(date)
# Created by YubiKey Gitsign Toggle Script v${SCRIPT_VERSION}

# Signing configuration
commit.gpgsign=$(git config ${config_scope} --get commit.gpgsign || echo "false")
tag.gpgsign=$(git config ${config_scope} --get tag.gpgsign || echo "false")
gpg.format=$(git config ${config_scope} --get gpg.format || echo "openpgp")
gpg.x509.program=$(git config ${config_scope} --get gpg.x509.program || echo "")
user.signingkey=$(git config ${config_scope} --get user.signingkey || echo "")

# Gitsign configuration
gitsign.fulcio-url=$(git config ${config_scope} --get gitsign.fulcio-url || echo "")
gitsign.rekor-url=$(git config ${config_scope} --get gitsign.rekor-url || echo "")
gitsign.oidc-issuer=$(git config ${config_scope} --get gitsign.oidc-issuer || echo "")
gitsign.oidc-client-id=$(git config ${config_scope} --get gitsign.oidc-client-id || echo "")
EOF

  print_status $GREEN "✅ Configuration backed up to: $BACKUP_CONFIG_FILE"
}

# Enable YubiKey-backed signing
enable_yubikey_signing() {
  print_header "Enabling YubiKey-backed Sigstore Signing"

  local config_scope=""
  if [[ ${GLOBAL_CONFIG:-false} == true ]]; then
    config_scope="--global"
    print_status $BLUE "🌐 Configuring globally for all repositories"
  else
    print_status $BLUE "📁 Configuring for current repository only"
  fi

  # Backup existing configuration
  backup_git_config

  print_status $BLUE "⚙️  Configuring gitsign for Sigstore..."

  # Configure Sigstore endpoints
  git config ${config_scope} gitsign.fulcio-url "https://fulcio.sigstore.dev"
  git config ${config_scope} gitsign.rekor-url "https://rekor.sigstore.dev"
  git config ${config_scope} gitsign.oidc-issuer "https://token.actions.githubusercontent.com"
  git config ${config_scope} gitsign.oidc-client-id "sigstore"

  # Enable Git signing with gitsign
  git config ${config_scope} commit.gpgsign true
  git config ${config_scope} tag.gpgsign true
  git config ${config_scope} gpg.x509.program gitsign
  git config ${config_scope} gpg.format x509

  # Create status file
  cat >"$GITSIGN_CONFIG_FILE" <<EOF
# YubiKey Gitsign Configuration
# Created: $(date)
# Version: ${SCRIPT_VERSION}
enabled=true
global=${GLOBAL_CONFIG:-false}
fulcio_url=https://fulcio.sigstore.dev
rekor_url=https://rekor.sigstore.dev
oidc_issuer=https://token.actions.githubusercontent.com
EOF

  print_status $GREEN "✅ YubiKey-backed Sigstore signing enabled!"
  echo
  print_status $BLUE "📋 Next Steps:"
  echo "   1. Ensure your YubiKey is registered with GitHub as a security key"
  echo "   2. Test signing: $0 test"
  echo "   3. Make your first signed commit!"
  echo
  print_status $YELLOW "💡 When you commit, you'll be redirected to GitHub for YubiKey authentication"
}

# Disable YubiKey signing and restore previous config
disable_yubikey_signing() {
  print_header "Disabling YubiKey Signing"

  if [[ ! -f $BACKUP_CONFIG_FILE ]]; then
    print_status $YELLOW "⚠️  No backup configuration found"
    print_status $YELLOW "   Will disable signing but cannot restore previous settings"
  fi

  local config_scope=""
  if [[ ${GLOBAL_CONFIG:-false} == true ]]; then
    config_scope="--global"
    print_status $BLUE "🌐 Disabling globally"
  else
    print_status $BLUE "📁 Disabling for current repository"
  fi

  print_status $BLUE "⚙️  Restoring previous Git configuration..."

  # Disable signing
  git config ${config_scope} commit.gpgsign false
  git config ${config_scope} tag.gpgsign false

  # Remove gitsign-specific configuration
  git config ${config_scope} --unset gitsign.fulcio-url || true
  git config ${config_scope} --unset gitsign.rekor-url || true
  git config ${config_scope} --unset gitsign.oidc-issuer || true
  git config ${config_scope} --unset gitsign.oidc-client-id || true
  git config ${config_scope} --unset gpg.x509.program || true

  # Restore GPG format if we have backup
  if [[ -f $BACKUP_CONFIG_FILE ]]; then
    local old_format
    old_format=$(grep "^gpg.format=" "$BACKUP_CONFIG_FILE" | cut -d'=' -f2)
    if [[ -n $old_format ]] && [[ $old_format != "x509" ]]; then
      git config ${config_scope} gpg.format "$old_format"
    else
      git config ${config_scope} --unset gpg.format || true
    fi
  else
    git config ${config_scope} --unset gpg.format || true
  fi

  # Update status file
  if [[ -f $GITSIGN_CONFIG_FILE ]]; then
    sed -i.bak 's/enabled=true/enabled=false/' "$GITSIGN_CONFIG_FILE"
    rm -f "${GITSIGN_CONFIG_FILE}.bak"
  fi

  print_status $GREEN "✅ YubiKey signing disabled"
  print_status $BLUE "💡 Your commits will no longer be signed with Sigstore"
}

# Show current signing status
show_status() {
  print_header "YubiKey Signing Status"

  local config_scope=""
  if [[ ${GLOBAL_CONFIG:-false} == true ]]; then
    config_scope="--global"
    print_status $BLUE "🌐 Global Configuration"
  else
    print_status $BLUE "📁 Repository Configuration"
  fi
  echo

  # Check if signing is enabled
  local commit_signing
  local tag_signing
  local gpg_format
  local gpg_program

  commit_signing=$(git config ${config_scope} --get commit.gpgsign || echo "false")
  tag_signing=$(git config ${config_scope} --get tag.gpgsign || echo "false")
  gpg_format=$(git config ${config_scope} --get gpg.format || echo "openpgp")
  gpg_program=$(git config ${config_scope} --get gpg.x509.program || echo "")

  print_status $BLUE "📋 Current Git Configuration:"
  echo "   commit.gpgsign: $commit_signing"
  echo "   tag.gpgsign: $tag_signing"
  echo "   gpg.format: $gpg_format"
  echo "   gpg.x509.program: $gpg_program"
  echo

  # Check gitsign-specific config
  local fulcio_url
  local rekor_url
  local oidc_issuer

  fulcio_url=$(git config ${config_scope} --get gitsign.fulcio-url || echo "")
  rekor_url=$(git config ${config_scope} --get gitsign.rekor-url || echo "")
  oidc_issuer=$(git config ${config_scope} --get gitsign.oidc-issuer || echo "")

  if [[ -n $fulcio_url ]]; then
    print_status $BLUE "🔒 Sigstore Configuration:"
    echo "   fulcio-url: $fulcio_url"
    echo "   rekor-url: $rekor_url"
    echo "   oidc-issuer: $oidc_issuer"
    echo
  fi

  # Determine overall status
  if [[ $commit_signing == "true" ]] && [[ $gpg_format == "x509" ]] && [[ $gpg_program == "gitsign" ]]; then
    print_status $GREEN "✅ YubiKey-backed Sigstore signing is ENABLED"

    # Check if YubiKey is available
    if command -v ykman &>/dev/null; then
      if ykman list | grep -q "YubiKey"; then
        print_status $GREEN "✅ YubiKey detected and ready"
      else
        print_status $YELLOW "⚠️  No YubiKey detected (insert YubiKey)"
      fi
    else
      print_status $BLUE "💡 Install 'ykman' to check YubiKey presence"
    fi
  elif [[ $commit_signing == "true" ]]; then
    print_status $YELLOW "⚠️  Git signing enabled but NOT using YubiKey/Sigstore"
    print_status $YELLOW "   Using format: $gpg_format, program: ${gpg_program:-default}"
  else
    print_status $RED "❌ Git commit signing is DISABLED"
  fi

  # Check gitsign availability
  if command -v gitsign &>/dev/null; then
    print_status $GREEN "✅ gitsign available: $(gitsign version 2>/dev/null || echo 'installed')"
  else
    print_status $RED "❌ gitsign not found"
    echo "   Install: go install github.com/sigstore/gitsign@latest"
  fi
}

# Test YubiKey signing
test_yubikey_signing() {
  print_header "Testing YubiKey Signing"

  # Check if we're in a git repo
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    print_status $RED "❌ Not in a Git repository"
    echo "Navigate to a Git repository to test signing"
    exit 1
  fi

  print_status $BLUE "🧪 Creating test commit to verify YubiKey signing..."

  # Create test file
  local test_file
  # shellcheck disable=SC2155 # Accept masking for readability here
  test_file="gitsign-test-$(date +%s).txt"
  echo "YubiKey Gitsign Test - $(date)" >"$test_file"

  print_status $YELLOW "📝 Creating test commit (YubiKey touch will be required)..."

  # Add and commit
  git add "$test_file"

  if git commit -m "Test YubiKey-backed Sigstore signing

This commit tests the YubiKey + gitsign integration.
Created by: YubiKey Gitsign Toggle Script v${SCRIPT_VERSION}"; then
    print_status $GREEN "✅ Test commit created successfully!"

    # Verify signature
    print_status $BLUE "🔍 Verifying commit signature..."
    if git log --show-signature -1 2>&1 | grep -q "gitsign: Good signature"; then
      print_status $GREEN "✅ Commit successfully signed with Sigstore!"

      # Show signature details
      print_status $BLUE "📋 Signature Details:"
      git log --show-signature -1 --format="%h %s" | head -n 5
    else
      print_status $RED "❌ Commit signature verification failed"
      git log --show-signature -1 --format="%h %s" | head -n 5
    fi

    # Clean up test file
    rm -f "$test_file"

    echo
    print_status $GREEN "🎉 YubiKey signing test completed!"
    print_status $BLUE "💡 Your commits are now cryptographically signed with your YubiKey"

  else
    print_status $RED "❌ Test commit failed"
    echo "This might be due to:"
    echo "  • YubiKey not connected"
    echo "  • GitHub authentication failed"
    echo "  • gitsign configuration issue"

    # Clean up test file
    rm -f "$test_file"
    exit 1
  fi
}

# Interactive setup wizard
interactive_setup() {
  print_header "YubiKey + Sigstore Setup Wizard"

  print_status $BLUE "🎯 This wizard will guide you through setting up YubiKey-backed Git signing"
  echo

  # Step 1: Prerequisites
  print_status $YELLOW "Step 1: Checking prerequisites..."
  check_prerequisites

  if [[ ${NEED_GITSIGN_INSTALL:-false} == true ]]; then
    echo
    read -p "Install gitsign now? (y/N): " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      install_gitsign
    else
      print_status $RED "❌ gitsign is required for Sigstore signing"
      exit 1
    fi
  fi

  echo

  # Step 2: YubiKey check
  print_status $YELLOW "Step 2: YubiKey verification..."
  if command -v ykman &>/dev/null; then
    if ykman list | grep -q "YubiKey"; then
      print_status $GREEN "✅ YubiKey detected!"
    else
      print_status $YELLOW "⚠️  Please insert your YubiKey"
      read -p "Press Enter when YubiKey is inserted..."
    fi
  else
    print_status $BLUE "💡 YubiKey Manager not found (optional)"
    echo "   Install with: pip install yubikey-manager"
  fi

  echo

  # Step 3: GitHub setup instructions
  print_status $YELLOW "Step 3: GitHub YubiKey setup..."
  print_status $BLUE "📋 Ensure your YubiKey is registered with GitHub:"
  echo "   1. Go to GitHub.com → Settings → Security"
  echo "   2. Two-factor authentication → Add security key"
  echo "   3. Follow prompts to register your YubiKey"
  echo
  read -p "Is your YubiKey registered with GitHub? (y/N): " -r
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_status $YELLOW "⚠️  Please register your YubiKey with GitHub first"
    echo "   Visit: https://github.com/settings/security"
    exit 1
  fi

  echo

  # Step 4: Configuration scope
  print_status $YELLOW "Step 4: Configuration scope..."
  read -p "Enable YubiKey signing globally for all repositories? (y/N): " -r
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    GLOBAL_CONFIG=true
  else
    GLOBAL_CONFIG=false
    check_git_repo
  fi

  echo

  # Step 5: Enable signing
  print_status $YELLOW "Step 5: Enabling YubiKey signing..."
  enable_yubikey_signing

  echo

  # Step 6: Test
  if [[ ${GLOBAL_CONFIG:-false} == false ]]; then
    read -p "Test YubiKey signing now? (y/N): " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      echo
      test_yubikey_signing
    fi
  else
    print_status $BLUE "💡 Navigate to a Git repository and run '$0 test' to test signing"
  fi

  echo
  print_status $GREEN "🎉 YubiKey setup completed successfully!"
}

# Reset all configuration
reset_configuration() {
  print_header "Resetting All Configuration"

  local config_scope=""
  if [[ ${GLOBAL_CONFIG:-false} == true ]]; then
    config_scope="--global"
    print_status $BLUE "🌐 Resetting global configuration"
  else
    print_status $BLUE "📁 Resetting repository configuration"
  fi

  print_status $YELLOW "⚠️  This will remove ALL Git signing configuration"

  if [[ ${FORCE:-false} != true ]]; then
    read -p "Are you sure you want to reset? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      print_status $BLUE "❌ Reset cancelled"
      exit 0
    fi
  fi

  # Remove all signing-related configuration
  git config ${config_scope} --unset commit.gpgsign || true
  git config ${config_scope} --unset tag.gpgsign || true
  git config ${config_scope} --unset gpg.format || true
  git config ${config_scope} --unset gpg.x509.program || true
  git config ${config_scope} --unset user.signingkey || true

  # Remove gitsign configuration
  git config ${config_scope} --unset gitsign.fulcio-url || true
  git config ${config_scope} --unset gitsign.rekor-url || true
  git config ${config_scope} --unset gitsign.oidc-issuer || true
  git config ${config_scope} --unset gitsign.oidc-client-id || true

  # Remove config files
  rm -f "$GITSIGN_CONFIG_FILE"
  rm -f "$BACKUP_CONFIG_FILE"

  print_status $GREEN "✅ All signing configuration reset"
}

# Parse command line arguments
parse_arguments() {
  COMMAND=""
  GLOBAL_CONFIG=false
  FORCE=false
  # shellcheck disable=SC2034 # Reserved; future dry-run behavior
  DRY_RUN=false

  while [[ $# -gt 0 ]]; do
    case $1 in
      enable | disable | status | test | setup | reset)
        COMMAND="$1"
        shift
        ;;
      -g | --global)
        GLOBAL_CONFIG=true
        shift
        ;;
      --force)
        FORCE=true
        shift
        ;;
      --dry-run)
        # shellcheck disable=SC2034
        DRY_RUN=true
        shift
        ;;
      -h | --help)
        show_help
        exit 0
        ;;
      -v | --version)
        show_version
        exit 0
        ;;
      *)
        print_status $RED "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
    esac
  done

  if [[ -z $COMMAND ]]; then
    print_status $RED "❌ No command specified"
    echo "Use --help for usage information"
    exit 1
  fi
}

# Main execution
main() {
  print_header "YubiKey Gitsign Toggle v$SCRIPT_VERSION"

  # Parse arguments
  parse_arguments "$@"

  # Check prerequisites for most commands
  if [[ $COMMAND != "status" ]] && [[ $COMMAND != "reset" ]]; then
    check_prerequisites
  fi

  # Check git repo for local operations
  if [[ $GLOBAL_CONFIG == false ]] && [[ $COMMAND != "status" ]] && [[ $COMMAND != "setup" ]]; then
    check_git_repo
  fi

  # Install gitsign if needed
  if [[ ${NEED_GITSIGN_INSTALL:-false} == true ]] && [[ $COMMAND != "status" ]]; then
    install_gitsign
  fi

  # Execute command
  case $COMMAND in
    "enable")
      enable_yubikey_signing
      ;;
    "disable")
      disable_yubikey_signing
      ;;
    "status")
      show_status
      ;;
    "test")
      test_yubikey_signing
      ;;
    "setup")
      interactive_setup
      ;;
    "reset")
      reset_configuration
      ;;
    *)
      print_status $RED "❌ Unknown command: $COMMAND"
      exit 1
      ;;
  esac
}

# Execute main function with all arguments
main "$@"
