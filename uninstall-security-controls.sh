#!/usr/bin/env bash
set -euo pipefail

# uninstall-security-controls.sh
# Safely remove installed security controls from a repository
# Usage: ./uninstall-security-controls.sh [--dry-run] [--yes] [--verbose]

# Script version and metadata
readonly SCRIPT_VERSION="0.4.0"
readonly SCRIPT_NAME="Security Controls Uninstaller"

# Global flags
DRY_RUN=0
YES=0
VERBOSE=false

# Logging configuration
readonly LOG_DIR="$HOME/.security-controls-uninstaller/logs"
LOG_FILE="$LOG_DIR/uninstaller-$(date '+%Y%m%d_%H%M%S').log"
readonly LOG_FILE

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# ═══════════════════════════════════════════════════════════════════════════════
# EMBEDDED STANDARDIZED FRAMEWORK
# ═══════════════════════════════════════════════════════════════════════════════
# This framework provides comprehensive error handling, logging, and transaction
# management while maintaining the single-script architecture principle.
#
# Key Features:
# - Standardized error codes and exit handling
# - Comprehensive logging with timestamps and levels
# - Transaction and rollback system for file operations
# - Atomic operations with automatic cleanup
# - Safe execution wrappers with error recovery
# ═══════════════════════════════════════════════════════════════════════════════

# Standardized error codes
readonly EXIT_SUCCESS=0
# readonly EXIT_GENERAL_ERROR=1  # Unused but kept for consistency
readonly EXIT_PERMISSION_ERROR=3
# readonly EXIT_NETWORK_ERROR=4  # Unused but kept for consistency
# readonly EXIT_TOOL_MISSING=6   # Unused but kept for consistency
readonly EXIT_VALIDATION_ERROR=7
readonly EXIT_CONFIG_ERROR=9
# readonly EXIT_SECURITY_ERROR=10 # Unused but kept for consistency

# Transaction state for rollback capability
declare -a ROLLBACK_ACTIONS=()
declare -a REMOVED_FILES=()

# Logging functions with timestamp and level
log_message() {
  local level="$1"
  local message="$2"
  local context="${3:-}"
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

log_debug() { log_message "DEBUG" "$1" "${2:-}"; }
log_info() { log_message "INFO" "$1" "${2:-}"; }
log_warn() { log_message "WARN" "$1" "${2:-}"; }
log_error() { log_message "ERROR" "$1" "${2:-}"; }

# Transaction management for rollback capability
add_rollback() {
  local action="$1"
  ROLLBACK_ACTIONS+=("$action")
  log_debug "Added rollback action: $action"
}

commit_transaction() {
  log_info "Transaction committed successfully - clearing rollback actions"
  ROLLBACK_ACTIONS=()
  REMOVED_FILES=()
}

rollback_transaction() {
  if [[ ${#ROLLBACK_ACTIONS[@]} -eq 0 ]]; then
    log_debug "No rollback actions to execute"
    return 0
  fi

  log_warn "Rolling back ${#ROLLBACK_ACTIONS[@]} operations..."

  # Execute rollback actions in reverse order
  for ((i = ${#ROLLBACK_ACTIONS[@]} - 1; i >= 0; i--)); do
    local action="${ROLLBACK_ACTIONS[i]}"
    log_debug "Executing rollback: $action"
    if ! eval "$action" 2>/dev/null; then
      log_error "Rollback action failed: $action"
    fi
  done

  ROLLBACK_ACTIONS=()
  REMOVED_FILES=()
  log_info "Rollback completed"
}

# Safe execution wrapper with automatic error handling
safe_execute() {
  local command="$1"
  local description="${2:-Executing command}"
  local ignore_errors="${3:-false}"

  log_debug "Executing: $command"

  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[DRY RUN] $description: $command"
    return 0
  fi

  if eval "$command" 2>/dev/null; then
    log_debug "Completed: $command"
    return 0
  else
    local exit_code=$?
    if [[ $ignore_errors == "true" ]]; then
      log_warn "Command failed (ignored): $command (exit code: $exit_code)"
      return 0
    else
      log_error "Command failed: $command (exit code: $exit_code)"
      return $exit_code
    fi
  fi
}

# Safe exit with cleanup
safe_exit() {
  local exit_code="${1:-$EXIT_SUCCESS}"
  local message="${2:-}"

  if [[ -n $message ]]; then
    if [[ $exit_code -eq $EXIT_SUCCESS ]]; then
      log_info "$message"
    else
      log_error "$message"
    fi
  fi

  if [[ $exit_code -ne $EXIT_SUCCESS ]]; then
    log_error "Script exiting with error code: $exit_code"
    rollback_transaction
  else
    log_info "Script completed successfully"
    commit_transaction
  fi

  exit "$exit_code"
}

# Atomic removal with rollback support
atomic_remove() {
  local path="$1"
  local description="${2:-$path}"

  if [[ ! -e $path ]]; then
    log_debug "Path does not exist, skipping: $path"
    return 0
  fi

  log_info "Removing $description: $path"

  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[DRY RUN] Would remove: $path"
    return 0
  fi

  # Create backup before removal
  local backup_path
  backup_path="/tmp/security-controls-backup-$(date +%s)-$(basename "$path")"
  if cp -r "$path" "$backup_path" 2>/dev/null; then
    add_rollback "mv '$backup_path' '$path'"
    REMOVED_FILES+=("$path")
    log_debug "Created backup: $backup_path"
  else
    log_warn "Could not create backup for: $path"
  fi

  if rm -rf "$path" 2>/dev/null; then
    log_info "Successfully removed: $path"
    return 0
  else
    log_error "Failed to remove: $path"
    return $EXIT_PERMISSION_ERROR
  fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# END OF EMBEDDED FRAMEWORK
# ═══════════════════════════════════════════════════════════════════════════════

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
  cat <<USAGE
🛡️  Security Controls Uninstaller v${SCRIPT_VERSION}

🎯 PURPOSE:
    Safely remove installed security controls from a repository with
    comprehensive logging and rollback capabilities.

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --dry-run       Show what would be removed without changing anything
    -y, --yes       Do not prompt for confirmation
    --verbose       Enable verbose logging output
    -h, --help      Show this help
    -v, --version   Show version information

📝 WHAT GETS REMOVED:
    • Git hooks (pre-push)
    • GitHub workflows (security.yml, pinning-validation.yml)
    • Security controls directory (.security-controls)
    • Configuration files (.security-controls-version)
    • Documentation (docs/security)

🔒 SAFETY FEATURES:
    ✓ Automatic backups before removal
    ✓ Rollback capability on failures
    ✓ Comprehensive logging
    ✓ Dry-run mode for safe testing
    ✓ Selective removal (only installer-generated files)

EXAMPLES:
    # Preview what would be removed
    $0 --dry-run

    # Remove with confirmation prompt
    $0

    # Remove without prompts (CI/automation)
    $0 --yes

    # Remove with detailed logging
    $0 --verbose --yes

LOGS:
    All operations are logged to: $LOG_FILE

USAGE
}

show_version() {
  echo "Security Controls Uninstaller v${SCRIPT_VERSION}"
  echo "Safe removal of 1-Click GitHub Security controls"
  echo "https://github.com/4n6h4x0r/1-click-github-sec"
}

# Parse command line arguments
parse_arguments() {
  for arg in "$@"; do
    case "$arg" in
      --dry-run)
        DRY_RUN=1
        log_info "Dry-run mode enabled"
        ;;
      -y | --yes)
        YES=1
        log_info "Automatic confirmation enabled"
        ;;
      --verbose)
        VERBOSE=true
        log_info "Verbose logging enabled"
        ;;
      -h | --help)
        show_help
        safe_exit $EXIT_SUCCESS
        ;;
      -v | --version)
        show_version
        safe_exit $EXIT_SUCCESS
        ;;
      *)
        log_error "Unknown flag: $arg"
        echo "Unknown flag: $arg" >&2
        echo "Use --help for usage information"
        safe_exit $EXIT_VALIDATION_ERROR
        ;;
    esac
  done
}

# Legacy function maintained for compatibility, but enhanced with logging
maybe_rm() {
  local path="$1"
  local description="${2:-$path}"

  log_debug "maybe_rm called for: $path"
  if [[ -e $path ]]; then
    atomic_remove "$path" "$description"
  else
    log_debug "Path does not exist, skipping: $path"
  fi
}

confirm() {
  log_info "Requesting user confirmation for uninstallation"
  if [[ $YES -eq 1 ]]; then
    log_info "Auto-confirmation enabled, proceeding"
    return 0
  fi

  echo
  print_status $YELLOW "⚠️  This will remove security controls from this repository."
  echo "   The following will be removed:"
  echo "   • Git hooks (pre-push)"
  echo "   • GitHub workflows"
  echo "   • Security controls directory"
  echo "   • Configuration files"
  echo "   • Documentation"
  echo

  read -r -p "Continue? (y/N): " ans
  if [[ $ans =~ ^[Yy]$ ]]; then
    log_info "User confirmed uninstallation"
    return 0
  else
    log_info "User cancelled uninstallation"
    return 1
  fi
}

# Check if we're in a git repository
check_git_repository() {
  log_info "Checking if current directory is a Git repository"
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    log_error "Not in a Git repository"
    print_status $RED "❌ Not in a Git repository"
    echo "Please run this script from within a Git repository that has security controls installed."
    safe_exit $EXIT_CONFIG_ERROR
  fi
  log_info "Git repository detected"
}

# Remove Git hooks with safety checks
remove_git_hooks() {
  log_info "Removing Git hooks"
  print_status $BLUE "🪝 Removing Git hooks..."

  if [[ -f .git/hooks/pre-push ]]; then
    if grep -q "Security Controls Installer" .git/hooks/pre-push 2>/dev/null; then
      log_info "Found installer-generated pre-push hook"
      maybe_rm .git/hooks/pre-push "Git pre-push hook"
    else
      log_warn "Pre-push hook exists but was not generated by installer"
      print_status $YELLOW "⚠️  Skipping .git/hooks/pre-push (not generated by installer)"
    fi
  else
    log_debug "No pre-push hook found"
  fi

  # Remove hooksPath dispatcher and chained hook
  if [[ -d .githooks/pre-push.d ]]; then
    log_info "Checking .githooks/pre-push.d directory"
    for f in .githooks/pre-push.d/*security-pre-push; do
      if [[ -e $f ]]; then
        log_info "Found security pre-push hook: $f"
        maybe_rm "$f" "Security pre-push hook"
      fi
    done
  fi

  if [[ -f .githooks/pre-push ]]; then
    log_info "Hooks dispatcher retained at .githooks/pre-push"
    print_status $BLUE "📝 Note: hooksPath dispatcher retained at .githooks/pre-push"
  fi
}

# Remove GitHub workflows
remove_github_workflows() {
  log_info "Removing GitHub workflows"
  print_status $BLUE "⚙️  Removing GitHub workflows..."

  maybe_rm .github/workflows/security.yml "Security workflow"
  maybe_rm .github/workflows/pinning-validation.yml "Pinning validation workflow"

  # Check for other workflows that might have been installed
  if [[ -f .github/workflows/codeql.yml ]]; then
    if grep -q "1-click-github-sec" .github/workflows/codeql.yml 2>/dev/null; then
      maybe_rm .github/workflows/codeql.yml "CodeQL workflow"
    fi
  fi
}

# Remove configuration and state files
remove_configuration() {
  log_info "Removing configuration and state files"
  print_status $BLUE "📁 Removing configuration files..."

  maybe_rm .security-controls "Security controls directory"
  maybe_rm .security-controls-version "Version file"

  # Remove any backup configuration files
  maybe_rm .git-config-backup "Git configuration backup"
  maybe_rm .gitsign-config "Gitsign configuration"
}

# Remove documentation
remove_documentation() {
  log_info "Removing documentation"
  print_status $BLUE "📝 Removing documentation..."

  maybe_rm docs/security "Security documentation"
}

# Display summary of what was removed
show_removal_summary() {
  log_info "Displaying removal summary"
  print_status $GREEN "✅ Uninstall completed successfully!"

  if [[ ${#REMOVED_FILES[@]} -gt 0 ]]; then
    echo
    print_status $BLUE "📋 Summary of removed items:"
    for file in "${REMOVED_FILES[@]}"; do
      echo "   ✓ $file"
    done
  fi

  echo
  print_status $YELLOW "💡 Notes:"
  echo "   • All operations were logged to: $LOG_FILE"
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "   • This was a dry run - no files were actually removed"
  else
    echo "   • Backups were created in /tmp for safety"
  fi
}

main() {
  log_info "Starting Security Controls Uninstaller v$SCRIPT_VERSION"
  print_header "$SCRIPT_NAME v$SCRIPT_VERSION"

  # Parse command line arguments
  parse_arguments "$@"

  # Check prerequisites
  check_git_repository

  # Get user confirmation
  if ! confirm; then
    log_info "User aborted uninstallation"
    print_status $YELLOW "Uninstallation aborted by user."
    safe_exit $EXIT_SUCCESS
  fi

  # Begin uninstallation process
  log_info "Beginning uninstallation process"
  print_status $BLUE "🚀 Starting uninstallation process..."

  # Remove components in logical order
  remove_git_hooks
  remove_github_workflows
  remove_configuration
  remove_documentation

  # Show summary
  show_removal_summary

  log_info "Uninstallation completed successfully"
  safe_exit $EXIT_SUCCESS
}

# Initialize and run main function
if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
  main "$@"
fi
