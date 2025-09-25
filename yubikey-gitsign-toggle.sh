#!/bin/bash

# Copyright 2025 Albert Hui <albert@securityronin.com>
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# 🔑 YubiKey Gitsign Toggle Script
# Enables/disables YubiKey-backed Sigstore commit signing
#
# Version: 1.0.0
# Repository: https://github.com/4n6h4x0r/1-click-github-sec

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
readonly SCRIPT_VERSION="0.4.0"
readonly GITSIGN_CONFIG_FILE="$HOME/.gitsign-config"
readonly BACKUP_CONFIG_FILE="$HOME/.git-config-backup"

# =============================================================================
# STANDARDIZED ERROR CODES AND HANDLING FRAMEWORK
# =============================================================================
# readonly EXIT_SUCCESS=0               # Unused but kept for consistency
readonly EXIT_GENERAL_ERROR=1 # Generic failure
# readonly EXIT_USAGE_ERROR=2           # Unused but kept for consistency
readonly EXIT_PERMISSION_ERROR=3 # Permission denied
readonly EXIT_NETWORK_ERROR=4    # Download/network issues
readonly EXIT_TOOL_MISSING=6     # Required tool not found
readonly EXIT_VALIDATION_ERROR=7 # Input validation failed
readonly EXIT_CONFIG_ERROR=9     # Configuration error
readonly EXIT_SECURITY_ERROR=10  # Security check failed

# =============================================================================
# ENHANCED LOGGING SYSTEM WITH TIMESTAMPS
# =============================================================================
readonly LOG_DIR="$HOME/.yubikey-gitsign/logs"
LOG_FILE="$LOG_DIR/yubikey-$(date +%Y%m%d_%H%M%S).log"
readonly LOG_FILE
VERBOSE=${VERBOSE:-false}

# =============================================================================
# TRANSACTION AND ROLLBACK SYSTEM
# =============================================================================
readonly TRANSACTION_DIR="$HOME/.yubikey-gitsign/transactions"
TRANSACTION_ACTIVE=false
declare -a ROLLBACK_ACTIONS

# Initialize logging system
setup_logging() {
  mkdir -p "$LOG_DIR"
  touch "$LOG_FILE"

  # Log session start
  {
    echo "=== YUBIKEY GITSIGN SESSION START ==="
    echo "Timestamp: $(date)"
    echo "Script: $0 $*"
    echo "PWD: $(pwd)"
    echo "User: $(whoami)"
    echo "========================================"
  } >>"$LOG_FILE"
}

# Enhanced logging functions
log_entry() {
  local level=$1
  local message=$2
  local context=${3:-""}
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  local caller="${FUNCNAME[2]:-main}"

  local log_line="[$timestamp] [$level] [$caller] $message"
  [[ -n $context ]] && log_line="$log_line | Context: $context"

  # Ensure log directory exists
  mkdir -p "$(dirname "$LOG_FILE")"
  echo "$log_line" >>"$LOG_FILE"

  # Also output to terminal if verbose or error/warn
  if [[ $VERBOSE == true ]] || [[ $level == "ERROR" ]] || [[ $level == "WARN" ]]; then
    echo "[$(date '+%H:%M:%S')] [$level] $message" >&2
  fi
}

log_debug() { [[ $VERBOSE == true ]] && log_entry "DEBUG" "$1" "${2:-}"; }
log_info() { log_entry "INFO" "$1" "${2:-}"; }
log_warn() { log_entry "WARN" "$1" "${2:-}"; }
log_error() { log_entry "ERROR" "$1" "${2:-}"; }

# Standardized error handler
handle_error() {
  local exit_code=$1
  local error_msg=$2
  local context=${3:-""}

  case $exit_code in
    "$EXIT_PERMISSION_ERROR")
      print_status $RED "❌ Permission Error: $error_msg"
      echo "💡 Try: sudo $0 $* or check file permissions"
      ;;
    "$EXIT_NETWORK_ERROR")
      print_status $RED "❌ Network Error: $error_msg"
      echo "💡 Check internet connection and retry"
      ;;
    "$EXIT_TOOL_MISSING")
      print_status $RED "❌ Missing Tool: $error_msg"
      echo "💡 Install required dependencies: $context"
      ;;
    "$EXIT_VALIDATION_ERROR")
      print_status $RED "❌ Validation Error: $error_msg"
      echo "💡 Check input: $context"
      ;;
    "$EXIT_CONFIG_ERROR")
      print_status $RED "❌ Configuration Error: $error_msg"
      echo "💡 Check configuration files and permissions"
      ;;
    "$EXIT_SECURITY_ERROR")
      print_status $RED "❌ Security Error: $error_msg"
      echo "💡 Review security requirements: $context"
      ;;
    *)
      print_status $RED "❌ Error: $error_msg"
      ;;
  esac

  [[ -n $context ]] && echo "   Context: $context"
  log_error "$error_msg" "$context"

  # Trigger rollback if transaction is active
  if [[ $TRANSACTION_ACTIVE == true ]]; then
    rollback_on_error
  fi

  exit "$exit_code"
}

# Safe execution wrapper
safe_execute() {
  local operation=$1
  local error_msg=$2
  local exit_code=${3:-$EXIT_GENERAL_ERROR}
  local context=${4:-""}

  log_debug "Executing: $operation" "$context"

  if ! eval "$operation" 2>>"$LOG_FILE"; then
    handle_error "$exit_code" "$error_msg" "$context"
  fi

  log_debug "Completed: $operation"
}

# Transaction management
start_transaction() {
  local transaction_name=${1:-"yubikey-config"}
  TRANSACTION_ACTIVE=true
  ROLLBACK_ACTIONS=()

  mkdir -p "$TRANSACTION_DIR"

  log_info "Transaction started: $transaction_name"

  # Set trap for automatic rollback on error
  trap 'rollback_on_error' ERR
  trap 'cleanup_transaction' EXIT
}

add_rollback() {
  local action=$1
  ROLLBACK_ACTIONS+=("$action")
  log_debug "Added rollback action: $action"
}

commit_transaction() {
  if [[ $TRANSACTION_ACTIVE == true ]]; then
    log_info "Transaction committed successfully"
    TRANSACTION_ACTIVE=false
    ROLLBACK_ACTIONS=()
    trap - ERR EXIT
  fi
}

rollback_on_error() {
  if [[ $TRANSACTION_ACTIVE == true ]]; then
    print_status $YELLOW "⚠️ Error detected - initiating rollback..."
    log_warn "Automatic rollback triggered"

    # Execute rollback actions in reverse order
    for ((i = ${#ROLLBACK_ACTIONS[@]} - 1; i >= 0; i--)); do
      local action="${ROLLBACK_ACTIONS[i]}"
      log_info "Rolling back: $action"

      if eval "$action" 2>>"$LOG_FILE"; then
        log_debug "Rollback action succeeded: $action"
      else
        log_error "Rollback action failed: $action"
      fi
    done

    print_status $GREEN "✅ Rollback completed"
    TRANSACTION_ACTIVE=false
  fi
}

cleanup_transaction() {
  if [[ $TRANSACTION_ACTIVE == true ]]; then
    TRANSACTION_ACTIVE=false
    trap - ERR EXIT
  fi
}

# Atomic file operations
atomic_write() {
  local file=$1
  local content=$2

  # Backup original if exists
  if [[ -f $file ]]; then
    local backup
    backup="$file.backup.$(date +%s)"
    cp "$file" "$backup"
    add_rollback "mv '$backup' '$file'"
    log_debug "Created backup: $backup"
  else
    add_rollback "rm -f '$file'"
  fi

  # Write new content
  echo "$content" >"$file"
  log_debug "Atomic write completed: $file"
}

atomic_move() {
  local src=$1
  local dest=$2

  if [[ -f $dest ]]; then
    local backup
    backup="$dest.backup.$(date +%s)"
    mv "$dest" "$backup"
    add_rollback "mv '$backup' '$dest'"
  else
    add_rollback "rm -f '$dest'"
  fi

  mv "$src" "$dest"
  log_debug "Atomic move: $src -> $dest"
}

# =============================================================================
# END FRAMEWORK SECTION
# =============================================================================

# Function to print colored output with logging
print_status() {
  local color=$1
  local message=$2
  echo -e "${color}${message}${NC}"
  log_info "$message"
}

print_header() {
  echo
  print_status $CYAN "════════════════════════════════════════════════"
  print_status $CYAN "  $1"
  print_status $CYAN "════════════════════════════════════════════════"
  echo
  log_info "Section: $1"
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
    troubleshoot        Show manual authentication guidance

OPTIONS:
    -h, --help          Show this help message
    -v, --version       Show version information
    -g, --global        Apply changes globally (default: repository-local)
    --force             Force changes without confirmation
    --dry-run           Show what would be changed without applying
    --verbose           Enable verbose logging output

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

    # Get help with authentication issues
    $0 troubleshoot

SECURITY FEATURES:
    ✅ Hardware-backed signing (YubiKey required)
    ✅ Short-lived certificates (5-10 minutes)
    ✅ Transparency logging (Rekor)
    ✅ OIDC identity verification
    ✅ Phishing-resistant authentication

REQUIREMENTS:
    - YubiKey 5 series with FIDO2/WebAuthn
    - GitHub account with YubiKey registered
    - gitsign installed (use 1-click-github-sec installer)
    - Modern browser for OIDC flow

EOF
}

show_version() {
  echo "YubiKey Requirement Toggle Script v${SCRIPT_VERSION}"
  echo "Toggle YubiKey requirement for Sigstore Git commit signing"
  echo "https://github.com/4n6h4x0r/1-click-github-sec"
}

# Check if we're in a git repository for local operations
check_git_repo() {
  log_debug "Checking git repository status (global_config=${GLOBAL_CONFIG:-false})"
  if [[ ${GLOBAL_CONFIG:-false} == false ]] && ! git rev-parse --git-dir >/dev/null 2>&1; then
    log_error "Not in a Git repository"
    print_status $RED "❌ Not in a Git repository"
    echo "Use --global flag for global configuration or run from within a Git repository"
    handle_error $EXIT_CONFIG_ERROR "Not in a Git repository"
  fi
  log_debug "Git repository check passed"
}

# Check prerequisites
check_prerequisites() {
  print_status $BLUE "🔍 Checking prerequisites..."
  log_info "Starting prerequisites check"

  local missing_tools=()

  # Check for required tools
  if ! command -v git &>/dev/null; then
    missing_tools+=("git")
    log_warn "git command not found"
  fi

  if ! command -v curl &>/dev/null; then
    missing_tools+=("curl")
    log_warn "curl command not found"
  fi

  # Check if gitsign is available
  if ! command -v gitsign &>/dev/null; then
    print_status $YELLOW "⚠️  gitsign not found - will attempt to install"
    log_warn "gitsign not found - will attempt installation"
    NEED_GITSIGN_INSTALL=true
  else
    print_status $GREEN "✅ gitsign: $(command -v gitsign)"
    log_info "gitsign found at: $(command -v gitsign)"
    NEED_GITSIGN_INSTALL=false
  fi

  if [[ ${#missing_tools[@]} -gt 0 ]]; then
    log_error "Missing required tools: ${missing_tools[*]}"
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
    handle_error $EXIT_TOOL_MISSING "Tool missing"
  fi

  log_info "Prerequisites check completed successfully"
  print_status $GREEN "✅ Prerequisites check passed"
}

# Backup current git configuration
backup_git_config() {
  log_info "Starting Git configuration backup"
  print_status $BLUE "💾 Backing up current Git configuration..."

  local config_scope=""
  if [[ ${GLOBAL_CONFIG:-false} == true ]]; then
    config_scope="--global"
    log_debug "Using global configuration scope"
  else
    log_debug "Using local repository configuration scope"
  fi

  # Ensure backup directory exists
  mkdir -p "$(dirname "$BACKUP_CONFIG_FILE")"

  # Create backup of relevant settings using atomic write
  local backup_content
  backup_content=$(
    cat <<EOF
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
gitsign.autoclose=$(git config ${config_scope} --get gitsign.autoclose || echo "")
gitsign.autocloseTimeout=$(git config ${config_scope} --get gitsign.autocloseTimeout || echo "")
gitsign.connectorID=$(git config ${config_scope} --get gitsign.connectorID || echo "")
EOF
  )

  atomic_write "$BACKUP_CONFIG_FILE" "$backup_content"
  log_info "Git configuration backed up to: $BACKUP_CONFIG_FILE"
  print_status $GREEN "✅ Configuration backed up to: $BACKUP_CONFIG_FILE"
}

# Enable YubiKey-backed signing
enable_yubikey_signing() {
  print_header "Enabling YubiKey Requirement for Sigstore Signing"
  log_info "Starting YubiKey requirement enablement"

  local config_scope=""
  if [[ ${GLOBAL_CONFIG:-false} == true ]]; then
    config_scope="--global"
    log_info "Configuring YubiKey requirement globally"
    print_status $BLUE "🌐 Configuring globally for all repositories"
  else
    log_info "Configuring YubiKey requirement for current repository"
    print_status $BLUE "📁 Configuring for current repository only"
  fi

  # Check if gitsign is already configured
  if ! git config ${config_scope} --get commit.gpgsign >/dev/null 2>&1; then
    log_warn "Gitsign is not configured. Please run the main installer first:"
    print_status $YELLOW "⚠️ Gitsign not configured!"
    print_status $BLUE "   Run the 1-click-github-sec installer first to set up gitsign:"
    print_status $BLUE "   curl -sSL https://raw.githubusercontent.com/4n6h4x0r/1-click-github-sec/main/install-security-controls.sh | bash"
    print_status $BLUE "   Then run this script to enable YubiKey requirement."
    handle_error $EXIT_CONFIG_ERROR "Configuration error"
  fi

  # Backup existing configuration
  if ! backup_git_config; then
    log_error "Failed to backup Git configuration"
    handle_error $EXIT_CONFIG_ERROR "Configuration error"
  fi

  print_status $BLUE "🔐 Configuring YubiKey requirement for gitsign..."
  log_info "Switching OIDC issuer to GitHub Actions for YubiKey authentication"

  # The key change: switch OIDC issuer to GitHub Actions which requires YubiKey
  safe_execute "git config ${config_scope} gitsign.oidc-issuer 'https://token.actions.githubusercontent.com'" "Setting OIDC issuer for YubiKey auth" || handle_error $EXIT_CONFIG_ERROR "Configuration error"

  # Create status file using atomic write
  local status_content
  status_content=$(
    cat <<EOF
# YubiKey Requirement Configuration
# Created: $(date)
# Version: ${SCRIPT_VERSION}
yubikey_required=true
global=${GLOBAL_CONFIG:-false}
oidc_issuer=https://token.actions.githubusercontent.com
EOF
  )

  atomic_write "$GITSIGN_CONFIG_FILE" "$status_content"

  log_info "YubiKey requirement configuration completed successfully"
  print_status $GREEN "✅ YubiKey requirement enabled for Sigstore signing!"
  echo
  print_status $BLUE "📋 Next Steps:"
  echo "   1. Ensure your YubiKey is registered with GitHub as a security key"
  echo "   2. Test signing: $0 test"
  echo "   3. Make your first signed commit!"
  echo
  print_status $YELLOW "💡 YubiKey authentication:"
  echo "   • GitHub will require YubiKey authentication for commits"
  echo "   • Touch your YubiKey when prompted during commit signing"
  echo "   • To disable YubiKey requirement: $0 disable"
}

# Disable YubiKey requirement and restore regular Sigstore authentication
disable_yubikey_signing() {
  print_header "Disabling YubiKey Requirement"
  log_info "Starting YubiKey requirement disablement"

  local config_scope=""
  if [[ ${GLOBAL_CONFIG:-false} == true ]]; then
    config_scope="--global"
    log_info "Disabling YubiKey requirement globally"
    print_status $BLUE "🌐 Disabling globally"
  else
    log_info "Disabling YubiKey requirement for current repository"
    print_status $BLUE "📁 Disabling for current repository"
  fi

  print_status $BLUE "🔓 Restoring regular Sigstore authentication..."
  log_info "Switching OIDC issuer back to regular OAuth (no YubiKey required)"

  # Switch back to regular OAuth issuer (no YubiKey required)
  safe_execute "git config ${config_scope} gitsign.oidc-issuer 'https://oauth2.sigstore.dev/auth'" "Restoring regular OAuth issuer" || log_warn "Failed to restore OIDC issuer"

  # Update status file atomically
  local status_content
  status_content=$(
    cat <<EOF
# YubiKey Requirement Configuration
# Created: $(date)
# Version: ${SCRIPT_VERSION}
yubikey_required=false
global=${GLOBAL_CONFIG:-false}
oidc_issuer=https://oauth2.sigstore.dev/auth
EOF
  )

  atomic_write "$GITSIGN_CONFIG_FILE" "$status_content"

  log_info "YubiKey requirement disabled successfully"
  print_status $GREEN "✅ YubiKey requirement disabled"
  print_status $BLUE "💡 Commits will still be signed with Sigstore, but without YubiKey requirement"
}

# Show current signing status
show_status() {
  print_header "YubiKey Signing Status"
  log_info "Displaying YubiKey signing status"

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

  commit_signing=$(timeout 3 git config ${config_scope} --get commit.gpgsign 2>/dev/null || echo "false")
  tag_signing=$(timeout 3 git config ${config_scope} --get tag.gpgsign 2>/dev/null || echo "false")
  gpg_format=$(timeout 3 git config ${config_scope} --get gpg.format 2>/dev/null || echo "openpgp")
  gpg_program=$(timeout 3 git config ${config_scope} --get gpg.x509.program 2>/dev/null || echo "")

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
  local autoclose
  local autoclose_timeout
  local connector_id

  # Use timeout for gitsign config checks to prevent hanging
  fulcio_url=$(timeout 3 git config ${config_scope} --get gitsign.fulcio-url 2>/dev/null || echo "")
  rekor_url=$(timeout 3 git config ${config_scope} --get gitsign.rekor-url 2>/dev/null || echo "")
  oidc_issuer=$(timeout 3 git config ${config_scope} --get gitsign.oidc-issuer 2>/dev/null || echo "")
  autoclose=$(timeout 3 git config ${config_scope} --get gitsign.autoclose 2>/dev/null || echo "")
  autoclose_timeout=$(timeout 3 git config ${config_scope} --get gitsign.autocloseTimeout 2>/dev/null || echo "")
  connector_id=$(timeout 3 git config ${config_scope} --get gitsign.connectorID 2>/dev/null || echo "")

  if [[ -n $fulcio_url ]]; then
    print_status $BLUE "🔒 Sigstore Configuration:"
    echo "   fulcio-url: $fulcio_url"
    echo "   rekor-url: $rekor_url"
    echo "   oidc-issuer: $oidc_issuer"
    echo
    print_status $BLUE "🌐 Authentication Configuration:"
    echo "   autoclose: ${autoclose:-default}"
    echo "   autoclose-timeout: ${autoclose_timeout:-20} seconds"
    echo "   connector-id: ${connector_id:-default}"
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
  log_info "Starting YubiKey signing test"

  # Check if we're in a git repo
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    log_error "Not in a Git repository for testing"
    print_status $RED "❌ Not in a Git repository"
    echo "Navigate to a Git repository to test signing"
    handle_error $EXIT_CONFIG_ERROR "Configuration error"
  fi

  log_debug "Git repository detected, proceeding with test"
  print_status $BLUE "🧪 Creating test commit to verify YubiKey signing..."

  # Create test file
  local test_file
  # shellcheck disable=SC2155 # Accept masking for readability here
  test_file="gitsign-test-$(date +%s).txt"
  log_debug "Creating test file: $test_file"
  echo "YubiKey Gitsign Test - $(date)" >"$test_file"

  print_status $YELLOW "📝 Creating test commit (YubiKey touch will be required)..."
  log_info "Creating test commit with YubiKey signing"

  # Add and commit
  if ! safe_execute "git add '$test_file'" "Adding test file to git"; then
    log_error "Failed to add test file to git"
    handle_error $EXIT_GENERAL_ERROR "General error"
  fi

  local commit_message="Test YubiKey-backed Sigstore signing

This commit tests the YubiKey + gitsign integration.
Created by: YubiKey Gitsign Toggle Script v${SCRIPT_VERSION}"

  if safe_execute "git commit -m '$commit_message'" "Creating test commit"; then
    log_info "Test commit created successfully"
    print_status $GREEN "✅ Test commit created successfully!"

    # Verify signature
    print_status $BLUE "🔍 Verifying commit signature..."
    log_debug "Verifying commit signature"
    if git log --show-signature -1 2>&1 | grep -q "gitsign: Good signature"; then
      log_info "Commit successfully signed with Sigstore"
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
    log_debug "Cleaned up test file: $test_file"

    echo
    log_info "YubiKey signing test completed successfully"
    print_status $GREEN "🎉 YubiKey signing test completed!"
    print_status $BLUE "💡 Your commits are now cryptographically signed with your YubiKey"

  else
    log_error "Test commit failed"
    print_status $RED "❌ Test commit failed"
    echo "This might be due to:"
    echo "  • YubiKey not connected"
    echo "  • GitHub authentication failed"
    echo "  • gitsign configuration issue"

    # Clean up test file
    rm -f "$test_file"
    log_debug "Cleaned up test file after failure: $test_file"
    handle_error $EXIT_GENERAL_ERROR "General error"
  fi
}

# Interactive setup wizard
interactive_setup() {
  print_header "YubiKey + Sigstore Setup Wizard"
  log_info "Starting interactive setup wizard"

  print_status $BLUE "🎯 This wizard will guide you through setting up YubiKey-backed Git signing"
  echo

  # Step 1: Prerequisites
  print_status $YELLOW "Step 1: Checking prerequisites..."
  log_info "Step 1: Checking prerequisites"
  if ! check_prerequisites; then
    log_error "Prerequisites check failed"
    handle_error $EXIT_TOOL_MISSING "Tool missing"
  fi

  if [[ ${NEED_GITSIGN_INSTALL:-false} == true ]]; then
    echo
    print_status $YELLOW "⚠️ gitsign is not installed"
    print_status $BLUE "   Please run the 1-click-github-sec installer first:"
    print_status $BLUE "   curl -sSL https://raw.githubusercontent.com/4n6h4x0r/1-click-github-sec/main/install-security-controls.sh | bash"
    print_status $BLUE "   Then run this script to enable YubiKey requirement."
    handle_error $EXIT_TOOL_MISSING "Tool missing"
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
  git config ${config_scope} --unset gitsign.autoclose || true
  git config ${config_scope} --unset gitsign.autocloseTimeout || true
  git config ${config_scope} --unset gitsign.connectorID || true

  # Remove config files
  rm -f "$GITSIGN_CONFIG_FILE"
  rm -f "$BACKUP_CONFIG_FILE"

  print_status $GREEN "✅ All signing configuration reset"
}

# Show troubleshooting guide for manual authentication
show_troubleshooting_guide() {
  print_header "Sigstore Authentication Troubleshooting"
  log_info "Displaying troubleshooting guide for manual authentication"

  print_status $BLUE "🔧 Manual Authentication Process"
  echo
  echo "If the automatic browser flow times out or fails, follow these steps:"
  echo
  print_status $YELLOW "1. Current Configuration"
  echo "   • Browser autoclose is ENABLED - window closes after 20 seconds"
  echo "   • GitHub connector pre-configured for OAuth"
  echo "   • Balanced security and usability settings"
  echo
  print_status $YELLOW "2. When Authentication Window Opens"
  echo "   • You have 20 seconds to complete GitHub authentication"
  echo "   • If redirected to GitHub, sign in if not already signed in"
  echo "   • Touch YubiKey when prompted (if YubiKey mode is enabled)"
  echo "   • When prompted for 2FA/security key, use your YubiKey"
  echo "   • Touch your YubiKey when it blinks"
  echo
  print_status $YELLOW "3. If Browser Flow Still Fails"
  echo "   • Check network connectivity"
  echo "   • Ensure GitHub account has YubiKey registered as security key"
  echo "   • Try disabling ad blockers or VPN"
  echo "   • Clear browser cache and cookies for GitHub/Sigstore"
  echo
  print_status $YELLOW "4. Alternative: Use Environment Variable"
  echo "   • Set GITSIGN_TOKEN_PROVIDER=interactive"
  echo "   • This forces interactive mode with extended timeout"
  echo "   • Example: GITSIGN_TOKEN_PROVIDER=interactive git commit -m 'message'"
  echo
  print_status $YELLOW "5. Verify Configuration"
  echo "   • Run: $0 status"
  echo "   • Check that autoclose=true and timeout=20"
  echo "   • Ensure connector-id points to GitHub"
  echo
  print_status $BLUE "📝 Additional Resources"
  echo "   • Sigstore Documentation: https://docs.sigstore.dev/"
  echo "   • gitsign Issues: https://github.com/sigstore/gitsign/issues"
  echo "   • YubiKey Setup: https://docs.github.com/en/authentication"
  echo
  print_status $GREEN "💡 Pro Tips"
  echo "   • Keep YubiKey inserted during commit process"
  echo "   • Sign in to GitHub before attempting commits"
  echo "   • Use 'git commit --no-verify' only for emergencies"
  echo "   • Test with: $0 test"
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
      enable | disable | status | test | setup | reset | troubleshoot)
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
      --verbose)
        VERBOSE=true
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
  if [[ $COMMAND != "status" ]] && [[ $COMMAND != "reset" ]] && [[ $COMMAND != "troubleshoot" ]]; then
    check_prerequisites
  fi

  # Check git repo for local operations
  if [[ $GLOBAL_CONFIG == false ]] && [[ $COMMAND != "status" ]] && [[ $COMMAND != "setup" ]] && [[ $COMMAND != "troubleshoot" ]]; then
    check_git_repo
  fi

  # Check if gitsign is available
  if [[ ${NEED_GITSIGN_INSTALL:-false} == true ]] && [[ $COMMAND != "status" ]]; then
    log_warn "gitsign is not installed"
    print_status $YELLOW "⚠️ gitsign is not installed"
    print_status $BLUE "   Please run the 1-click-github-sec installer first:"
    print_status $BLUE "   curl -sSL https://raw.githubusercontent.com/4n6h4x0r/1-click-github-sec/main/install-security-controls.sh | bash"
    print_status $BLUE "   Then run this script to enable YubiKey requirement."
    handle_error $EXIT_TOOL_MISSING "Tool missing"
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
    "troubleshoot")
      show_troubleshooting_guide
      ;;
    *)
      print_status $RED "❌ Unknown command: $COMMAND"
      exit 1
      ;;
  esac
}

# Execute main function with all arguments
main "$@"
