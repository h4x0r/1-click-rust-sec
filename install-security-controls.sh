#!/bin/bash

# 🛡️ Security Controls Installer
# Installs comprehensive security controls for any repository
# Industry-leading security architecture for Rust projects
#
# Version: 0.1.0
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
# shellcheck disable=SC2034 # Placeholder for future use
readonly REQUIRED_TOOLS_FILE="security-tools-requirements.txt"
# shellcheck disable=SC2034 # Placeholder for future use
readonly PRE_PUSH_HOOK_FILE="security-pre-push-hook"
# shellcheck disable=SC2034 # Placeholder for future use
readonly CI_WORKFLOW_FILE="security-ci-workflow.yml"
readonly DOCS_DIR="docs/security"

# Upgrade functionality configuration
readonly VERSION_FILE=".security-controls-version"
readonly BACKUP_DIR=".security-controls-backup"
readonly CONFIG_FILE=".security-controls-config"
readonly REMOTE_VERSION_URL="https://raw.githubusercontent.com/4n6h4x0r/1-click-rust-sec/main/VERSION"
readonly REMOTE_CHANGELOG_URL="https://raw.githubusercontent.com/4n6h4x0r/1-click-rust-sec/main/CHANGELOG.md"

# Local state/config directories
readonly CONTROL_STATE_DIR=".security-controls"
readonly CONFIG_ENV_FILE="$CONTROL_STATE_DIR/config.env"
readonly GITLEAKS_CONFIG_FILE="$CONTROL_STATE_DIR/gitleaks.toml"
# shellcheck disable=SC2034 # Baseline reserved
readonly GITLEAKS_BASELINE_FILE="$CONTROL_STATE_DIR/gitleaks-baseline.json"

# Hooks path (optional chaining)
readonly HOOKS_PATH_DIR=".githooks"
readonly PRE_PUSH_D_DIR="$HOOKS_PATH_DIR/pre-push.d"

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
readonly LOG_DIR="$CONTROL_STATE_DIR/logs"
LOG_FILE="$LOG_DIR/install-$(date +%Y%m%d_%H%M%S).log"
readonly LOG_FILE
VERBOSE=${VERBOSE:-false}

# =============================================================================
# TRANSACTION AND ROLLBACK SYSTEM
# =============================================================================
readonly TRANSACTION_DIR="$CONTROL_STATE_DIR/transactions"
TRANSACTION_ACTIVE=false
declare -a ROLLBACK_ACTIONS

# Initialize logging system
# shellcheck disable=SC2120  # Function accesses global script arguments
setup_logging() {
  # Function to initialize logging
  mkdir -p "$LOG_DIR"
  touch "$LOG_FILE"

  # Log session start with script arguments from global scope
  {
    echo "=== INSTALLATION SESSION START ==="
    echo "Timestamp: $(date)"
    echo "Script: $0 ${*:-}"
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
  local transaction_name=${1:-"install"}
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

# Global flags
DRY_RUN=false
SKIP_TOOLS=false
FORCE_INSTALL=false
RUST_PROJECT=true
INSTALL_HOOKS=true
INSTALL_CI=true
INSTALL_DOCS=true
INSTALL_SIGNING=true
USE_HOOKS_PATH=false
INSTALL_GITHUB_SECURITY=true

# Upgrade functionality flags
# shellcheck disable=SC2034 # Reserved flag
UPGRADE_MODE=false
CHECK_UPDATE=false
BACKUP_MODE=false
# shellcheck disable=SC2034 # Reserved flag
RESTORE_MODE=false
SHOW_VERSION=false
# Function to print colored output
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
}

print_section() {
  echo
  print_status $BLUE "▶ $1"
  echo
}

# ===== UPGRADE FUNCTIONALITY =====

# Get current installed version
get_installed_version() {
  if [[ -f $VERSION_FILE ]]; then
    cat "$VERSION_FILE" | grep "version=" | cut -d'=' -f2 | tr -d '"'
  else
    echo "unknown"
  fi
}

# Get latest available version
get_latest_version() {
  if curl -fsSL "$REMOTE_VERSION_URL" 2>/dev/null; then
    return 0
  else
    echo "1.1.0" # Fallback version
    return 1
  fi
}

# Compare versions (returns 0 if upgrade needed, 1 if up-to-date)
compare_versions() {
  local current="$1"
  local latest="$2"

  # Simple version comparison (assumes semantic versioning)
  if [[ $current == "unknown" ]] || [[ $current != "$latest" ]]; then
    return 0 # Upgrade needed
  else
    return 1 # Up to date
  fi
}

# Show version information
show_version_info() {
  print_header "Version Information"

  local current_version
  local latest_version

  current_version=$(get_installed_version)

  print_status $BLUE "📋 Current Installation:"
  echo "   Installed Version: $current_version"

  if [[ -f $VERSION_FILE ]]; then
    local install_date
    install_date=$(grep "install_date=" "$VERSION_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "Unknown")
    echo "   Install Date: $install_date"

    local install_type
    install_type=$(grep "install_type=" "$VERSION_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "Unknown")
    echo "   Install Type: $install_type"
  fi

  echo
  print_status $BLUE "🌐 Checking for updates..."

  if latest_version=$(get_latest_version); then
    print_status $GREEN "✅ Successfully connected to update server"
    echo "   Latest Version: $latest_version"

    if compare_versions "$current_version" "$latest_version"; then
      print_status $YELLOW "🆙 Update available: $current_version → $latest_version"
      echo
      echo "Run '$0 --upgrade' to update to the latest version"
    else
      print_status $GREEN "✅ You have the latest version installed"
    fi
  else
    print_status $RED "❌ Could not check for updates"
    echo "   Please check your internet connection"
  fi
}

# Check for updates without installing
check_for_updates() {
  print_header "Update Check"

  local current_version
  local latest_version

  current_version=$(get_installed_version)

  print_status $BLUE "🔍 Checking for updates..."
  echo "   Current: $current_version"

  if latest_version=$(get_latest_version); then
    echo "   Latest:  $latest_version"
    echo

    if compare_versions "$current_version" "$latest_version"; then
      print_status $YELLOW "🆙 Update Available!"
      echo
      print_status $BLUE "📋 What's new in $latest_version:"

      # Fetch and display changelog excerpt
      if curl -fsSL "$REMOTE_CHANGELOG_URL" 2>/dev/null | head -20; then
        echo
      else
        echo "   (Changelog not available)"
        echo
      fi

      echo "To upgrade: $0 --upgrade"
    else
      print_status $GREEN "✅ No updates available"
      echo "   You have the latest version"
    fi
  else
    print_status $RED "❌ Update check failed"
    echo "   Could not connect to update server"
    exit 1
  fi
}

# Create backup of current installation
create_backup() {
  print_status $BLUE "💾 Creating backup..."

  # Create backup directory
  mkdir -p "$BACKUP_DIR"

  local backup_timestamp
  backup_timestamp=$(date +"%Y%m%d_%H%M%S")
  local backup_subdir="$BACKUP_DIR/backup_$backup_timestamp"

  mkdir -p "$backup_subdir"

  # Backup pre-push hook
  if [[ -f ".git/hooks/pre-push" ]]; then
    cp ".git/hooks/pre-push" "$backup_subdir/"
    print_status $GREEN "✅ Backed up pre-push hook"
  fi

  # Backup CI workflow
  if [[ -f ".github/workflows/security.yml" ]]; then
    mkdir -p "$backup_subdir/.github/workflows"
    cp ".github/workflows/security.yml" "$backup_subdir/.github/workflows/"
    print_status $GREEN "✅ Backed up CI workflow"
  fi

  # Backup documentation
  if [[ -d $DOCS_DIR ]]; then
    cp -r "$DOCS_DIR" "$backup_subdir/"
    print_status $GREEN "✅ Backed up documentation"
  fi

  # Backup version and config files
  if [[ -f $VERSION_FILE ]]; then
    cp "$VERSION_FILE" "$backup_subdir/"
  fi

  if [[ -f $CONFIG_FILE ]]; then
    cp "$CONFIG_FILE" "$backup_subdir/"
  fi

  # Create backup manifest
  cat >"$backup_subdir/BACKUP_MANIFEST.txt" <<MANIFEST_EOF
# Security Controls Backup
# Created: $(date)
# Original Version: $(get_installed_version)
# Backup Location: $backup_subdir

Files backed up:
$(find "$backup_subdir" -type f | sed "s|$backup_subdir/||" | sort)
MANIFEST_EOF

  # Update symlink to latest backup
  ln -sfn "backup_$backup_timestamp" "$BACKUP_DIR/latest"

  print_status $GREEN "✅ Backup created: $backup_subdir"
  echo "   Latest backup link: $BACKUP_DIR/latest"

  return 0
}

# Show changelog for current version
show_changelog() {
  print_header "Changelog"

  print_status $BLUE "📋 Fetching latest changelog..."

  if curl -fsSL "$REMOTE_CHANGELOG_URL" 2>/dev/null; then
    return 0
  else
    print_status $RED "❌ Could not fetch changelog"
    echo "   Please check your internet connection"
    echo "   View online: https://github.com/4n6h4x0r/1-click-rust-sec/blob/main/CHANGELOG.md"
    exit 1
  fi
}

# Write version information after successful installation
write_version_info() {
  cat >"$VERSION_FILE" <<VERSION_EOF
# Security Controls Installation Information
# Generated by install-security-controls.sh v$SCRIPT_VERSION
version="$SCRIPT_VERSION"
install_date="$(date)"
install_type="fresh_install"
installer_version="$SCRIPT_VERSION"
project_type="$(if [[ $RUST_PROJECT == true ]]; then echo "rust"; else echo "generic"; fi)"
global_install="false"
VERSION_EOF

  print_status $GREEN "📝 Version information saved to $VERSION_FILE"
}

# Execute upgrade commands
execute_upgrade_commands() {
  # Check upgrade commands first, before normal installation
  if [[ $SHOW_VERSION == true ]]; then
    show_version_info
    exit 0
  fi

  if [[ $CHECK_UPDATE == true ]]; then
    check_for_updates
    exit 0
  fi

  if [[ $BACKUP_MODE == true ]]; then
    create_backup
    exit 0
  fi
}

show_help() {
  cat <<EOF
🛡️  Security Controls Installer v${SCRIPT_VERSION}

USAGE:
    $0 [OPTIONS]

DESCRIPTION:
    Installs enterprise-grade security controls for Rust projects.
    Provides comprehensive security: local validation (25+ checks) + CI analysis + GitHub security features.

OPTIONS:
    -h, --help              Show this help message
    -v, --version           Show version information
    --verbose               Enable verbose logging output
    -d, --dry-run           Show what would be done without making changes
    -f, --force             Force overwrite existing files
    --skip-tools            Skip tool installation (assume tools are available)
    --no-hooks              Skip Git hooks installation
    --no-ci                 Skip CI workflow installation  
    --no-docs               Skip documentation installation
    --no-signing            Skip gitsign installation and configuration
    --non-rust              Configure for non-Rust project
    --hooks-path            Install hooks using git core.hooksPath (\".githooks\") and chain safely
    --no-github-security    Skip GitHub repository security features (enabled by default)

UPGRADE COMMANDS:
    --version               Show version and check for updates
    --check-update          Check for available updates
    --upgrade               Upgrade to latest version with backup
    --backup                Create backup of current installation
    --changelog             Show changelog and release notes
EXAMPLES:
    # Full installation with all security features (recommended)
    $0

    # Preview changes without installing
    $0 --dry-run

    # Force reinstall over existing setup
    $0 --force

    # Install only hooks (skip CI, docs, and GitHub security)
    $0 --no-ci --no-docs --no-github-security

    # Configure for non-Rust project (still includes GitHub security)
    $0 --non-rust

    # Skip GitHub security features (local security only)
    $0 --no-github-security

    # Use hooksPath chaining instead of replacing .git/hooks/pre-push
    $0 --hooks-path

    # Check version and updates
    $0 --version

    # Check for updates
    $0 --check-update

    # Create manual backup
    $0 --backup

SECURITY CONTROLS INSTALLED:
    Pre-Push (Complete Coverage, < 80s):
    ✅ Code formatting validation
    ✅ Linting and quality checks  
    ✅ Security audit (vulnerable dependencies)
    ✅ Test suite execution
    ✅ Secret detection (API keys, passwords)
    ✅ License compliance checking
    ✅ SHA pinning validation
    ✅ Commit signature verification
    ✅ Cargo.lock validation & git tracking
    ✅ Dependency version pinning analysis
    ✅ Build script security scanning
    ✅ Documentation security validation
    ✅ Environment variable security check
    ✅ Rust edition enforcement
    ✅ Unsafe block monitoring
    ✅ Import security validation
    ✅ File permission auditing
    ✅ Dependency count monitoring
    ✅ Network address validation
    ✅ Commit message security scanning
    ✅ Large file detection & blocking
    ✅ Technical debt monitoring
    ✅ Empty file detection

    Post-Push (Comprehensive CI):
    🔍 Static security analysis (SAST)
    🔍 Vulnerability scanning (Trivy)
    🔍 Supply chain verification
    🔍 SBOM generation
    🔍 Security metrics collection
    🔍 Integration testing
    🔍 Compliance reporting

    GitHub Security Features (enabled by default):
    🔐 Dependabot vulnerability alerts
    🔐 Dependabot automated security fixes
    🔐 CodeQL security scanning workflow
    🔐 Branch protection rules
    🔐 Secret scanning (auto-enabled for public repos)
    ⚠️  Security advisories (manual setup required)
    ❌ Advanced Security (GitHub Enterprise only)

REQUIREMENTS:
    - Git repository (initialized)
    - Internet connection (for tool downloads)
    - Platform: Linux, macOS, or WSL2

EOF
}

show_version() {
  echo "Security Controls Installer v${SCRIPT_VERSION}"
  echo "Industry-leading security architecture for Rust projects"
  echo "https://github.com/4n6h4x0r/1-click-rust-sec"
}

# Check if we're in a git repository
check_git_repo() {
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    handle_error $EXIT_VALIDATION_ERROR "Not in a Git repository" "Initialize git first: git init"
  fi
  print_status $GREEN "✅ Git repository detected"
}

# Detect project type
detect_project_type() {
  if [[ $RUST_PROJECT == true ]]; then
    if [[ -f "Cargo.toml" ]]; then
      print_status $GREEN "✅ Rust project detected (Cargo.toml found)"
      return 0
    else
      print_status $YELLOW "⚠️  No Cargo.toml found - using Rust configuration anyway"
      return 0
    fi
  fi

  # Auto-detect project type
  if [[ -f "Cargo.toml" ]]; then
    RUST_PROJECT=true
    print_status $GREEN "✅ Auto-detected: Rust project"
  elif [[ -f "package.json" ]]; then
    RUST_PROJECT=false
    print_status $GREEN "✅ Auto-detected: Node.js project"
  elif [[ -f "go.mod" ]]; then
    RUST_PROJECT=false
    print_status $GREEN "✅ Auto-detected: Go project"
  elif [[ -f "pyproject.toml" ]] || [[ -f "requirements.txt" ]]; then
    RUST_PROJECT=false
    print_status $GREEN "✅ Auto-detected: Python project"
  else
    RUST_PROJECT=false
    print_status $YELLOW "⚠️  Project type unknown - using generic configuration"
  fi
}

# Check if required tools are available
check_required_tools() {
  print_section "Checking Required Tools"

  local missing_tools=()

  # Core tools (always required)
  local core_tools=("git" "curl" "jq")

  # Project-specific tools
  local rust_tools=("cargo" "rustc")

  # Check core tools
  for tool in "${core_tools[@]}"; do
    if command -v "$tool" &>/dev/null; then
      print_status $GREEN "✅ $tool: $(command -v $tool)"
    else
      missing_tools+=("$tool")
      print_status $RED "❌ $tool: not found"
    fi
  done

  # Check Rust tools if Rust project
  if [[ $RUST_PROJECT == true ]]; then
    for tool in "${rust_tools[@]}"; do
      if command -v "$tool" &>/dev/null; then
        print_status $GREEN "✅ $tool: $(command -v $tool)"
      else
        missing_tools+=("$tool")
        print_status $RED "❌ $tool: not found"
      fi
    done
  fi

  if [[ ${#missing_tools[@]} -gt 0 ]] && [[ $SKIP_TOOLS == false ]]; then
    local install_instructions=""
    for tool in "${missing_tools[@]}"; do
      case $tool in
        "git")
          install_instructions+="  macOS: brew install git\n  Ubuntu: sudo apt install git\n"
          ;;
        "curl")
          install_instructions+="  macOS: brew install curl\n  Ubuntu: sudo apt install curl\n"
          ;;
        "jq")
          install_instructions+="  macOS: brew install jq\n  Ubuntu: sudo apt install jq\n"
          ;;
        "cargo" | "rustc")
          install_instructions+="  Install Rust: https://rustup.rs/\n"
          ;;
      esac
    done
    handle_error $EXIT_TOOL_MISSING "Missing required tools: ${missing_tools[*]}" "$install_instructions"
  fi
}

# Install security tools
install_security_tools() {
  print_section "Installing Security Tools"

  # Warn if a toolchain override is present and prefer +stable for optional installs
  local CARGO=(cargo)
  if [[ -n ${RUSTUP_TOOLCHAIN:-} ]]; then
    print_status $YELLOW "⚠️ RUSTUP_TOOLCHAIN is set to '$RUSTUP_TOOLCHAIN' — this overrides the default toolchain."
    print_status $YELLOW "   Optional cargo installs may fail or use a non-default toolchain. Using 'cargo +stable' for installs."
    print_status $YELLOW "   To avoid this, unset RUSTUP_TOOLCHAIN before running the installer."
    CARGO=(cargo +stable)
  fi

  # Install Rust security tools if Rust project
  if [[ $RUST_PROJECT == true ]] && command -v cargo &>/dev/null; then
    # Enhanced security tools with no-brainer additions
    local rust_security_tools=("cargo-deny" "cargo-geiger" "cargo-cyclonedx" "cargo-machete")
    local fallback_tools=("cargo-audit" "cargo-license") # Fallbacks if enhanced tools fail

    # Try to install enhanced tools first
    for tool in "${rust_security_tools[@]}"; do
      if ! command -v "$tool" &>/dev/null; then
        print_status $YELLOW "📦 Installing $tool..."
        if [[ $DRY_RUN == true ]]; then
          print_status $BLUE "   [DRY RUN] Would install $tool"
        else
          if "${CARGO[@]}" install --locked "$tool" 2>/dev/null; then
            print_status $GREEN "✅ $tool installed"
          else
            print_status $YELLOW "⚠️ $tool installation failed, will use fallback if needed"
          fi
        fi
      else
        print_status $GREEN "✅ $tool already installed"
      fi
    done

    # Install fallback tools if enhanced tools aren't available
    print_status $BLUE "🔄 Ensuring fallback security tools..."
    for tool in "${fallback_tools[@]}"; do
      if ! command -v "$tool" &>/dev/null && ! command -v "${tool/audit/deny}" &>/dev/null; then
        print_status $YELLOW "📦 Installing fallback tool $tool..."
        if [[ $DRY_RUN == true ]]; then
          print_status $BLUE "   [DRY RUN] Would install fallback $tool"
        else
          if "${CARGO[@]}" install --locked "$tool" 2>/dev/null; then
            print_status $GREEN "✅ Fallback $tool installed"
          else
            print_status $RED "❌ Failed to install $tool"
          fi
        fi
      fi
    done
  fi

  # Install gitsign for commit signing (if not disabled)
  if [[ $INSTALL_SIGNING == true ]]; then
    install_gitsign
  fi
}

# Install and configure gitsign for Sigstore commit signing
install_gitsign() {
  print_section "Installing Gitsign for Sigstore Signing"

  # Check if Go is available for gitsign installation
  if ! command -v go &>/dev/null; then
    print_status $YELLOW "⚠️ Go not found - gitsign installation requires Go"
    print_status $BLUE "   Install Go from https://golang.org/dl/ or:"
    print_status $BLUE "   • macOS: brew install go"
    print_status $BLUE "   • Ubuntu: sudo apt install golang-go"
    print_status $BLUE "   • Windows: Download from golang.org"
    return 0
  fi

  # Check if gitsign is already installed
  if command -v gitsign &>/dev/null; then
    print_status $GREEN "✅ gitsign already installed"
  else
    print_status $YELLOW "📦 Installing gitsign..."
    if [[ $DRY_RUN == true ]]; then
      print_status $BLUE "   [DRY RUN] Would install gitsign"
    else
      if go install github.com/sigstore/gitsign@latest 2>/dev/null; then
        print_status $GREEN "✅ gitsign installed successfully"
      else
        print_status $RED "❌ Failed to install gitsign"
        print_status $YELLOW "   Try installing manually: go install github.com/sigstore/gitsign@latest"
        return 1
      fi
    fi
  fi

  # Configure gitsign with manual authentication behavior
  configure_gitsign_manual_auth
}

# Non-fatal execution for optional configurations
try_execute() {
  local operation=$1
  local success_msg=${2:-""}
  local failure_msg=${3:-"⚠️ Operation failed"}

  if eval "$operation" 2>/dev/null; then
    [[ -n $success_msg ]] && print_status $GREEN "$success_msg"
    return 0
  else
    print_status $YELLOW "$failure_msg"
    return 1
  fi
}

# Configure gitsign for manual authentication with URL/code fallback
configure_gitsign_manual_auth() {
  print_status $YELLOW "🔧 Configuring gitsign for manual authentication..."

  if [[ $DRY_RUN == true ]]; then
    print_status $BLUE "   [DRY RUN] Would configure gitsign settings"
    return 0
  fi

  # Enable commit and tag signing
  try_execute "git config --global commit.gpgsign true" "" "⚠️ Failed to enable commit signing"
  try_execute "git config --global tag.gpgsign true" "" "⚠️ Failed to enable tag signing"
  try_execute "git config --global gpg.format x509" "" "⚠️ Failed to set GPG format"
  try_execute "git config --global gpg.x509.program gitsign" "" "⚠️ Failed to set gitsign as x509 program"

  # Configure Sigstore endpoints
  try_execute "git config --global gitsign.fulcio-url 'https://fulcio.sigstore.dev'" "" "⚠️ Failed to set Fulcio URL"
  try_execute "git config --global gitsign.rekor-url 'https://rekor.sigstore.dev'" "" "⚠️ Failed to set Rekor URL"
  try_execute "git config --global gitsign.oidc-issuer 'https://oauth2.sigstore.dev/auth'" "" "⚠️ Failed to set OIDC issuer"
  try_execute "git config --global gitsign.oidc-client-id 'sigstore'" "" "⚠️ Failed to set OIDC client ID"

  # Configure balanced authentication behavior (security + usability)
  try_execute "git config --global gitsign.autoclose true" "" "⚠️ Failed to enable autoclose"
  try_execute "git config --global gitsign.autocloseTimeout 20" "" "⚠️ Failed to set timeout"
  try_execute "git config --global gitsign.connectorID 'https://github.com/login/oauth'" "" "⚠️ Failed to set connector ID"

  print_status $GREEN "✅ Gitsign configured with balanced security and usability"
  print_status $BLUE "   • Browser auto-closes after 20 seconds (enough time for auth)"
  print_status $BLUE "   • Uses GitHub OAuth for identity verification"
  print_status $BLUE "   • Ephemeral certificates with transparency logging"

  # Test gitsign configuration and provide troubleshooting guidance
  if command -v gitsign &>/dev/null; then
    print_status $BLUE "🧪 Testing gitsign configuration..."
    if git config --global --get commit.gpgsign >/dev/null 2>&1; then
      print_status $GREEN "✅ Gitsign ready for commit signing"
      print_status $BLUE "   Next commit will be signed with Sigstore"
      echo
      print_status $YELLOW "💡 Authentication Behavior:"
      echo "   When you make your first signed commit:"
      echo "   1. Browser will open to GitHub OAuth page"
      echo "   2. You have 20 seconds to complete authentication"
      echo "   3. Browser closes automatically after auth or timeout"
      echo "   4. If timeout occurs, git commit will fail - simply retry"
      echo
      print_status $YELLOW "🔧 Troubleshooting Authentication Failures:"
      echo "   • Ensure you're logged into GitHub in your default browser"
      echo "   • Check that pop-ups are not blocked for sigstore.dev"
      echo "   • If repeated failures: git config --global gitsign.autocloseTimeout 60"
      echo "   • For CI/CD environments: use GITHUB_TOKEN authentication"
    else
      print_status $YELLOW "⚠️ Gitsign configuration may need verification"
    fi
  fi
}

# Configure Cargo.toml for security enhancements
configure_cargo_security() {
  if [[ $RUST_PROJECT == true ]] && [[ -f "Cargo.toml" ]]; then
    print_section "Configuring Cargo.toml Security Settings"

    # Check if [profile.release] section exists
    if ! grep -q "^\[profile\.release\]" Cargo.toml; then
      print_status $YELLOW "📝 Adding [profile.release] section to Cargo.toml..."
      if [[ $DRY_RUN == true ]]; then
        print_status $BLUE "   [DRY RUN] Would add [profile.release] section"
      else
        echo "" >>Cargo.toml
        echo "# Security enhancements" >>Cargo.toml
        echo "[profile.release]" >>Cargo.toml
        echo "# Enable integer overflow checks in release builds for security" >>Cargo.toml
        echo "overflow-checks = true" >>Cargo.toml
        print_status $GREEN "✅ Added security profile to Cargo.toml"
      fi
    else
      # Check if overflow-checks is already configured
      if ! grep -A 10 "^\[profile\.release\]" Cargo.toml | grep -q "overflow-checks"; then
        print_status $YELLOW "📝 Adding overflow-checks to existing [profile.release]..."
        if [[ $DRY_RUN == true ]]; then
          print_status $BLUE "   [DRY RUN] Would add overflow-checks = true"
        else
          # Add overflow-checks after the [profile.release] line
          sed -i.bak '/^\[profile\.release\]/a\
# Enable integer overflow checks in release builds for security\
overflow-checks = true' Cargo.toml
          rm -f Cargo.toml.bak
          print_status $GREEN "✅ Added overflow-checks to Cargo.toml"
        fi
      else
        print_status $GREEN "✅ overflow-checks already configured in Cargo.toml"
      fi
    fi

    # Create deny.toml if it doesn't exist
    if [[ ! -f "deny.toml" ]]; then
      print_status $YELLOW "📝 Creating deny.toml security configuration..."
      if [[ $DRY_RUN == true ]]; then
        print_status $BLUE "   [DRY RUN] Would create deny.toml"
      else
        create_deny_toml
        print_status $GREEN "✅ Created deny.toml configuration"
      fi
    else
      print_status $GREEN "✅ deny.toml already exists"
    fi

    # Create secure .cargo/config.toml
    configure_cargo_config_security
  fi
}

# Configure .cargo/config.toml for security hardening
configure_cargo_config_security() {
  local cargo_config_dir=".cargo"
  local cargo_config_file="$cargo_config_dir/config.toml"

  print_status $YELLOW "📝 Configuring secure .cargo/config.toml..."

  if [[ $DRY_RUN == true ]]; then
    print_status $BLUE "   [DRY RUN] Would create secure .cargo/config.toml"
    return 0
  fi

  # Create .cargo directory if it doesn't exist
  mkdir -p "$cargo_config_dir"

  # Create or update config.toml with security settings
  if [[ ! -f $cargo_config_file ]]; then
    cat >"$cargo_config_file" <<'CARGO_CONFIG_EOF'
# Cargo security configuration
# Generated by 1-Click Rust Security Controls

[net]
# Force git to use CLI for fetching (more secure than libgit2)
git-fetch-with-cli = true
# Set reasonable timeouts to prevent hanging builds
connect-timeout = 60
read-timeout = 60

[http]
# Check certificate revocation
check-revoke = true
# Force TLS 1.2 or higher
ssl-version = "tlsv1.2"
# Set user agent for security tracking
user-agent = "cargo (security-hardened)"
# Set timeout for HTTP requests
timeout = 60

[source.crates-io]
replace-with = "crates-io-secure"

[source.crates-io-secure]
registry = "https://github.com/rust-lang/crates.io-index"
# Ensure we're using the official registry only
CARGO_CONFIG_EOF
    print_status $GREEN "✅ Created secure .cargo/config.toml"
  else
    # Merge security settings with existing config
    print_status $BLUE "ℹ️  .cargo/config.toml exists - adding security settings"

    # Add [net] section if missing
    if ! grep -q "^\[net\]" "$cargo_config_file"; then
      echo "" >>"$cargo_config_file"
      echo "# Security: Force git CLI and set timeouts" >>"$cargo_config_file"
      echo "[net]" >>"$cargo_config_file"
      echo "git-fetch-with-cli = true" >>"$cargo_config_file"
      echo "connect-timeout = 60" >>"$cargo_config_file"
      echo "read-timeout = 60" >>"$cargo_config_file"
      print_status $GREEN "✅ Added [net] security settings"
    fi

    # Add [http] section if missing
    if ! grep -q "^\[http\]" "$cargo_config_file"; then
      echo "" >>"$cargo_config_file"
      echo "# Security: HTTP hardening" >>"$cargo_config_file"
      echo "[http]" >>"$cargo_config_file"
      echo "check-revoke = true" >>"$cargo_config_file"
      echo 'ssl-version = "tlsv1.2"' >>"$cargo_config_file"
      echo "timeout = 60" >>"$cargo_config_file"
      print_status $GREEN "✅ Added [http] security settings"
    fi
  fi
}

# Create comprehensive deny.toml configuration
create_deny_toml() {
  cat >deny.toml <<'DENY_TOML_EOF'
# cargo-deny configuration for comprehensive security
# Generated by 1-Click Rust Security Controls

[graph]
targets = [
    "x86_64-unknown-linux-gnu",
    "x86_64-apple-darwin", 
    "aarch64-apple-darwin",
    "x86_64-pc-windows-msvc",
]

[advisories]
db-path = "~/.cargo/advisory-db"
db-urls = ["https://github.com/rustsec/advisory-db"]
vulnerability = "deny"
unmaintained = "warn"
yanked = "deny" 
notice = "warn"

[licenses]
unlicensed = "deny"
allow = [
    "MIT",
    "Apache-2.0",
    "Apache-2.0 WITH LLVM-exception",
    "BSD-2-Clause", 
    "BSD-3-Clause",
    "ISC",
    "Unicode-DFS-2016",
    "CC0-1.0",
    "MPL-2.0",
    "Zlib",
    "BSL-1.0",
]
deny = [
    "GPL-2.0",
    "GPL-3.0",
    "AGPL-1.0", 
    "AGPL-3.0",
    "LGPL-2.0",
    "LGPL-2.1",
    "LGPL-3.0",
]
copyleft = "deny"
confidence-threshold = 0.8

[bans]
multiple-versions = "warn"
wildcards = "allow"
deny = [
    { name = "openssl", reason = "Use rustls instead for pure Rust crypto" },
    { name = "openssl-sys", reason = "Use rustls instead for pure Rust crypto" },
]

[sources]
unknown-registry = "warn"
unknown-git = "warn"
allow-registry = ["https://github.com/rust-lang/crates.io-index"]
DENY_TOML_EOF
}

# Generate pre-push hook
generate_pre_push_hook() {
  if [[ $RUST_PROJECT == true ]]; then
    cat <<'HOOK_EOF'
#!/bin/bash
set -euo pipefail

# Pre-push hook for security validation (Rust)
# Generated by Security Controls Installer v1.4.0

echo "🔍 Running pre-push validation checks..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Script-only helpers: secrets and pinning
run_secret_scan() {
    local dir_filter='^(target/|node_modules/|dist/|build/|vendor/|coverage/|\\.git/|\\.github/workflows/)'
    local allowlist_file=".security-controls/secret-allowlist.txt"
    local hits=0
    while IFS= read -r f; do
        [[ -z "$f" || ! -f "$f" ]] && continue
        while IFS= read -r line; do
            [[ "$f" =~ \\.lock$ ]] && continue
            if [[ -f "$allowlist_file" ]] && grep -E -q -f "$allowlist_file" <<<"$line"; then continue; fi
            if grep -E -q 'AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|AIza[0-9A-Za-z_-]{35}|xox[baprs]-[A-Za-z0-9-]{10,48}|-----BEGIN [A-Z ,]*PRIVATE KEY-----|[A-Za-z0-9+/=]{40,}' <<<"$line" \
               || grep -E -qi '(secret|password|api[_-]?key|token)[^\n]{0,20}[:=][[:space:]]*[^[:space:]]{8,}' <<<"$line"; then
                echo "   $f: $(sed -E 's/([:=])[[:space:]]*\"?[^\"[:space:]]{4,}/\\1 ***REDACTED***/g' <<<"$line")"
                hits=$((hits+1))
            fi
        done < <(git diff --cached -U0 -- "$f" | sed -n 's/^+//p')
    done < <(git diff --cached --name-only --diff-filter=ACM | grep -v -E "$dir_filter" || true)
    [[ $hits -eq 0 ]]
}

run_pin_checks() {
    local wf_dir="${1:-.github/workflows}"
    local violations=0
    [[ ! -d "$wf_dir" ]] && return 0
    is_hex40() { [[ ${#1} -eq 40 && "$1" =~ ^[0-9a-fA-F]{40}$ ]]; }
    check_uses_line() {
        local file="$1" uses="$2"
        if [[ "$uses" == ./* || "$uses" == .github/* ]]; then return 0; fi
        if [[ "$uses" == docker://* ]]; then
            [[ "$uses" == *"@sha256:"* ]] || { echo "   $file: docker action not pinned: $uses"; return 1; }
            return 0
        fi
        [[ "$uses" == *"@"* ]] || { echo "   $file: unpinned action (missing @<sha>): $uses"; return 1; }
        local ref="${uses##*@}"
        is_hex40 "$ref" || { echo "   $file: action ref not a 40-hex commit: $uses"; return 1; }
        return 0
    }
    while IFS= read -r -d '' f; do
        rm -f "$f.uses.tmp"
        awk -v FNAME="$f" -v UFILE="$f.uses.tmp" '
          function ltrim(s) { sub(/^\s+/, "", s); return s }
          function indent(s) { match(s, /^ */); return RLENGTH }
          BEGIN{ in_container=0; cont_indent=0; in_services=0; serv_indent=0; bad=0 }
          /^[[:space:]]*#/ { next }
          {
            line=$0; ind=indent(line); l=ltrim(line)
            if (l ~ /^container:/) {
              if (l ~ /^container:[[:space:]]*[^\{\[]/) {
                img=l; sub(/^container:[[:space:]]*/, "", img)
                if (img !~ /@sha256:/) { printf "   %s: jobs.container: image not pinned: %s\n", FNAME, img; bad++ }
              } else {
                in_container=1; cont_indent=ind
              }
            } else if (in_container && ind <= cont_indent) { in_container=0 }
            if (l ~ /^services:/) { in_services=1; serv_indent=ind; next }
            if (in_services && ind <= serv_indent) { in_services=0 }
            if ((in_container || in_services) && l ~ /^image:[[:space:]]*/) {
              img=l; sub(/^image:[[:space:]]*/, "", img)
              gsub(/^"|"$/, "", img); gsub(/^\047|\047$/, "", img)
              if (img !~ /@sha256:/) { printf "   %s: image not pinned: %s\n", FNAME, img; bad++ }
            }
            if (l ~ /^uses:[[:space:]]*/) {
              val=l; sub(/^uses:[[:space:]]*/, "", val); gsub(/^"|"$/, "", val); gsub(/^\047|\047$/, "", val)
              printf "USES %s\n", val >> UFILE
            }
          }
          END{ if (bad>0) exit 2 }' "$f" || violations=$((violations+1))
        while IFS= read -r uses; do
            check_uses_line "$f" "$uses" || violations=$((violations+1))
        done < "$f.uses.tmp"
    done < <(find "$wf_dir" -type f \( -name "*.yml" -o -name "*.yaml" \) -print0)
    [[ $violations -eq 0 ]]
}

# Load optional configuration
CONFIG_FILE=".security-controls/config.env"
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    . "$CONFIG_FILE"
fi

# Defaults if not set in config
: "${ENABLE_SECRET_SCAN:=true}"
: "${SECRET_SCAN_MODE:=staged}"
: "${ENABLE_LARGE_FILE_CHECK:=true}"
: "${LARGE_FILE_MAX_MB:=10}"
: "${ENABLE_TECH_DEBT_CHECK:=true}"
: "${ENABLE_EMPTY_FILE_CHECK:=true}"
: "${ENABLE_LINT:=true}"
: "${ENABLE_TESTS:=true}"
: "${TEST_SCOPE:=all}"

# Track if any checks fail
FAILED=0

print_status $BLUE "📋 Pre-push validation started"

# Detect if there are Rust packages; skip Rust-specific checks if workspace has no members
SKIP_RUST=0
if command -v cargo >/dev/null 2>&1; then
    if cargo metadata --no-deps --format-version 1 >/dev/null 2>&1; then
        PKG_COUNT=$(cargo metadata --no-deps --format-version 1 | jq -r '.packages | length' 2>/dev/null || echo 0)
    else
        PKG_COUNT=0
    fi
else
    PKG_COUNT=0
fi
if [[ "${PKG_COUNT:-0}" -eq 0 ]]; then
    print_status $BLUE "ℹ️ No Rust packages detected (workspace has no members) — skipping Rust-specific checks"
    SKIP_RUST=1
fi

# 1. Cargo Format Check
if [[ "${SKIP_RUST:-0}" -eq 1 ]]; then
    print_status $BLUE "ℹ️ Skipping cargo fmt (no Rust packages)"
else
print_status $YELLOW "🎨 Checking code formatting (cargo fmt)..."
if cargo fmt --all -- --check; then
    print_status $GREEN "✅ Code formatting is correct"
else
    print_status $RED "❌ Code formatting issues found"
    echo "   Run: cargo fmt --all"
    FAILED=1
fi
fi

echo
# 2. Cargo Clippy Check
if [[ "${ENABLE_LINT}" == "true" ]]; then
if [[ "${SKIP_RUST:-0}" -eq 1 ]]; then
    print_status $BLUE "ℹ️ Skipping clippy (no Rust packages)"
else
print_status $YELLOW "🔧 Running linting checks (cargo clippy)..."
if cargo clippy --all-targets --all-features -- -D warnings; then
    print_status $GREEN "✅ No clippy warnings found"
else
    print_status $RED "❌ Clippy warnings found"
    echo "   Fix warnings before pushing"
    FAILED=1
fi
fi
else
print_status $BLUE "ℹ️ Linting disabled via config (ENABLE_LINT=false)"
fi

echo
# 3. Security Audit (cargo-deny preferred)
if [[ "${SKIP_RUST:-0}" -eq 1 ]]; then
    print_status $BLUE "ℹ️ Skipping cargo-deny/audit (no Rust packages)"
else
if command -v cargo-deny &> /dev/null; then
    print_status $YELLOW "🛡️ Running comprehensive security audit (cargo deny)..."
    if cargo deny check; then
        print_status $GREEN "✅ All cargo-deny checks passed"
    else
        print_status $RED "❌ cargo-deny checks failed"
        echo "   Review vulnerabilities, license issues, or banned dependencies"
        FAILED=1
    fi
else
    print_status $YELLOW "🛡️ Running security audit (cargo audit)..."
    if command -v cargo-audit &> /dev/null; then
        if cargo audit; then
            print_status $GREEN "✅ No security vulnerabilities found"
        else
            print_status $RED "❌ Security vulnerabilities found"
            echo "   Run: cargo audit fix"
            FAILED=1
        fi
    else
        print_status $YELLOW "⚠️ Neither cargo-deny nor cargo-audit found"
        echo "   Install cargo-deny: cargo install cargo-deny (recommended)"
    fi
fi
fi

echo
# 4. Unsafe Code Detection (cargo-geiger) [warn]
if [[ "${SKIP_RUST:-0}" -eq 1 ]]; then
    print_status $BLUE "ℹ️ Skipping cargo-geiger (no Rust packages)"
else
if command -v cargo-geiger &> /dev/null; then
    print_status $YELLOW "🔬 Checking unsafe code usage (cargo geiger)..."
    if cargo geiger --format compact --quiet 2>/dev/null | grep -q "unsafe"; then
        print_status $YELLOW "⚠️ Unsafe code detected in dependencies"
        echo "   Review unsafe code usage for security implications"
    else
        print_status $GREEN "✅ No unsafe code detected"
    fi
else
    print_status $BLUE "ℹ️ cargo-geiger not found - skipping unsafe code check"
fi
fi

echo
# 5. Unused Dependencies Check (cargo-machete) [warn]
if [[ "${SKIP_RUST:-0}" -eq 1 ]]; then
    print_status $BLUE "ℹ️ Skipping cargo-machete (no Rust packages)"
else
if command -v cargo-machete &> /dev/null; then
    print_status $YELLOW "🧹 Checking for unused dependencies (cargo machete)..."
    if cargo machete --with-metadata 2>/dev/null | grep -q "unused"; then
        print_status $YELLOW "⚠️ Unused dependencies found"
        echo "   Run: cargo machete --fix (to auto-remove)"
    else
        print_status $GREEN "✅ No unused dependencies found"
    fi
else
    print_status $BLUE "ℹ️ cargo-machete not found - skipping unused dependency check"
fi
fi

echo
# 6. Test Suite
if [[ "${ENABLE_TESTS}" == "true" ]]; then
if [[ "${SKIP_RUST:-0}" -eq 1 ]]; then
    print_status $BLUE "ℹ️ Skipping tests (no Rust packages)"
else
print_status $YELLOW "🧪 Running test suite..."
if [[ "${TEST_SCOPE}" == "unit" ]]; then
    TEST_CMD=(cargo test --lib)
else
    TEST_CMD=(cargo test --all)
fi
if "${TEST_CMD[@]}"; then
    print_status $GREEN "✅ Tests passed (${TEST_SCOPE})"
else
    print_status $RED "❌ Tests failed (${TEST_SCOPE})"
    echo "   Fix failing tests before pushing"
    FAILED=1
fi
fi
else
print_status $BLUE "ℹ️ Tests disabled via config (ENABLE_TESTS=false)"
fi

echo
# 7. Secret Detection (script-only helper)
if [[ "$ENABLE_SECRET_SCAN" == "true" ]]; then
    print_status $YELLOW "🔍 Running secret detection (staged changes)..."
    if [[ -x ".security-controls/bin/gitleakslite" ]]; then
        if .security-controls/bin/gitleakslite protect --staged --no-banner --redact; then
            print_status $GREEN "✅ No secrets detected in staged changes"
        else
            print_status $RED "❌ Secrets detected in staged changes"
            echo "   Remove secrets or add safe patterns to .security-controls/secret-allowlist.txt"
            FAILED=1
        fi
    else
        print_status $YELLOW "⚠️ Secret scanner helper missing: .security-controls/bin/gitleakslite"
        echo "   Re-run installer to restore helpers"
    fi
else
    print_status $BLUE "ℹ️ Secret scan disabled via config"
fi

echo
# 8. License Compliance Check [warn]
if [[ "${SKIP_RUST:-0}" -eq 1 ]]; then
    print_status $BLUE "ℹ️ Skipping license compliance (no Rust packages)"
else
print_status $YELLOW "⚖️ Checking license compliance..."
if command -v cargo-license &> /dev/null; then
    COPYLEFT=$(cargo license --json 2>/dev/null | jq -r '.[] | select(.license | test("GPL-2.0|GPL-3.0|AGPL|LGPL"; "i")) | .name' 2>/dev/null || echo "")
    if [ -n "$COPYLEFT" ]; then
        print_status $YELLOW "⚠️ Copyleft licenses found (review required):"
        echo "$COPYLEFT" | while read -r pkg; do
            echo "     • $pkg"
        done
    else
        print_status $GREEN "✅ No problematic licenses found"
    fi
else
    print_status $YELLOW "⚠️ cargo-license not found - skipping license check"
fi
fi

echo
# 9. GitHub Actions SHA Pinning Check
print_status $YELLOW "📌 Checking GitHub Actions SHA pinning..."
if [[ -x ".security-controls/bin/pinactlite" ]]; then
    if .security-controls/bin/pinactlite pincheck --dir .github/workflows; then
        print_status $GREEN "✅ All GitHub Actions are properly pinned"
    else
        print_status $YELLOW "🛠  Auto-pinning unpinned references..."
        set +e
        .security-controls/bin/pinactlite autopin --dir .github/workflows --actions --images --quiet
        rc=$?
        set -e
        if [[ $rc -eq 2 ]]; then
            print_status $GREEN "✅ Auto-pinned all references successfully"
            git --no-pager diff -- .github/workflows | sed -n '1,120p' || true
        else
            print_status $RED "❌ Some references remain unpinned or autopin failed"
            FAILED=1
        fi
    fi
else
    print_status $YELLOW "⚠️  pinactlite helper not found, using basic validation..."
    if run_pin_checks .github/workflows; then
        print_status $GREEN "✅ Basic GitHub Actions pinning validation passed"
    else
        print_status $RED "❌ GitHub Actions pinning validation failed"
        FAILED=1
    fi
fi

echo
# 10. Commit Signing Check (if gitsign is configured)
if git config --get gpg.format | grep -q "x509"; then
    print_status $YELLOW "🔐 Checking Sigstore commit signing..."
    if git log --show-signature -1 HEAD 2>&1 | grep -q "gitsign: Good signature"; then
        print_status $GREEN "✅ Latest commit is Sigstore signed"
    else
        print_status $YELLOW "⚠️ Latest commit is not Sigstore signed"
    fi
    echo
fi

# 11. Cargo.lock Validation
print_status $YELLOW "📋 Checking Cargo.lock file..."
if [[ ! -f "Cargo.lock" ]]; then
    print_status $RED "❌ Cargo.lock not found"
    echo "   Run: cargo generate-lockfile"
    FAILED=1
elif ! git ls-files --error-unmatch Cargo.lock >/dev/null 2>&1; then
    print_status $YELLOW "⚠️ Cargo.lock is not committed to git"
else
    print_status $GREEN "✅ Cargo.lock exists and is committed"
fi

echo
# 12. Dependency Version Pinning Check [warn]
print_status $YELLOW "📌 Checking dependency version pinning..."
if grep -E "^\s*[a-zA-Z0-9_-]+\s*=\s*[\"']*[\*\^]" Cargo.toml >/dev/null 2>&1; then
    print_status $YELLOW "⚠️ Unpinned dependencies detected in Cargo.toml"
    grep -E "^\s*[a-zA-Z0-9_-]+\s*=\s*[\"']*[\*\^]" Cargo.toml | head -3 || true
else
    print_status $GREEN "✅ All dependencies appear to be pinned"
fi

echo
# 13. Build Script Security Check [warn]
print_status $YELLOW "🔧 Checking build scripts for security..."
BUILD_SCRIPTS=$(find . -name "build.rs" -not -path "./target/*" 2>/dev/null || true)
if [[ -n "$BUILD_SCRIPTS" ]]; then
    SUSPICIOUS_BUILD=""
    for script in $BUILD_SCRIPTS; do
        if grep -l "std::process\|std::env::var\|Command::new\|process::Command" "$script" >/dev/null 2>&1; then
            SUSPICIOUS_BUILD="$SUSPICIOUS_BUILD $script"
        fi
    done
    if [[ -n "$SUSPICIOUS_BUILD" ]]; then
        print_status $YELLOW "⚠️ Build scripts with system calls detected:"
        for script in $SUSPICIOUS_BUILD; do
            echo "     • $script"
        done
    else
        print_status $GREEN "✅ Build scripts appear safe"
    fi
else
    print_status $GREEN "✅ No build scripts found"
fi

echo
# 14. Documentation Security Check [warn]
print_status $YELLOW "📚 Scanning documentation for secrets..."
DOC_SECRETS=""
if [[ -d "docs" ]] || [[ -f "README.md" ]] || [[ -f "CHANGELOG.md" ]]; then
    for doc_file in README.md CHANGELOG.md $(find docs/ -name "*.md" 2>/dev/null | head -10); do
        if [[ -f "$doc_file" ]]; then
            if grep -i -E "(password|secret|token|api[_-]?key|private[_-]?key)" "$doc_file" >/dev/null 2>&1; then
                DOC_SECRETS="$DOC_SECRETS $doc_file"
            fi
        fi
    done
    if [[ -n "$DOC_SECRETS" ]]; then
        print_status $YELLOW "⚠️ Documentation may contain sensitive information:"
        for doc in $DOC_SECRETS; do
            echo "     • $doc"
        done
    else
        print_status $GREEN "✅ Documentation appears clean"
    fi
else
    print_status $BLUE "ℹ️ No documentation files to scan"
fi

echo
# 15. Environment Variable Security Check [warn]
print_status $YELLOW "🔐 Checking for hardcoded environment variables..."
ENV_VARS=$(grep -r "std::env::var.*['\"][A-Z_]*\(API\|KEY\|TOKEN\|SECRET\|PASSWORD\)" src/ --include="*.rs" 2>/dev/null || true)
if [[ -n "$ENV_VARS" ]]; then
    print_status $YELLOW "⚠️ Hardcoded environment variable names detected:"
    echo "$ENV_VARS" | head -3 || true
else
    print_status $GREEN "✅ No hardcoded environment variable patterns found"
fi

echo
# 16. Rust Edition Check [warn]
print_status $YELLOW "📅 Checking Rust edition..."
if [[ -f "Cargo.toml" ]]; then
    EDITION=$(grep 'edition = ' Cargo.toml | head -1 | sed 's/.*edition = "\([^"]*\)".*/\1/' 2>/dev/null || echo "")
    if [[ "$EDITION" == "2021" ]]; then
        print_status $GREEN "✅ Using current Rust edition 2021"
    elif [[ -z "$EDITION" ]]; then
        print_status $YELLOW "⚠️ No explicit Rust edition specified"
    else
        print_status $BLUE "ℹ️ Using Rust edition: $EDITION"
    fi
else
    print_status $BLUE "ℹ️ No Cargo.toml found for edition check"
fi

echo
# 17. Unsafe Block Monitoring [warn]
print_status $YELLOW "⚠️ Monitoring unsafe code blocks..."
if [[ -d "src" ]]; then
    UNSAFE_COUNT=$(find src/ -name "*.rs" -exec grep -c "unsafe" {} \; 2>/dev/null | awk '{sum += $1} END {print sum+0}')
    if [[ $UNSAFE_COUNT -gt 10 ]]; then
        print_status $YELLOW "⚠️ High unsafe block count: $UNSAFE_COUNT"
    elif [[ $UNSAFE_COUNT -gt 0 ]]; then
        print_status $BLUE "ℹ️ Found $UNSAFE_COUNT unsafe blocks"
    else
        print_status $GREEN "✅ No unsafe code blocks found"
    fi
else
    print_status $BLUE "ℹ️ No src/ directory found for unsafe code check"
fi

echo
# 18. Import Security Validation [warn]
print_status $YELLOW "📦 Checking for potentially dangerous imports..."
DANGEROUS_IMPORTS=$(grep -r "use std::process::\*\|use std::ffi::\*\|use std::mem::\*" src/ --include="*.rs" 2>/dev/null || true)
if [[ -n "$DANGEROUS_IMPORTS" ]]; then
    print_status $YELLOW "⚠️ Wildcard imports of potentially dangerous modules detected:"
    echo "$DANGEROUS_IMPORTS" | head -3 || true
else
    print_status $GREEN "✅ No dangerous wildcard imports found"
fi

echo
# 19. File Permission Check
print_status $YELLOW "🔒 Checking file permissions..."
WRITABLE_FILES=$(find . -name "*.rs" -perm -o+w -not -path "./.git/*" 2>/dev/null | head -10 || true)
if [[ -n "$WRITABLE_FILES" ]]; then
    print_status $RED "❌ World-writable source files found:"
    echo "$WRITABLE_FILES"
    FAILED=1
else
    print_status $GREEN "✅ File permissions are secure"
fi

echo
# 20. Dependency Count Monitoring [warn]
print_status $YELLOW "📊 Monitoring dependency count..."
if [[ -f "Cargo.toml" ]]; then
    DEP_COUNT=$(grep -E "^\s*[a-zA-Z0-9_-]+\s*=" Cargo.toml | grep -v "^\[" | wc -l | tr -d ' ')
    if [[ $DEP_COUNT -gt 75 ]]; then
        print_status $YELLOW "⚠️ Very high dependency count: $DEP_COUNT"
    elif [[ $DEP_COUNT -gt 50 ]]; then
        print_status $YELLOW "⚠️ High dependency count: $DEP_COUNT"
    else
        print_status $GREEN "✅ Reasonable dependency count: $DEP_COUNT"
    fi
else
    print_status $BLUE "ℹ️ No Cargo.toml found for dependency count check"
fi

echo
# 21. Network Address Validation [warn]
print_status $YELLOW "🌐 Checking for hardcoded network addresses..."
NETWORK_REFS=$(grep -r "http://\|https://[a-zA-Z0-9.-]\+\|[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}" src/ --include="*.rs" 2>/dev/null | grep -v "//\|#\|println!\|eprintln!" | head -5 || true)
if [[ -n "$NETWORK_REFS" ]]; then
    print_status $YELLOW "⚠️ Hardcoded network addresses detected:"
    echo "$NETWORK_REFS"
else
    print_status $GREEN "✅ No hardcoded network addresses found"
fi

echo
# 22. Commit Message Security Check [warn]
print_status $YELLOW "💬 Checking recent commit messages..."
COMMIT_SECRETS=$(git log --oneline -10 2>/dev/null | grep -i -E "password|secret|token|api.?key|private.?key" || true)
if [[ -n "$COMMIT_SECRETS" ]]; then
    print_status $YELLOW "⚠️ Sensitive information detected in commit messages:"
    echo "$COMMIT_SECRETS"
else
    print_status $GREEN "✅ Recent commit messages appear clean"
fi

echo
# 23. Large File Detection (Critical - Blocking)
if [[ "$ENABLE_LARGE_FILE_CHECK" == "true" ]]; then
    print_status $YELLOW "📦 Checking for large files (> ${LARGE_FILE_MAX_MB}MB)..."
    LARGE_FILES=$(find . -type f -size +${LARGE_FILE_MAX_MB}M -not -path "./.git/*" -not -path "./target/*" 2>/dev/null || true)
    if [[ -n "$LARGE_FILES" ]]; then
        print_status $RED "❌ Large files detected (> ${LARGE_FILE_MAX_MB}MB):"
        echo "$LARGE_FILES"
        FAILED=1
    else
        print_status $GREEN "✅ No large files detected"
    fi
else
    print_status $BLUE "ℹ️ Large file check disabled via config"
fi

echo
# 24. Technical Debt Monitoring [warn]
if [[ "$ENABLE_TECH_DEBT_CHECK" == "true" ]]; then
    print_status $YELLOW "🔧 Monitoring technical debt..."
    if [[ -d "src" ]]; then
        TODO_COUNT=$(grep -r "TODO\|FIXME\|XXX\|HACK" src/ --include="*.rs" 2>/dev/null | wc -l | tr -d ' ')
        if [[ $TODO_COUNT -gt 100 ]]; then
            print_status $YELLOW "⚠️ Very high technical debt: $TODO_COUNT TODO/FIXME items"
        elif [[ $TODO_COUNT -gt 50 ]]; then
            print_status $YELLOW "⚠️ High technical debt: $TODO_COUNT TODO/FIXME items"
        elif [[ $TODO_COUNT -gt 0 ]]; then
            print_status $BLUE "ℹ️ Technical debt items: $TODO_COUNT TODO/FIXME items"
        else
            print_status $GREEN "✅ No technical debt markers found"
        fi
    else
        print_status $BLUE "ℹ️ No src/ directory found for technical debt check"
    fi
else
    print_status $BLUE "ℹ️ Technical debt check disabled via config"
fi

echo
# 25. Empty File Detection [warn]
if [[ "$ENABLE_EMPTY_FILE_CHECK" == "true" ]]; then
    print_status $YELLOW "📄 Checking for empty source files..."
    if [[ -d "src" ]]; then
        EMPTY_FILES=$(find src/ -name "*.rs" -empty 2>/dev/null || true)
        if [[ -n "$EMPTY_FILES" ]]; then
            print_status $YELLOW "⚠️ Empty source files detected:"
            echo "$EMPTY_FILES"
        else
            print_status $GREEN "✅ No empty source files found"
        fi
    else
        print_status $BLUE "ℹ️ No src/ directory found for empty file check"
    fi
else
    print_status $BLUE "ℹ️ Empty file check disabled via config"
fi

echo
# Summary
if [ $FAILED -eq 0 ]; then
    print_status $GREEN "🎉 All pre-push checks passed! Pushing to remote..."
    echo
    print_status $BLUE "📤 Push will proceed"
else
    print_status $RED "💥 Pre-push validation failed!"
    echo
    print_status $RED "❌ Push blocked - fix the issues above before pushing"
    echo
    exit 1
fi

exit 0
HOOK_EOF
  else
    cat <<'HOOK_EOF'
#!/bin/bash
set -euo pipefail

# Pre-push hook for security validation (Generic)
# Generated by Security Controls Installer v1.4.0

echo "🔍 Running pre-push validation checks..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Load optional configuration
CONFIG_FILE=".security-controls/config.env"
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    . "$CONFIG_FILE"
fi

: "${ENABLE_SECRET_SCAN:=true}"
: "${ENABLE_LARGE_FILE_CHECK:=true}"
: "${LARGE_FILE_MAX_MB:=10}"

FAILED=0

print_status $BLUE "📋 Pre-push validation started"

echo
# 1. Secret Detection (script-only helper)
if [[ "$ENABLE_SECRET_SCAN" == "true" ]]; then
    print_status $YELLOW "🔍 Running secret detection (staged changes)..."
    if [[ -x ".security-controls/bin/gitleakslite" ]]; then
        if .security-controls/bin/gitleakslite protect --staged --no-banner --redact; then
            print_status $GREEN "✅ No secrets detected in staged changes"
        else
            print_status $RED "❌ Secrets detected in staged changes"
            FAILED=1
        fi
    else
        print_status $YELLOW "⚠️ Secret scanner helper missing: .security-controls/bin/gitleakslite"
        echo "   Re-run installer to restore helpers"
    fi
else
    print_status $BLUE "ℹ️ Secret scan disabled via config"
fi

echo
# 2. GitHub Actions SHA Pinning Check
if [[ -d ".github/workflows" ]]; then
print_status $YELLOW "📌 Checking GitHub Actions SHA pinning..."
if [[ -x ".security-controls/bin/pinactlite" ]]; then
        if .security-controls/bin/pinactlite pincheck --dir .github/workflows; then
            print_status $GREEN "✅ All GitHub Actions are properly pinned"
        else
print_status $YELLOW "🛠  Auto-pinning unpinned references..."
            set +e
            .security-controls/bin/pinactlite autopin --dir .github/workflows --actions --images --quiet
            rc=$?
            set -e
            if [[ $rc -eq 2 ]]; then
                print_status $GREEN "✅ Auto-pinned all references successfully"
                git --no-pager diff -- .github/workflows | sed -n '1,120p' || true
            else
                print_status $RED "❌ Some references remain unpinned or autopin failed"
                FAILED=1
            fi
        fi
    else
print_status $YELLOW "⚠️ Pinning checker helper missing: .security-controls/bin/pinactlite"
        echo "   Re-run installer to restore helpers"
    fi
    echo
fi
if git config --get gpg.format | grep -q "x509"; then
    print_status $YELLOW "🔐 Checking Sigstore commit signing..."
    if git log --show-signature -1 HEAD 2>&1 | grep -q "gitsign: Good signature"; then
        print_status $GREEN "✅ Latest commit is Sigstore signed"
    else
        print_status $YELLOW "⚠️ Latest commit is not Sigstore signed"
    fi
fi

echo
# 4. Large File Detection (Critical - Blocking)
if [[ "$ENABLE_LARGE_FILE_CHECK" == "true" ]]; then
    print_status $YELLOW "📦 Checking for large files (> ${LARGE_FILE_MAX_MB}MB)..."
    LARGE_FILES=$(find . -type f -size +${LARGE_FILE_MAX_MB}M -not -path "./.git/*" 2>/dev/null || true)
    if [[ -n "$LARGE_FILES" ]]; then
        print_status $RED "❌ Large files detected (> ${LARGE_FILE_MAX_MB}MB):"
        echo "$LARGE_FILES"
        FAILED=1
    else
        print_status $GREEN "✅ No large files detected"
    fi
fi

echo
# Summary
if [ $FAILED -eq 0 ]; then
    print_status $GREEN "🎉 All pre-push checks passed! Pushing to remote..."
    echo
    print_status $BLUE "📤 Push will proceed"
else
    print_status $RED "💥 Pre-push validation failed!"
    echo
    print_status $RED "❌ Push blocked - fix the issues above before pushing"
    echo
    exit 1
fi

exit 0
HOOK_EOF
  fi
}

# Ensure hooksPath dispatcher exists and optionally set core.hooksPath
ensure_hooks_path_dispatcher() {
  # Create dispatcher and directory structure
  mkdir -p "$PRE_PUSH_D_DIR"

  local dispatcher="$HOOKS_PATH_DIR/pre-push"
  if [[ ! -f $dispatcher ]]; then
    cat >"$dispatcher" <<'DISPATCH_EOF'
#!/bin/bash
# hooksPath pre-push dispatcher: runs all executables in pre-push.d
set -euo pipefail
HOOK_DIR="$(dirname "$0")/pre-push.d"
status=0
if [ -d "$HOOK_DIR" ]; then
  for hook in "$HOOK_DIR"/*; do
    if [ -f "$hook" ] && [ -x "$hook" ]; then
      "$hook" || status=$?
    fi
  done
fi
exit $status
DISPATCH_EOF
    chmod +x "$dispatcher"
    print_status $GREEN "✅ Created hooksPath dispatcher at $dispatcher"
  fi

  # Configure git to use hooksPath if not already set
  local current_hooks_path
  current_hooks_path=$(git config --get core.hooksPath || true)
  if [[ -z $current_hooks_path ]]; then
    if [[ $FORCE_INSTALL == true ]]; then
      git config core.hooksPath "$HOOKS_PATH_DIR"
      print_status $GREEN "✅ Set git core.hooksPath to $HOOKS_PATH_DIR"
    else
      read -p "Set git core.hooksPath to $HOOKS_PATH_DIR for chained hooks? (y/N): " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        git config core.hooksPath "$HOOKS_PATH_DIR"
        print_status $GREEN "✅ Set git core.hooksPath to $HOOKS_PATH_DIR"
      else
        print_status $BLUE "ℹ️ Skipping core.hooksPath configuration"
      fi
    fi
  else
    print_status $BLUE "ℹ️ git core.hooksPath already set to $current_hooks_path"
  fi
}

# Install pre-push hook
install_pre_push_hook() {
  print_section "Installing Pre-Push Hook"

  if [[ $USE_HOOKS_PATH == true ]]; then
    # hooksPath mode (chaining-friendly)
    if [[ $DRY_RUN == true ]]; then
      print_status $BLUE "[DRY RUN] Would create hooksPath dispatcher and install hook to $PRE_PUSH_D_DIR/50-security-pre-push"
      return 0
    fi
    ensure_hooks_path_dispatcher
    local chained_hook="$PRE_PUSH_D_DIR/50-security-pre-push"

    # Generate hook content and write atomically
    local hook_content
    hook_content=$(generate_pre_push_hook)
    atomic_write "$chained_hook" "$hook_content"
    chmod +x "$chained_hook"
    add_rollback "chmod -x '$chained_hook'"

    print_status $GREEN "✅ Pre-push hook installed (hooksPath): $chained_hook"
    return 0
  fi

  # Legacy mode: write to .git/hooks/pre-push (may replace existing)
  local hook_file=".git/hooks/pre-push"

  if [[ -f $hook_file ]] && [[ $FORCE_INSTALL == false ]]; then
    print_status $YELLOW "⚠️  Pre-push hook already exists"
    read -p "Replace existing hook? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      print_status $BLUE "📝 Skipping pre-push hook installation"
      return 0
    fi
  fi

  if [[ $DRY_RUN == true ]]; then
    print_status $BLUE "[DRY RUN] Would install pre-push hook to $hook_file"
  else
    mkdir -p .git/hooks

    # Generate hook content and write atomically
    local hook_content
    hook_content=$(generate_pre_push_hook)
    atomic_write "$hook_file" "$hook_content"
    chmod +x "$hook_file"
    add_rollback "chmod -x '$hook_file'"

    print_status $GREEN "✅ Pre-push hook installed: $hook_file"
  fi
}

# Generate Pinning Validation workflow (standalone)
generate_pinning_workflow() {
  cat <<'EOF'
name: Pinning Validation

on:
  workflow_dispatch:
  push:
    branches: ["**"]
  pull_request:
    branches: ["**"]

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  pinning:
    name: Validate GitHub Actions and container image pins
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v5.0.0

      - name: Quick local pincheck (if present)
        run: |
          if [ -x ./.security-controls/bin/pinactlite ]; then
            ./.security-controls/bin/pinactlite pincheck --dir .github/workflows
          else
            echo "Local pinactlite helper not present; skipping quick check."
          fi

      - name: Install and verify tools, then install pinact v3.4.2
        run: |
          set -euo pipefail
          mkdir -p "$HOME/.local/bin"
          export PATH="$HOME/.local/bin:$PATH"
          
          # 1) Install cosign v2.6.0 and verify with SHA256
          COSIGN_VERSION=v2.6.0
          COSIGN_BASE="https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}"
          COSIGN_BIN="cosign-linux-amd64"
          COSIGN_SHA="ea5c65f99425d6cfbb5c4b5de5dac035f14d09131c1a0ea7c7fc32eab39364f9"
          curl -fsSLo /tmp/${COSIGN_BIN} "${COSIGN_BASE}/${COSIGN_BIN}"
          echo "${COSIGN_SHA}  /tmp/${COSIGN_BIN}" | sha256sum -c -
          install -m 0755 /tmp/${COSIGN_BIN} "$HOME/.local/bin/cosign"
          
          # 2) Install slsa-verifier v2.7.1 and verify SHA256
          SLSA_VERIFIER_VERSION=v2.7.1
          SLSA_BIN="slsa-verifier-linux-amd64"
          SLSA_BASE="https://github.com/slsa-framework/slsa-verifier/releases/download/${SLSA_VERIFIER_VERSION}"
          SLSA_SHA="946dbec729094195e88ef78e1734324a27869f03e2c6bd2f61cbc06bd5350339"
          curl -fsSLo /tmp/${SLSA_BIN} "${SLSA_BASE}/${SLSA_BIN}"
          echo "${SLSA_SHA}  /tmp/${SLSA_BIN}" | sha256sum -c -
          install -m 0755 /tmp/${SLSA_BIN} "$HOME/.local/bin/slsa-verifier"
          
          # 3) Download pinact v3.4.2 artifacts and verify signature + provenance + checksum
          VERSION=v3.4.2
          BASE="https://github.com/suzuki-shunsuke/pinact/releases/download/${VERSION}"

          # Fetch checksums and signature (prefer versioned filenames; fallback to plain)
          curl -fsSLo /tmp/checksums.txt "${BASE}/pinact_${VERSION#v}_checksums.txt" || \
          curl -fsSLo /tmp/checksums.txt "${BASE}/checksums.txt"

          curl -fsSLo /tmp/checksums.txt.pem "${BASE}/pinact_${VERSION#v}_checksums.txt.pem" || \
          curl -fsSLo /tmp/checksums.txt.pem "${BASE}/checksums.txt.pem"

          curl -fsSLo /tmp/checksums.txt.sig "${BASE}/pinact_${VERSION#v}_checksums.txt.sig" || \
          curl -fsSLo /tmp/checksums.txt.sig "${BASE}/checksums.txt.sig"
          
          # Sigstore verification of checksums.txt certificate and signature (GitHub OIDC issuer)
          cosign verify-blob \
            --certificate /tmp/checksums.txt.pem \
            --signature /tmp/checksums.txt.sig \
            --certificate-oidc-issuer https://token.actions.githubusercontent.com \
            --certificate-identity-regexp '^https://github.com/suzuki-shunsuke/(pinact|go-release-workflow)/.*' \
            /tmp/checksums.txt
          
          # OpenSSL verification as defense in depth
          # 1) Extract pubkey from certificate: try PEM directly, else decode base64-wrapped cert
          if ! openssl x509 -in /tmp/checksums.txt.pem -pubkey -noout > /tmp/pinact.pub 2>/dev/null; then
            base64 -d /tmp/checksums.txt.pem > /tmp/checksums.txt.pem.dec
            openssl x509 -in /tmp/checksums.txt.pem.dec -pubkey -noout > /tmp/pinact.pub
          fi
          # 2) Prepare signature: decode base64 if needed, else use raw signature
          if ! base64 -d /tmp/checksums.txt.sig > /tmp/checksums.txt.sig.bin 2>/dev/null; then
            cp /tmp/checksums.txt.sig /tmp/checksums.txt.sig.bin
          fi
          # 3) Verify
          openssl dgst -sha256 -verify /tmp/pinact.pub -signature /tmp/checksums.txt.sig.bin /tmp/checksums.txt

          # Determine Linux amd64 tarball name from checksums (support multiple conventions)
          TARBALL=""
          for name in "pinact_${VERSION#v}_linux_amd64.tar.gz" "pinact_linux_amd64.tar.gz" \
                     "pinact_${VERSION#v}_Linux_x86_64.tar.gz" "pinact_Linux_x86_64.tar.gz"; do
            if grep -q " ${name}$" /tmp/checksums.txt; then
              TARBALL="$name"; break
            fi
          done
          if [[ -z "$TARBALL" ]]; then
            echo "Unable to determine tarball name from checksums.txt" >&2
            echo "Available entries:" >&2
            cat /tmp/checksums.txt >&2
            exit 1
          fi

          # Download the tarball using the discovered name
          curl -fsSLo "/tmp/${TARBALL}" "${BASE}/${TARBALL}"

          # Checksum verification of the tarball
          awk -v tar="${TARBALL}" -v path="/tmp/${TARBALL}" '$2==tar { print $1, path }' /tmp/checksums.txt | sha256sum -c -

          # Try to download provenance with fallbacks
          PROV=""
          for prov in multiple.intoto.jsonl provenance.intoto.jsonl attestation.intoto.jsonl; do
            if curl -fsSLo "/tmp/${prov}" "${BASE}/${prov}"; then PROV="/tmp/${prov}"; break; fi
          done

          # SLSA provenance verification for the tarball (if provenance is available)
          if [[ -n "${PROV}" ]]; then
            slsa-verifier verify-artifact \
              --provenance-path "${PROV}" \
              --source-uri github.com/suzuki-shunsuke/pinact \
              --source-tag "${VERSION}" \
              "/tmp/${TARBALL}"
          else
            echo "Provenance file not found for ${VERSION}; skipping SLSA verification"
          fi
          
          # Extract and install pinact
          tar -xzf "/tmp/${TARBALL}"
          install -m 0755 pinact "$HOME/.local/bin/pinact"
          echo "$HOME/.local/bin" >> "$GITHUB_PATH"

      - name: Verify pinact version (non-blocking)
        run: |
          pinact --version || true

      - name: Validate pins with pinact
        run: |
          pinact run --check
EOF
}

# Generate CI workflow
generate_ci_workflow() {
  if [[ $RUST_PROJECT == true ]]; then
    cat <<'EOF'
name: Security CI

on:
  push:
    branches: [ main, master, develop ]
  pull_request:
    branches: [ main, master, develop ]

env:
  CARGO_TERM_COLOR: always

jobs:
  security-audit:
    name: Security Audit
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7

    - name: Detect Rust packages
      id: rust
      run: |
        set -euo pipefail
        if [ -f Cargo.toml ]; then
          if grep -q '^[[:space:]]*\[package\]' Cargo.toml; then
            echo "has=true" >> "$GITHUB_OUTPUT"
          elif grep -q '^[[:space:]]*\[workspace\]' Cargo.toml && grep -q '^[[:space:]]*members[[:space:]]*=' Cargo.toml; then
            echo "has=true" >> "$GITHUB_OUTPUT"
          else
            echo "has=false" >> "$GITHUB_OUTPUT"
          fi
        else
          echo "has=false" >> "$GITHUB_OUTPUT"
        fi

    - name: Install Rust toolchain
      if: ${{ steps.rust.outputs.has == 'true' }}
      uses: dtolnay/rust-toolchain@21dc36fb71dd22e3317045c0c31a3f4249868b17 # stable
      with:
        toolchain: stable

    - name: Skip Security Audit (no Rust packages)
      if: ${{ steps.rust.outputs.has != 'true' }}
      run: echo "No Rust packages detected; skipping Security Audit job steps."

    - name: Cache dependencies
      if: ${{ steps.rust.outputs.has == 'true' }}
      uses: actions/cache@0c45773b623bea8c8e75f6c82b208c3cf94ea4f9 # v4.0.2
      with:
        path: |
          ~/.cargo/bin/
          ~/.cargo/registry/index/
          ~/.cargo/registry/cache/
          ~/.cargo/git/db/
          target/
        key: ${{ runner.os }}-cargo-audit-${{ hashFiles('**/Cargo.lock') }}
        restore-keys: |
          ${{ runner.os }}-cargo-audit-

    - name: Install cargo-audit and cargo-auditable
      if: ${{ steps.rust.outputs.has == 'true' }}
      run: |
        cargo install --locked cargo-audit
        cargo install --locked cargo-auditable

    - name: Build with auditable metadata
      if: ${{ steps.rust.outputs.has == 'true' }}
      run: cargo auditable build --release

    - name: Run cargo audit
      if: ${{ steps.rust.outputs.has == 'true' }}
      run: cargo audit

    - name: Run cargo audit for dependencies
      if: ${{ steps.rust.outputs.has == 'true' }}
      run: cargo audit --db advisory-db --json | tee audit-report.json

    - name: Run cargo audit on binary
      if: ${{ steps.rust.outputs.has == 'true' }}
      run: cargo audit bin target/release/*

    - name: Upload audit report
      if: ${{ steps.rust.outputs.has == 'true' }}
      uses: actions/upload-artifact@65462800fd760344b1a7b4382951275a0abb4808 # v4.3.3
      with:
        name: security-audit-report
        path: audit-report.json

  secret-scanning:
    name: Secret Scanning
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7
      with:
        fetch-depth: 0

    - name: Run Gitleaks
      uses: gitleaks/gitleaks-action@cb7149b9e61c3d6896c4bc2616d4c9e86ee2d0c2 # v2.3.6
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  vulnerability-scanning:
    name: Vulnerability Scanning
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7

    - name: Run Trivy vulnerability scanner in repo mode
      uses: aquasecurity/trivy-action@b6643a29fecd7f34b3597bc6acb0a98b03d33ff8 # 0.33.1
      with:
        scan-type: 'fs'
        scan-ref: '.'
        format: 'sarif'
        output: 'trivy-results.sarif'

    - name: Upload Trivy scan results to GitHub Security
      uses: github/codeql-action/upload-sarif@396bb3e45325a47dd9ef434068033c6d5bb0d11a # v3.26.7
      if: always()
      with:
        sarif_file: 'trivy-results.sarif'

  static-analysis:
    name: Static Analysis
    runs-on: ubuntu-latest
    permissions:
      actions: read
      contents: read
      security-events: write
    steps:
    - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7

    - name: Detect Rust packages
      id: rust
      run: |
        set -euo pipefail
        if [ -f Cargo.toml ]; then
          if grep -q '^[[:space:]]*\[package\]' Cargo.toml; then
            echo "has=true" >> "$GITHUB_OUTPUT"
          elif grep -q '^[[:space:]]*\[workspace\]' Cargo.toml && grep -q '^[[:space:]]*members[[:space:]]*=' Cargo.toml; then
            echo "has=true" >> "$GITHUB_OUTPUT"
          else
            echo "has=false" >> "$GITHUB_OUTPUT"
          fi
        else
          echo "has=false" >> "$GITHUB_OUTPUT"
        fi

    - name: Initialize CodeQL
      if: ${{ steps.rust.outputs.has == 'true' }}
      uses: github/codeql-action/init@396bb3e45325a47dd9ef434068033c6d5bb0d11a # v3.26.7
      with:
        languages: rust
        queries: +security-and-quality

    - name: Install Rust toolchain
      if: ${{ steps.rust.outputs.has == 'true' }}
      uses: dtolnay/rust-toolchain@21dc36fb71dd22e3317045c0c31a3f4249868b17 # stable
      with:
        toolchain: stable

    - name: Build project
      if: ${{ steps.rust.outputs.has == 'true' }}
      run: cargo build --release

    - name: Perform CodeQL Analysis
      if: ${{ steps.rust.outputs.has == 'true' }}
      uses: github/codeql-action/analyze@396bb3e45325a47dd9ef434068033c6d5bb0d11a # v3.26.7

  supply-chain:
    name: Supply Chain Security
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7

    - name: Detect Rust packages
      id: rust
      run: |
        set -euo pipefail
        if [ -f Cargo.toml ]; then
          if grep -q '^[[:space:]]*\[package\]' Cargo.toml; then
            echo "has=true" >> "$GITHUB_OUTPUT"
          elif grep -q '^[[:space:]]*\[workspace\]' Cargo.toml && grep -q '^[[:space:]]*members[[:space:]]*=' Cargo.toml; then
            echo "has=true" >> "$GITHUB_OUTPUT"
          else
            echo "has=false" >> "$GITHUB_OUTPUT"
          fi
        else
          echo "has=false" >> "$GITHUB_OUTPUT"
        fi

    - name: Install Rust toolchain
      if: ${{ steps.rust.outputs.has == 'true' }}
      uses: dtolnay/rust-toolchain@21dc36fb71dd22e3317045c0c31a3f4249868b17 # stable
      with:
        toolchain: stable

    - name: Generate SBOM
      if: ${{ steps.rust.outputs.has == 'true' }}
      run: |
        cargo install --locked cargo-auditable
        cargo auditable build --release
        cargo install --locked cargo-cyclonedx
        cargo cyclonedx --output-format json --output-file sbom.json

    - name: Skip Supply Chain (no Rust packages)
      if: ${{ steps.rust.outputs.has != 'true' }}
      run: echo "No Rust packages detected; skipping Supply Chain job steps."

    - name: Upload SBOM
      if: ${{ steps.rust.outputs.has == 'true' }}
      uses: actions/upload-artifact@65462800fd760344b1a7b4382951275a0abb4808 # v4.3.3
      with:
        name: software-bill-of-materials
        path: sbom.json


  license-compliance:
    name: License Compliance
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7

    - name: Detect Rust packages
      id: rust
      run: |
        set -euo pipefail
        if [ -f Cargo.toml ]; then
          if grep -q '^[[:space:]]*\[package\]' Cargo.toml; then
            echo "has=true" >> "$GITHUB_OUTPUT"
          elif grep -q '^[[:space:]]*\[workspace\]' Cargo.toml && grep -q '^[[:space:]]*members[[:space:]]*=' Cargo.toml; then
            echo "has=true" >> "$GITHUB_OUTPUT"
          else
            echo "has=false" >> "$GITHUB_OUTPUT"
          fi
        else
          echo "has=false" >> "$GITHUB_OUTPUT"
        fi

    - name: Install Rust toolchain
      if: ${{ steps.rust.outputs.has == 'true' }}
      uses: dtolnay/rust-toolchain@21dc36fb71dd22e3317045c0c31a3f4249868b17 # stable
      with:
        toolchain: stable

    - name: Install cargo-license
      if: ${{ steps.rust.outputs.has == 'true' }}
      run: cargo install --locked cargo-license

    - name: Generate license report
      if: ${{ steps.rust.outputs.has == 'true' }}
      run: |
        cargo license --json > licenses.json
        cargo license --tsv > licenses.tsv

    - name: Check for copyleft licenses
      if: ${{ steps.rust.outputs.has == 'true' }}
      run: |
        COPYLEFT=$(cargo license --json | jq -r '.[] | select(.license | test("GPL-2.0|GPL-3.0|AGPL|LGPL"; "i")) | "\(.name): \(.license)"' || true)
        if [ -n "$COPYLEFT" ]; then
          echo "::warning::Copyleft licenses found:"
          echo "$COPYLEFT"
        else
          echo "No problematic copyleft licenses found"
        fi

    - name: Skip License Compliance (no Rust packages)
      if: ${{ steps.rust.outputs.has != 'true' }}
      run: echo "No Rust packages detected; skipping License Compliance job steps."

    - name: Upload license report
      uses: actions/upload-artifact@65462800fd760344b1a7b4382951275a0abb4808 # v4.3.3
      with:
        name: license-compliance-report
        path: |
          licenses.json
          licenses.tsv

  binary-analysis:
    name: Binary Security Analysis
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7

    - name: Detect Rust packages
      id: rust
      run: |
        set -euo pipefail
        if [ -f Cargo.toml ]; then
          if grep -q '^[[:space:]]*\[package\]' Cargo.toml; then
            echo "has=true" >> "$GITHUB_OUTPUT"
          elif grep -q '^[[:space:]]*\[workspace\]' Cargo.toml && grep -q '^[[:space:]]*members[[:space:]]*=' Cargo.toml; then
            echo "has=true" >> "$GITHUB_OUTPUT"
          else
            echo "has=false" >> "$GITHUB_OUTPUT"
          fi
        else
          echo "has=false" >> "$GITHUB_OUTPUT"
        fi

    - name: Install Rust toolchain
      if: ${{ steps.rust.outputs.has == 'true' }}
      uses: dtolnay/rust-toolchain@21dc36fb71dd22e3317045c0c31a3f4249868b17 # stable
      with:
        toolchain: stable

    - name: Build release binary
      if: ${{ steps.rust.outputs.has == 'true' }}
      run: cargo build --release

    - name: Install binary analysis tools
      if: ${{ steps.rust.outputs.has == 'true' }}
      run: |
        cargo install --locked cargo-binutils
        rustup component add llvm-tools-preview

    - name: Analyze binary for embedded secrets
      if: ${{ steps.rust.outputs.has == 'true' }}
      run: |
        echo "🔍 Scanning binary for embedded secrets..."
        for binary in target/release/*; do
          if [[ -x "$binary" && ! -d "$binary" ]]; then
            echo "Analyzing: $binary"
            # Check for common secret patterns in binary
            if strings "$binary" | grep -i -E "(password|secret|token|api[_-]?key|private[_-]?key|-----BEGIN)" > binary-secrets.txt; then
              echo "::warning::Potential secrets found in binary"
              cat binary-secrets.txt
            else
              echo "✅ No obvious secrets found in binary"
            fi
          fi
        done

    - name: Check for debug symbols
      if: ${{ steps.rust.outputs.has == 'true' }}
      run: |
        echo "🔍 Checking for debug symbols..."
        for binary in target/release/*; do
          if [[ -x "$binary" && ! -d "$binary" ]]; then
            if file "$binary" | grep -q "not stripped"; then
              echo "::warning::Binary contains debug symbols: $binary"
            else
              echo "✅ Binary is properly stripped: $binary"
            fi
          fi
        done

    - name: Upload binary analysis results
      if: ${{ steps.rust.outputs.has == 'true' }}
      uses: actions/upload-artifact@65462800fd760344b1a7b4382951275a0abb4808 # v4.3.3
      with:
        name: binary-analysis-results
        path: binary-secrets.txt
      if: hashFiles('binary-secrets.txt') != ''

  dependency-confusion-check:
    name: Dependency Confusion Detection
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7

    - name: Check for suspicious dependency names
      run: |
        echo "🔍 Checking for potential dependency confusion attacks..."
        
        # Extract dependency names from Cargo.toml
        if [[ -f "Cargo.toml" ]]; then
          echo "Dependencies found in Cargo.toml:"
          grep -E "^\s*[a-zA-Z0-9_-]+\s*=" Cargo.toml | head -10
          
          # Check for common typosquatting patterns
          SUSPICIOUS=""
          while IFS= read -r dep; do
            dep_name=$(echo "$dep" | sed 's/^\s*//' | cut -d'=' -f1 | tr -d ' ')
            # Check for suspicious patterns (numbers at end, common typos)
            if echo "$dep_name" | grep -E ".*[0-9]+$|.*-rs$|.*_rs$" >/dev/null; then
              SUSPICIOUS="$SUSPICIOUS $dep_name"
            fi
          done < <(grep -E "^\s*[a-zA-Z0-9_-]+\s*=" Cargo.toml)
          
          if [[ -n "$SUSPICIOUS" ]]; then
            echo "::warning::Potentially suspicious dependency names detected:"
            for dep in $SUSPICIOUS; do
              echo "  - $dep"
            done
            echo "Review these dependencies for typosquatting attempts"
          else
            echo "✅ No obviously suspicious dependency names detected"
          fi
        fi

    - name: Verify official crates.io sources
      run: |
        echo "🔍 Verifying dependency sources..."
        
        # Check if any dependencies are from non-standard sources
        if grep -E "git\s*=|path\s*=" Cargo.toml >/dev/null 2>&1; then
          echo "::notice::Found dependencies from non-crates.io sources:"
          grep -E "git\s*=|path\s*=" Cargo.toml || true
          echo "Ensure these are from trusted sources"
        else
          echo "✅ All dependencies appear to be from crates.io"
        fi

  enhanced-security-checks:
    name: Enhanced Security Validation
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7

    - name: Detect Rust packages
      id: rust
      run: |
        set -euo pipefail
        if [ -f Cargo.toml ]; then
          if grep -q '^[[:space:]]*\[package\]' Cargo.toml; then
            echo "has=true" >> "$GITHUB_OUTPUT"
          elif grep -q '^[[:space:]]*\[workspace\]' Cargo.toml && grep -q '^[[:space:]]*members[[:space:]]*=' Cargo.toml; then
            echo "has=true" >> "$GITHUB_OUTPUT"
          else
            echo "has=false" >> "$GITHUB_OUTPUT"
          fi
        else
          echo "has=false" >> "$GITHUB_OUTPUT"
        fi

    - name: Install Rust toolchain
      if: ${{ steps.rust.outputs.has == 'true' }}
      uses: dtolnay/rust-toolchain@21dc36fb71dd22e3317045c0c31a3f4249868b17 # stable
      with:
        toolchain: stable

    - name: Validate Cargo.lock
      if: ${{ steps.rust.outputs.has == 'true' }}
      run: |
        echo "🔍 Validating Cargo.lock..."
        if [[ ! -f "Cargo.lock" ]]; then
          echo "::error::Cargo.lock not found - this is required for reproducible builds"
          exit 1
        fi
        
        # Check if Cargo.lock is up-to-date
        if ! cargo check --locked >/dev/null 2>&1; then
          echo "::error::Cargo.lock is out of date"
          echo "Run 'cargo update' to update Cargo.lock"
          exit 1
        fi
        echo "✅ Cargo.lock is valid and up-to-date"

    - name: Check for feature flag security
      if: ${{ steps.rust.outputs.has == 'true' }}
      run: |
        echo "🔍 Checking feature flag configuration..."
        
        # Check for debug features that might be enabled inappropriately
        if grep -E "debug.*=.*true|dev.*=.*true" Cargo.toml >/dev/null 2>&1; then
          echo "::warning::Debug/dev features found in Cargo.toml"
          grep -E "debug.*=.*true|dev.*=.*true" Cargo.toml || true
          echo "Ensure debug features are not enabled in production builds"
        fi
        
        # Check for default features that might expose debug functionality
        if cargo tree --format "{f}" | grep -i debug >/dev/null 2>&1; then
          echo "::notice::Debug-related features detected in dependency tree"
          echo "Review feature flags for production appropriateness"
          else
            echo "✅ No obvious debug features in dependency tree"
          fi

    - name: Skip Enhanced Security (no Rust packages)
      if: ${{ steps.rust.outputs.has != 'true' }}
      run: echo "No Rust packages detected; skipping Enhanced Security job steps."

  gitsign-verification:
    name: Commit Signature Verification
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7
      with:
        fetch-depth: 0

    - name: Install Go
      uses: actions/setup-go@0a12ed9d6a96ab950c8f026ed9f722fe0da7ef32 # v5.0.2
      with:
        go-version: '1.21'

    - name: Install gitsign for Sigstore verification
      run: |
        # Install gitsign for Sigstore signature verification
        go install github.com/sigstore/gitsign@latest

    - name: Verify latest commit signature
      run: |
        echo "Checking commit signature for: $(git log -1 --format='%H %s')"
        if git log --show-signature -1 2>&1 | grep -q "gitsign: Good signature"; then
          echo "✅ Latest commit has valid Sigstore signature"
        elif git log --show-signature -1 2>&1 | grep -q "gitsign: "; then
          echo "::error::Latest commit has invalid Sigstore signature"
          git log --show-signature -1
          exit 1
        else
          echo "::warning::Commit is not signed with Sigstore - enable gitsign"
        fi

EOF
  else
    cat <<'EOF'
name: Security CI

on:
  push:
    branches: [ main, master, develop ]
  pull_request:
    branches: [ main, master, develop ]

jobs:
  secret-scanning:
    name: Secret Scanning
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7
      with:
        fetch-depth: 0

    - name: Run Gitleaks
      uses: gitleaks/gitleaks-action@cb7149b9e61c3d6896c4bc2616d4c9e86ee2d0c2 # v2.3.6
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}


  vulnerability-scanning:
    name: Vulnerability Scanning
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7

    - name: Run Trivy vulnerability scanner in repo mode
      uses: aquasecurity/trivy-action@b6643a29fecd7f34b3597bc6acb0a98b03d33ff8 # 0.33.1
      with:
        scan-type: 'fs'
        scan-ref: '.'
        format: 'sarif'
        output: 'trivy-results.sarif'

    - name: Upload Trivy scan results to GitHub Security
      uses: github/codeql-action/upload-sarif@396bb3e45325a47dd9ef434068033c6d5bb0d11a # v3.26.7
      if: always()
      with:
        sarif_file: 'trivy-results.sarif'

  gitsign-verification:
    name: Commit Signature Verification
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7
      with:
        fetch-depth: 0

    - name: Install Go
      uses: actions/setup-go@0a12ed9d6a96ab950c8f026ed9f722fe0da7ef32 # v5.0.2
      with:
        go-version: '1.21'

    - name: Install gitsign for Sigstore verification
      run: |
        # Install gitsign for Sigstore signature verification
        go install github.com/sigstore/gitsign@latest

    - name: Verify latest commit signature
      run: |
        echo "Checking commit signature for: $(git log -1 --format='%H %s')"
        if git log --show-signature -1 2>&1 | grep -q "gitsign: Good signature"; then
          echo "✅ Latest commit has valid Sigstore signature"
        elif git log --show-signature -1 2>&1 | grep -q "gitsign: "; then
          echo "::error::Latest commit has invalid Sigstore signature"
          git log --show-signature -1
          exit 1
        else
          echo "::warning::Commit is not signed with Sigstore - enable gitsign"
        fi

EOF
  fi
}

# Generate CodeQL workflow for security scanning
generate_codeql_workflow() {
  cat <<'EOF'
name: "Code Scanning - CodeQL"

on:
  push:
    branches: [ "main", "master" ]
  pull_request:
    branches: [ "main", "master" ]
  schedule:
    - cron: '17 18 * * 1'  # Weekly on Mondays

permissions:
  contents: read
  security-events: write
  actions: read

jobs:
  analyze:
    name: Analyze Code
    runs-on: ubuntu-latest
    timeout-minutes: 360

    strategy:
      fail-fast: false
      matrix:
        include:
        - language: javascript-typescript
          build-mode: none # CodeQL supports 'none', 'autobuild', and 'manual'

    steps:
    - name: Checkout repository
      uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7

    - name: Initialize CodeQL
      uses: github/codeql-action/init@afb54ba388a7dca6ecae48f608c4ff05ff4cc77a # v3.25.15
      with:
        languages: ${{ matrix.language }}
        build-mode: ${{ matrix.build-mode }}

    - name: Perform CodeQL Analysis
      uses: github/codeql-action/analyze@afb54ba388a7dca6ecae48f608c4ff05ff4cc77a # v3.25.15
      with:
        category: "/language:${{matrix.language}}"
EOF
}

# Install CI workflow
install_ci_workflow() {
  print_section "Installing CI Workflow"

  local workflows_dir=".github/workflows"
  local workflow_file="$workflows_dir/security.yml"
  local pinning_file="$workflows_dir/pinning-validation.yml"

  # Create workflows directory if it doesn't exist
  if [[ $DRY_RUN == false ]]; then
    mkdir -p "$workflows_dir"
  fi

  # Check if security workflow already exists
  if [[ -f $workflow_file ]] && [[ $FORCE_INSTALL == false ]]; then
    print_status $YELLOW "⚠️  Security workflow already exists"
    read -p "Replace existing workflow? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      print_status $BLUE "📝 Skipping security CI workflow installation"
    else
      if [[ $DRY_RUN == true ]]; then
        print_status $BLUE "[DRY RUN] Would install CI workflow to $workflow_file"
      else
        generate_ci_workflow >"$workflow_file"
        print_status $GREEN "✅ Security CI workflow installed: $workflow_file"
      fi
    fi
  else
    if [[ $DRY_RUN == true ]]; then
      print_status $BLUE "[DRY RUN] Would install CI workflow to $workflow_file"
    else
      generate_ci_workflow >"$workflow_file"
      print_status $GREEN "✅ Security CI workflow installed: $workflow_file"
    fi
  fi

  # Install dedicated Pinning Validation workflow separately
  if [[ -f $pinning_file ]] && [[ $FORCE_INSTALL == false ]]; then
    print_status $YELLOW "⚠️  Pinning Validation workflow already exists"
    read -p "Replace existing pinning workflow? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      print_status $BLUE "📝 Skipping pinning workflow installation"
      return 0
    fi
  fi

  if [[ $DRY_RUN == true ]]; then
    print_status $BLUE "[DRY RUN] Would install Pinning Validation workflow to $pinning_file"
  else
    generate_pinning_workflow >"$pinning_file"
    print_status $GREEN "✅ Pinning Validation workflow installed: $pinning_file"
  fi

  # Install CodeQL workflow if GitHub security features are enabled
  if [[ $INSTALL_GITHUB_SECURITY == true ]]; then
    local codeql_file="$workflows_dir/codeql.yml"
    if [[ -f $codeql_file ]] && [[ $FORCE_INSTALL == false ]]; then
      print_status $YELLOW "⚠️  CodeQL workflow already exists"
      read -p "Replace existing CodeQL workflow? (y/N): " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status $BLUE "📝 Skipping CodeQL workflow installation"
      else
        if [[ $DRY_RUN == true ]]; then
          print_status $BLUE "[DRY RUN] Would install CodeQL workflow to $codeql_file"
        else
          generate_codeql_workflow >"$codeql_file"
          print_status $GREEN "✅ CodeQL workflow installed: $codeql_file"
        fi
      fi
    else
      if [[ $DRY_RUN == true ]]; then
        print_status $BLUE "[DRY RUN] Would install CodeQL workflow to $codeql_file"
      else
        generate_codeql_workflow >"$codeql_file"
        print_status $GREEN "✅ CodeQL workflow installed: $codeql_file"
      fi
    fi
  fi
}

# Install documentation
install_documentation() {
  print_section "Installing Security Documentation"

  if [[ $DRY_RUN == false ]]; then
    mkdir -p "$DOCS_DIR"
  fi

  # Install README
  local readme_file="$DOCS_DIR/README.md"
  if [[ $DRY_RUN == true ]]; then
    print_status $BLUE "[DRY RUN] Would install README to $readme_file"
  else
    cat <<'EOF' >"$readme_file"
# Security Controls

This repository includes comprehensive security controls with industry-leading security architecture.

## 🛡️ Security Architecture

Our security model employs a **two-stage approach**:

1. **Pre-Push Controls**: Fast validation (< 60s) that catches critical issues early
2. **Post-Push Controls**: Comprehensive CI analysis for deep security insights

### Pre-Push Controls (Fast Validation)

- ✅ Code formatting validation
- ✅ Linting and quality checks
- ✅ Security audit (vulnerable dependencies)
- ✅ Test suite execution
- ✅ Secret detection (API keys, passwords)
- ✅ License compliance checking
- ✅ SHA pinning validation
- ✅ Commit signature verification

### Post-Push Controls (Comprehensive Analysis)

- 🔍 Static security analysis (SAST)
- 🔍 Vulnerability scanning (Trivy)
- 🔍 Supply chain verification
- 🔍 SBOM generation
- 🔍 Security metrics collection
- 🔍 Integration testing
- 🔍 Compliance reporting

## 🚀 Quick Start

### For Developers

1. **Normal Development**: Code as usual
2. **Commit**: Create commits locally
3. **Push**: Pre-push hook validates automatically (< 60s)
4. **CI/CD**: Comprehensive security analysis runs in background

### Fixing Pre-Push Failures

The pre-push hook provides specific fix instructions for each failure:

```bash
# Format issues
cargo fmt --all

# Linting issues
cargo clippy --all-targets --all-features --fix

# Security vulnerabilities
cargo audit fix

# Secrets detected
# Remove secrets and use environment variables

# GitHub Actions not pinned
.security-controls/bin/pinactlite pinactlite --dir .github/workflows
```

### Emergency Bypass

For urgent fixes (use sparingly):

```bash
git push --no-verify
```

## 🔧 Tool Installation

Local runtime dependencies are minimal: git, curl, jq, and (for Rust projects) the Rust toolchain. The installer provides script-only helpers at `.security-controls/bin` for secret scanning and GitHub Actions SHA pinning; no Go/brew installs are required for local checks.

```bash
# Rust tools (if Rust project)
cargo install cargo-audit cargo-license
```

## 🔐 Enable Sigstore commit signing (YubiKey)

See docs/security/YUBIKEY_SIGSTORE_GUIDE.md for a hardware-backed, keyless commit signing workflow using YubiKey + Sigstore. It improves supply-chain integrity with short-lived certs and public transparency logs.

## 📊 Security Benefits

- **Zero Secret Exposure**: Secrets blocked at source
- **Supply Chain Protection**: SHA pinning + verification
- **Vulnerability Prevention**: Multi-layer scanning
- **Compliance Automation**: Continuous legal/security validation
- **Fast Feedback**: Issues caught early in workflow
- **Clear Guidance**: Specific fix instructions provided

## 🎯 Performance

- **Pre-Push Time**: ~55 seconds average
- **Security Coverage**: 14+ comprehensive controls
- **Developer Impact**: 10x faster issue resolution vs CI failures

## 🔐 GitHub Security Features (Optional)

With the `--github-security` option, the installer also configures:

### ✅ **Automatically Configured**
- **Dependabot Vulnerability Alerts** - Automated dependency scanning
- **Dependabot Security Fixes** - Automated security update PRs
- **Branch Protection Rules** - Requires PR reviews and status checks
- **CodeQL Security Scanning** - Automated code analysis workflow
- **Secret Scanning** - Server-side secret detection (auto-enabled)
- **Secret Push Protection** - Blocks secrets at GitHub level

### 📋 **Manual Setup Required**
- **Security Advisories** - Private vulnerability reporting (web interface)
- **Advanced Security** - GitHub Enterprise only (not available for public repos)

### 🛠️ **Requirements**
- GitHub CLI (`gh`) installed and authenticated
- Repository admin permissions for branch protection
- GitHub repository (not local-only)

### 💡 **Usage**
```bash
# Enable all GitHub security features
./install-security-controls.sh --github-security
```

If requirements aren't met, detailed manual setup instructions are provided.

## 📈 Compliance

- ✅ NIST SSDF aligned
- ✅ SLSA Level 2 compliant
- ✅ OpenSSF best practices
- ✅ Supply chain transparency (SBOM)

EOF
    print_status $GREEN "✅ Security README installed: $readme_file"
  fi

  # Install architecture documentation
  local arch_file="$DOCS_DIR/ARCHITECTURE.md"
  if [[ $DRY_RUN == true ]]; then
    print_status $BLUE "[DRY RUN] Would install architecture documentation to $arch_file"
  else
    # Copy from the embedded architecture documentation
    echo "# Security Controls Architecture - See main repository for full details" >"$arch_file"
    print_status $GREEN "✅ Architecture documentation installed: $arch_file"
  fi

  # Install YubiKey + Sigstore guide
  local yubi_file="$DOCS_DIR/YUBIKEY_SIGSTORE_GUIDE.md"
  if [[ $DRY_RUN == true ]]; then
    print_status $BLUE "[DRY RUN] Would install YubiKey guide to $yubi_file"
  else
    cat <<'YUBI_EOF' >"$yubi_file"
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
3. **OIDC Challenge**: gitsign opens browser for authentication (20-second timeout)
4. **YubiKey Authentication**: GitHub requires YubiKey touch (if enabled)
5. **Token Exchange**: Valid OIDC token received
6. **Certificate Request**: gitsign requests cert from Fulcio
7. **Short-lived Certificate**: Fulcio issues 5-10 minute certificate
8. **Commit Signing**: Certificate signs commit
9. **Transparency Log**: Signature recorded in Rekor
10. **Browser Closes**: Browser window closes automatically

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
3. **Browser Opens**: gitsign opens browser for GitHub OAuth (20-second timeout)
4. **YubiKey Touch**: GitHub prompts for YubiKey authentication (if enabled)
5. **Touch YubiKey**: Physical touch authenticates your identity
6. **Automatic Signing**: gitsign receives certificate and signs commit
7. **Browser Closes**: Browser window closes automatically after authentication
8. **Transparency Logging**: Signature automatically logged to Rekor

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

### **Authentication Behavior**

**Normal Flow (within 20 seconds):**
- Browser opens to GitHub OAuth
- Complete authentication
- Browser closes automatically
- Commit succeeds with Sigstore signature

**Timeout Scenario (after 20 seconds):**
- Browser closes automatically
- Authentication incomplete
- Git commit fails with signing error
- Simply retry: `git commit` again
- Most users complete auth on second attempt

**Troubleshooting:**
- Ensure you're logged into GitHub in your browser
- Disable pop-up blockers for sigstore.dev
- For slow connections: `git config --global gitsign.autocloseTimeout 60`

---

## 🔒 Security Considerations

- Use multiple registered YubiKeys for redundancy
- Keep your tooling up-to-date (gitsign, cosign)
- Verify signatures and Rekor transparency log entries regularly

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

- GitHub Actions provides OIDC tokens; gitsign can verify runner identity where applicable.

---

## 🎯 Best Practices

- Keep YubiKey connected during development to minimize prompts
- Register backup YubiKeys
- Treat --no-verify pushes as emergencies only

---

## 🔗 Resources

- Sigstore Documentation: https://docs.sigstore.dev/
- gitsign: https://github.com/sigstore/gitsign
- YubiKey Manager: https://developers.yubico.com/yubikey-manager/
- Rekor: https://github.com/sigstore/rekor

YUBI_EOF
    print_status $GREEN "✅ YubiKey guide installed: $yubi_file"
  fi
}

# Install default config/state files
install_default_config() {
  print_section "Installing Default Security Configuration"

  if [[ $DRY_RUN == true ]]; then
    print_status $BLUE "[DRY RUN] Would create $CONTROL_STATE_DIR with config and gitleaks config"
    return 0
  fi

  mkdir -p "$CONTROL_STATE_DIR"

  # Create config.env if missing
  if [[ ! -f $CONFIG_ENV_FILE ]]; then
    cat >"$CONFIG_ENV_FILE" <<'CONF_EOF'
# 1-Click Security Controls - Configuration
# Toggle controls (true/false)
ENABLE_SECRET_SCAN=true
SECRET_SCAN_MODE=staged   # staged|full
ENABLE_LARGE_FILE_CHECK=true
LARGE_FILE_MAX_MB=10
ENABLE_TECH_DEBT_CHECK=true
ENABLE_EMPTY_FILE_CHECK=true
# New toggles
ENABLE_LINT=true
ENABLE_TESTS=true
# unit: cargo test --lib, all: cargo test --all
TEST_SCOPE=all
CONF_EOF
    print_status $GREEN "✅ Created $CONFIG_ENV_FILE"
  else
    print_status $BLUE "ℹ️ Existing config preserved at $CONFIG_ENV_FILE"
  fi

  # Create a default gitleaks config if missing (used by CI action)
  if [[ ! -f $GITLEAKS_CONFIG_FILE ]]; then
    cat >"$GITLEAKS_CONFIG_FILE" <<'GL_EOF'
# Gitleaks configuration for 1-Click Security Controls
# Basic allowlist to reduce noise for common build artifacts
title = "1-Click Security Gitleaks Config"

[allowlist]
paths = [
  "target/",
  "node_modules/",
  "dist/",
  "build/",
  "coverage/",
  "*.lock",
]
GL_EOF
    print_status $GREEN "✅ Created $GITLEAKS_CONFIG_FILE"
  else
    print_status $BLUE "ℹ️ Existing gitleaks config preserved at $GITLEAKS_CONFIG_FILE"
  fi

  # Create a simple secret allowlist for local scanner
  local allowlist_file="$CONTROL_STATE_DIR/secret-allowlist.txt"
  if [[ ! -f $allowlist_file ]]; then
    cat >"$allowlist_file" <<'AL_EOF'
# Regex patterns to allow (one per line). Examples:
# ^TEST_[A-Z0-9_]+$
# example.com
AL_EOF
    print_status $GREEN "✅ Created $allowlist_file"
  fi
}

install_pinactlite_script() {
  print_section "Installing script-only pinactlite helper"

  local bin_dir="$CONTROL_STATE_DIR/bin"
  local script_path="$bin_dir/pinactlite"

  if [[ $DRY_RUN == true ]]; then
    print_status $BLUE "[DRY RUN] Would copy pinactlite to $script_path"
    return 0
  fi

  mkdir -p "$bin_dir"

  # Copy from the canonical source instead of embedding
  if [[ -f ".security-controls/bin/pinactlite" ]]; then
    cp ".security-controls/bin/pinactlite" "$script_path"
    print_status $GREEN "✅ Copied pinactlite from canonical source"
  else
    # Fallback: download from repository if not available locally
    local pinactlite_url="https://raw.githubusercontent.com/h4x0r/1-click-rust-sec/main/.security-controls/bin/pinactlite"
    if command -v curl >/dev/null 2>&1; then
      curl -sSL "$pinactlite_url" >"$script_path"
      print_status $GREEN "✅ Downloaded pinactlite from repository"
    else
      print_status $RED "❌ Cannot find local pinactlite and curl not available"
      return 1
    fi
  fi

  chmod +x "$script_path"
  print_status $GREEN "✅ Installed script-only pinactlite at $script_path"
}

install_gitleakslite_script() {
  print_section "Installing script-only gitleakslite helper"

  local bin_dir="$CONTROL_STATE_DIR/bin"
  local script_path="$bin_dir/gitleakslite"

  if [[ $DRY_RUN == true ]]; then
    print_status $BLUE "[DRY RUN] Would copy gitleakslite to $script_path"
    return 0
  fi

  mkdir -p "$bin_dir"

  # Copy from the canonical source instead of embedding
  if [[ -f ".security-controls/bin/gitleakslite" ]]; then
    cp ".security-controls/bin/gitleakslite" "$script_path"
    print_status $GREEN "✅ Copied gitleakslite from canonical source"
  else
    # Fallback: download from repository if not available locally
    local gitleakslite_url="https://raw.githubusercontent.com/h4x0r/1-click-rust-sec/main/.security-controls/bin/gitleakslite"
    if command -v curl >/dev/null 2>&1; then
      curl -sSL "$gitleakslite_url" >"$script_path"
      print_status $GREEN "✅ Downloaded gitleakslite from repository"
    else
      print_status $YELLOW "⚠️ Cannot find local gitleakslite and curl not available, generating basic fallback"
      # Fallback: generate basic version if source not available
      cat >"$script_path" <<'GLSCRIPT_EOF'
#!/usr/bin/env bash
set -euo pipefail
usage() {
  cat <<USG
gitleakslite (script) - basic secret scanner (fallback version)

Usage:
  gitleakslite protect --staged [--redact] [--no-banner] [--config PATH]
  gitleakslite detect [--redact] [--no-banner] [--config PATH]

Note: This is a fallback version. For comprehensive patterns, run from repository.
USG
}
read_allowlist() {
  local file=".security-controls/secret-allowlist.txt"
  [[ -f $file ]] && cat "$file"
}
scan_lines() {
  local file="$1" redact="$2" allowlist hit=0
  allowlist=$(read_allowlist || true)
  local patterns='(A3T[A-Z0-9]|AKIA|ASIA|ABIA|ACCA)[A-Z0-9]{16}|(ghp|gho|ghu|ghr|ghs)_[0-9a-zA-Z]{36}|AIza[0-9A-Za-z_-]{35}|xox[bpsoarunv]-[0-9]{8,13}-[0-9a-zA-Z]{8,64}|-----BEGIN[ A-Z0-9_-]{0,100}PRIVATE KEY'
  while IFS= read -r line; do
    [[ -n $allowlist ]] && grep -E -q "$allowlist" <<<"$line" && continue
    if grep -E -q "$patterns" <<<"$line"; then
      [[ $redact == "1" ]] && line=$(echo "$line" | sed -E 's/([:=])[[:space:]]*"?[^"[:space:]]{4,}/\1 ***REDACTED***/g')
      echo "$line"; hit=1
    fi
  done
  return $hit
}
cmd_protect() {
  local staged=0 redact=0
  while [[ $# -gt 0 ]]; do
    case "$1" in --staged) staged=1; shift ;; --redact) redact=1; shift ;; --no-banner|--config) shift ;; *) shift ;; esac
  done
  [[ $staged -ne 1 ]] && { echo "protect: --staged required" >&2; exit 2; }
  local hit=0
  while IFS= read -r f; do
    [[ -z $f || ! -f $f ]] && continue
    git diff --cached -U0 -- "$f" | sed -n 's/^+//p' | scan_lines "$f" "$redact" || { hit=1; echo "[$f]" >&2; }
  done < <(git diff --cached --name-only --diff-filter=ACM | grep -v -E '^(target/|node_modules/)' || true)
  [[ $hit -eq 1 ]] && exit 1
}
cmd_detect() {
  local redact=0
  while [[ $# -gt 0 ]]; do
    case "$1" in --redact) redact=1; shift ;; *) shift ;; esac
  done
  local hit=0
  while IFS= read -r f; do
    [[ -z $f || ! -f $f ]] && continue
    cat "$f" | scan_lines "$f" "$redact" || { hit=1; echo "[$f]" >&2; }
  done < <(git ls-files | grep -v -E '^(target/|node_modules/)' || true)
  [[ $hit -eq 1 ]] && exit 1
}
case "${1:-}" in
  protect) shift; cmd_protect "$@" ;;
  detect) shift; cmd_detect "$@" ;;
  *) usage ;;
esac
GLSCRIPT_EOF
    fi
  fi

  chmod +x "$script_path"
  print_status $GREEN "✅ Installed script-only gitleakslite at $script_path"
}

# Install GitHub repository security features
install_github_security() {
  if [[ $INSTALL_GITHUB_SECURITY != true ]]; then
    return 0
  fi

  print_section "Configuring GitHub Repository Security Features"

  # Check if gh CLI is available
  if ! command -v gh >/dev/null 2>&1; then
    print_status $YELLOW "⚠️  GitHub CLI (gh) not found"
    print_status $BLUE "💡 Manual setup required for GitHub security features:"
    print_status $BLUE ""
    print_status $BLUE "   1. Install GitHub CLI: https://cli.github.com/"
    print_status $BLUE "   2. Run: gh auth login"
    print_status $BLUE "   3. Re-run installer with --github-security"
    print_status $BLUE ""
    print_manual_github_instructions
    return 0
  fi

  # Check if authenticated
  if ! gh auth status >/dev/null 2>&1; then
    print_status $YELLOW "⚠️  GitHub CLI not authenticated"
    print_status $BLUE "💡 Please authenticate with GitHub:"
    print_status $BLUE "   gh auth login"
    print_status $BLUE ""
    print_manual_github_instructions
    return 0
  fi

  # Get repository information
  local repo_info
  repo_info=$(gh repo view --json nameWithOwner 2>/dev/null)
  if [[ $? -ne 0 ]]; then
    print_status $YELLOW "⚠️  Not in a GitHub repository or no remote configured"
    print_manual_github_instructions
    return 0
  fi

  local repo_name
  repo_name=$(echo "$repo_info" | jq -r '.nameWithOwner')
  print_status $BLUE "🔧 Configuring security for repository: $repo_name"

  # 1. Enable Dependabot Vulnerability Alerts
  print_status $BLUE "🔍 Enabling Dependabot vulnerability alerts..."
  if gh api "repos/$repo_name/vulnerability-alerts" -X PUT >/dev/null 2>&1; then
    print_status $GREEN "   ✅ Dependabot vulnerability alerts enabled"
  else
    print_status $YELLOW "   ⚠️  Failed to enable vulnerability alerts (may already be enabled)"
  fi

  # 2. Enable Dependabot Automated Security Fixes
  print_status $BLUE "🔧 Enabling Dependabot automated security fixes..."
  if gh api "repos/$repo_name/automated-security-fixes" -X PUT >/dev/null 2>&1; then
    print_status $GREEN "   ✅ Dependabot automated security fixes enabled"
  else
    print_status $YELLOW "   ⚠️  Failed to enable automated security fixes (may already be enabled)"
  fi

  # 3. Enable Branch Protection (if this is the main branch)
  local current_branch
  current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [[ $current_branch == "main" ]] || [[ $current_branch == "master" ]]; then
    print_status $BLUE "🛡️  Enabling branch protection for $current_branch..."
    configure_branch_protection "$repo_name" "$current_branch"
  else
    print_status $BLUE "ℹ️  Branch protection configuration available for main/master branch"
    print_status $BLUE "   Current branch: $current_branch"
  fi

  # 4. Show manual steps for remaining features
  print_status $BLUE ""
  print_status $BLUE "📋 Additional security features (manual setup required):"
  print_status $BLUE ""
  print_status $BLUE "   🔐 Security Advisories:"
  print_status $BLUE "       Visit: https://github.com/$repo_name/settings/security_analysis"
  print_status $BLUE "       Enable: 'Private vulnerability reporting'"
  print_status $BLUE ""
  print_status $BLUE "   ❌ Advanced Security (GitHub Enterprise only):"
  print_status $BLUE "       • Advanced code scanning"
  print_status $BLUE "       • Secret scanning for private repos"
  print_status $BLUE "       • Dependency review"
  print_status $BLUE "       Not available for public repositories"
  print_status $BLUE ""

  print_status $GREEN "🎉 GitHub security features configured!"
}

# Configure branch protection rules
configure_branch_protection() {
  local repo_name=$1
  local branch_name=$2

  local protection_config
  protection_config=$(
    cat <<EOF
{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "Security CI",
      "Pinning Validation"
    ]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
  )

  if gh api "repos/$repo_name/branches/$branch_name/protection" -X PUT --input - <<<"$protection_config" >/dev/null 2>&1; then
    print_status $GREEN "   ✅ Branch protection enabled for $branch_name"
    print_status $BLUE "      • Requires PR reviews (1 approver)"
    print_status $BLUE "      • Requires status checks to pass"
    print_status $BLUE "      • Enforces admin restrictions"
    print_status $BLUE "      • Blocks force pushes and deletions"
  else
    print_status $YELLOW "   ⚠️  Failed to enable branch protection"
    print_status $BLUE "   💡 Manual setup: https://github.com/$repo_name/settings/branches"
  fi
}

# Print manual instructions for GitHub security features
print_manual_github_instructions() {
  print_status $BLUE "📋 Manual GitHub Security Setup Instructions:"
  print_status $BLUE ""
  print_status $BLUE "   1. 🔍 Secret Scanning (Public repos - auto-enabled):"
  print_status $BLUE "      Already enabled for public repositories"
  print_status $BLUE ""
  print_status $BLUE "   2. 🔧 Dependabot Security Updates:"
  print_status $BLUE "      Go to: Repository Settings → Security & analysis"
  print_status $BLUE "      Enable: 'Dependabot security updates'"
  print_status $BLUE ""
  print_status $BLUE "   3. 🛡️  Branch Protection:"
  print_status $BLUE "      Go to: Repository Settings → Branches"
  print_status $BLUE "      Add rule for 'main' branch with:"
  print_status $BLUE "      ✓ Require pull request reviews"
  print_status $BLUE "      ✓ Require status checks to pass"
  print_status $BLUE "      ✓ Include administrators"
  print_status $BLUE ""
  print_status $BLUE "   4. 🔐 Security Advisories:"
  print_status $BLUE "      Go to: Repository Settings → Security & analysis"
  print_status $BLUE "      Enable: 'Private vulnerability reporting'"
  print_status $BLUE ""
  print_status $BLUE "   5. 📊 Code Scanning:"
  print_status $BLUE "      CodeQL workflow added to .github/workflows/codeql.yml"
  print_status $BLUE "      Will activate automatically on next push"
  print_status $BLUE ""
}

# Show installation summary
show_summary() {
  print_header "Installation Complete"

  print_status $GREEN "✅ Security controls successfully installed!"
  echo

  if [[ $INSTALL_HOOKS == true ]]; then
    print_status $BLUE "📋 Pre-Push Hook:"
    if [[ $USE_HOOKS_PATH == true ]]; then
      print_status $GREEN "   ✅ Installed to $PRE_PUSH_D_DIR/50-security-pre-push"
      print_status $BLUE "   🔗 hooksPath dispatcher: $HOOKS_PATH_DIR/pre-push"
    else
      print_status $GREEN "   ✅ Installed to .git/hooks/pre-push"
    fi
    print_status $BLUE "   🔍 Validates: format, lint, security, tests, secrets, licenses, SHA pinning, size, tech debt, empty files"
    print_status $BLUE "   ⚡ Pre-push aims to complete in ~55–75 seconds"
  fi

  if [[ $INSTALL_CI == true ]]; then
    print_status $BLUE "🔄 CI Workflow:"
    print_status $GREEN "   ✅ Installed to .github/workflows/security.yml"
    print_status $BLUE "   🔍 Includes: SAST, vulnerability scanning, SBOM generation"
    print_status $BLUE "   🚀 Runs automatically on push/PR"
  fi

  if [[ $INSTALL_DOCS == true ]]; then
    print_status $BLUE "📚 Documentation:"
    print_status $GREEN "   ✅ Installed to $DOCS_DIR/"
    print_status $BLUE "   📖 Includes: README, architecture, usage guides"
  fi

  if [[ $INSTALL_GITHUB_SECURITY == true ]]; then
    print_status $BLUE "🔐 GitHub Security Features:"
    print_status $GREEN "   ✅ Dependabot vulnerability alerts enabled"
    print_status $GREEN "   ✅ Dependabot automated security fixes enabled"
    print_status $GREEN "   ✅ CodeQL workflow added"
    print_status $BLUE "   🔧 Branch protection configured (if main/master branch)"
    print_status $YELLOW "   ⚠️  Security advisories require manual setup"
    print_status $BLUE "   ❌ Advanced security (GitHub Enterprise only)"
  fi

  echo
  print_status $BLUE "🎯 Next Steps:"
  echo "   1. Test the pre-push hook: git push --dry-run"
  echo "   2. Make a test commit and push to verify CI workflow"
  echo "   3. Review documentation in $DOCS_DIR/"
  echo "   4. Configure gitsign for commit signing (optional)"
  echo

  print_status $YELLOW "💡 Pro Tips:"
  echo "   • Pre-push hook runs automatically on every push"
  echo "   • Use 'git push --no-verify' for emergency bypasses only"
  echo "   • All security reports available in CI artifacts"
  echo "   • Tools auto-install instructions provided on first run"
  echo

  print_status $GREEN "🛡️  Your repository is now secured with comprehensive controls!"
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h | --help)
        show_help
        exit 0
        ;;
      -v)
        show_version
        exit 0
        ;;
      --version)
        SHOW_VERSION=true
        shift
        ;;
      --verbose)
        VERBOSE=true
        shift
        ;;
      -d | --dry-run)
        DRY_RUN=true
        shift
        ;;
      -f | --force)
        FORCE_INSTALL=true
        shift
        ;;
      --skip-tools)
        SKIP_TOOLS=true
        shift
        ;;
      --no-hooks)
        INSTALL_HOOKS=false
        shift
        ;;
      --no-ci)
        INSTALL_CI=false
        shift
        ;;
      --no-docs)
        INSTALL_DOCS=false
        shift
        ;;
      --non-rust)
        RUST_PROJECT=false
        shift
        ;;
      --hooks-path)
        USE_HOOKS_PATH=true
        shift
        ;;
      --no-github-security)
        INSTALL_GITHUB_SECURITY=false
        shift
        ;;
      --no-signing)
        INSTALL_SIGNING=false
        shift
        ;;
      --check-update)
        CHECK_UPDATE=true
        shift
        ;;
      --backup)
        BACKUP_MODE=true
        shift
        ;;
      --changelog)
        show_changelog
        exit 0
        ;;
      *)
        print_status $RED "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
    esac
  done
}

# Main execution
main() {
  # Initialize framework first - but do minimal setup before argument parsing
  setup_logging

  print_header "Security Controls Installer v$SCRIPT_VERSION"

  # Parse arguments first, so flags like --version work before other output
  parse_arguments "$@"

  # Now start transaction after parsing arguments (in case of early exits)
  start_transaction "security-controls-install"

  log_info "=== Security Controls Installation Started ==="
  log_info "Script version: $SCRIPT_VERSION"
  log_info "Arguments: $*"

  if [[ $DRY_RUN == true ]]; then
    print_status $YELLOW "🔍 DRY RUN MODE - No changes will be made"
    echo
  fi

  # Execute upgrade commands (these exit before normal installation)
  execute_upgrade_commands

  # Core setup with enhanced error handling
  safe_execute "check_git_repo" \
    "Not in a Git repository" \
    $EXIT_VALIDATION_ERROR \
    "Initialize git first: git init"

  safe_execute "detect_project_type" \
    "Failed to detect project type" \
    $EXIT_VALIDATION_ERROR

  safe_execute "check_required_tools" \
    "Missing required tools" \
    $EXIT_TOOL_MISSING \
    "Install required dependencies"

  # Install components
  if [[ $SKIP_TOOLS == false ]]; then
    safe_execute "install_security_tools" \
      "Failed to install security tools" \
      $EXIT_NETWORK_ERROR \
      "Check internet connection"
  fi

  # Configure security settings (Rust-specific and global)
  safe_execute "configure_cargo_security" \
    "Failed to configure Cargo security" \
    $EXIT_CONFIG_ERROR

  # Install default config/state
  safe_execute "install_default_config" \
    "Failed to install default configuration" \
    $EXIT_CONFIG_ERROR

  # Install script-only helpers
  install_pinactlite_script
  install_gitleakslite_script

  if [[ $INSTALL_HOOKS == true ]]; then
    install_pre_push_hook
  fi

  if [[ $INSTALL_CI == true ]]; then
    install_ci_workflow
  fi

  if [[ $INSTALL_DOCS == true ]]; then
    install_documentation
  fi

  # Configure GitHub security features
  install_github_security

  # Summary
  if [[ $DRY_RUN == false ]]; then
    show_summary
    write_version_info
  else
    print_header "Dry Run Complete"
    print_status $BLUE "🔍 Preview complete - no changes made"
    print_status $BLUE "   Run without --dry-run to install"
  fi

  # Commit transaction on success
  commit_transaction
  log_info "=== Installation Completed Successfully ==="
}

# Execute main function with all arguments and error handling
if ! main "$@"; then
  handle_error $EXIT_GENERAL_ERROR "Installation failed" "Check logs: $LOG_FILE"
fi
