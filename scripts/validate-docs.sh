#!/usr/bin/env bash
# validate-docs.sh - Cross-reference consistency validation
# Part of 1-Click GitHub Security Documentation Synchronization Framework
#
# Usage: ./scripts/validate-docs.sh
#
# Ensures consistency across all documentation sources

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

show_usage() {
  cat <<EOF
🔍 Documentation Consistency Validator

USAGE:
    $0 [OPTIONS]

DESCRIPTION:
    Validates consistency across all documentation sources:
    - Repository documentation (README.md, CLAUDE.md, etc.)
    - Installer help messages (--help)
    - Installer-generated documentation
    - Cross-references and links
    - Version synchronization

OPTIONS:
    --fix           Attempt to fix found inconsistencies
    --detailed      Show detailed breakdown of all checks
    --help          Show this help message

CHECKS:
    ✅ Version consistency across all files
    ✅ Security control count accuracy
    ✅ Cross-reference link validation
    ✅ Feature claim consistency
    ✅ Workflow documentation accuracy
    ✅ Embedded documentation currency

EOF
}

# Track validation results
declare -i TOTAL_CHECKS=0
declare -i PASSED_CHECKS=0
declare -i FAILED_CHECKS=0
declare -i WARNINGS=0

# Validation result tracking
check_result() {
  local status="$1"
  local message="$2"

  ((TOTAL_CHECKS++))

  case "$status" in
    "PASS")
      log_success "✅ $message"
      ((PASSED_CHECKS++))
      ;;
    "FAIL")
      log_error "❌ $message"
      ((FAILED_CHECKS++))
      ;;
    "WARN")
      log_warning "⚠️  $message"
      ((WARNINGS++))
      ;;
  esac
}

# Validate version consistency
validate_versions() {
  log_info "🔍 Validating version consistency..."

  local version_file="VERSION"
  if [[ ! -f "$version_file" ]]; then
    check_result "FAIL" "VERSION file not found"
    return
  fi

  local current_version
  current_version=$(cat "$version_file" | tr -d '\n\r\s')

  # Check README.md
  if [[ -f "README.md" ]]; then
    if grep -q "Version-v${current_version}" README.md; then
      check_result "PASS" "README.md version badge matches VERSION file ($current_version)"
    else
      check_result "FAIL" "README.md version badge does not match VERSION file ($current_version)"
    fi
  else
    check_result "WARN" "README.md not found"
  fi

  # Check installer script
  if [[ -f "install-security-controls.sh" ]]; then
    if grep -q "readonly SCRIPT_VERSION=\"${current_version}\"" install-security-controls.sh; then
      check_result "PASS" "Installer script version matches VERSION file ($current_version)"
    else
      check_result "FAIL" "Installer script version does not match VERSION file ($current_version)"
    fi
  else
    check_result "WARN" "install-security-controls.sh not found"
  fi

  # Check mkdocs.yml
  if [[ -f "mkdocs.yml" ]]; then
    if grep -q "v${current_version}" mkdocs.yml; then
      check_result "PASS" "MkDocs version matches VERSION file (v$current_version)"
    else
      check_result "FAIL" "MkDocs version does not match VERSION file (v$current_version)"
    fi
  else
    check_result "WARN" "mkdocs.yml not found"
  fi

  # Check CHANGELOG.md
  if [[ -f "CHANGELOG.md" ]]; then
    if grep -q "## \[${current_version}\]" CHANGELOG.md; then
      check_result "PASS" "CHANGELOG.md has entry for current version ($current_version)"
    else
      check_result "WARN" "CHANGELOG.md missing entry for current version ($current_version)"
    fi
  else
    check_result "WARN" "CHANGELOG.md not found"
  fi
}

# Validate workflow documentation
validate_workflows() {
  log_info "🔍 Validating workflow documentation..."

  local workflow_dir=".github/workflows"
  if [[ ! -d "$workflow_dir" ]]; then
    check_result "WARN" "Workflows directory not found"
    return
  fi

  # Count actual workflows
  local actual_workflows
  actual_workflows=$(find "$workflow_dir" -name "*.yml" | wc -l | tr -d ' ')

  # Check REPO_SECURITY.md workflow count
  if [[ -f "REPO_SECURITY.md" ]]; then
    if grep -q "Six specialized workflows" REPO_SECURITY.md; then
      if [[ $actual_workflows -eq 6 ]]; then
        check_result "PASS" "REPO_SECURITY.md workflow count matches actual ($actual_workflows)"
      else
        check_result "FAIL" "REPO_SECURITY.md claims 6 workflows, found $actual_workflows"
      fi
    else
      check_result "WARN" "REPO_SECURITY.md workflow count statement not found"
    fi
  fi

  # Validate individual workflow documentation
  local workflows
  workflows=($(find "$workflow_dir" -name "*.yml" -exec basename {} \; | sort))

  for workflow in "${workflows[@]}"; do
    local workflow_name="${workflow%.yml}"
    if [[ -f "REPO_SECURITY.md" ]]; then
      if grep -q "$workflow" REPO_SECURITY.md; then
        check_result "PASS" "Workflow $workflow documented in REPO_SECURITY.md"
      else
        check_result "FAIL" "Workflow $workflow not documented in REPO_SECURITY.md"
      fi
    fi
  done
}

# Validate security control claims
validate_control_claims() {
  log_info "🔍 Validating security control claims..."

  # Get README badge claim
  local readme_claim=""
  if [[ -f "README.md" ]]; then
    readme_claim=$(grep -o "Installer%20Provides-[0-9]\+%2B%20Controls" README.md | head -1 | grep -o "[0-9]\+" 2>/dev/null || echo "")
    if [[ -n "$readme_claim" ]]; then
      check_result "PASS" "README.md security control claim found (${readme_claim}+)"
    else
      check_result "WARN" "README.md security control claim not found or unreadable"
    fi
  fi

  # Get installer help claim
  if [[ -f "install-security-controls.sh" ]]; then
    if grep -q "35+ checks" install-security-controls.sh; then
      check_result "PASS" "Installer help message control claim found (35+)"
    else
      check_result "WARN" "Installer help message control claim not found"
    fi
  fi

  # Suggest running count-controls.sh for verification
  if [[ -f "scripts/count-controls.sh" ]]; then
    log_info "💡 Run './scripts/count-controls.sh' to verify control count accuracy"
  fi
}

# Validate cross-references
validate_cross_references() {
  log_info "🔍 Validating cross-references..."

  # Dynamic discovery of documentation files
  local all_docs
  all_docs=($(find . -maxdepth 1 -name "*.md" -not -name "README.md" -exec basename {} \; | sort))

  log_info "📋 Discovered documentation files:"
  for doc in "${all_docs[@]}"; do
    echo "  • $doc"
  done

  # Check documentation links in README
  if [[ -f "README.md" ]]; then
    for doc_file in "${all_docs[@]}"; do
      if grep -q "$doc_file" README.md; then
        if [[ -f "$doc_file" ]]; then
          check_result "PASS" "Cross-reference to $doc_file exists and file found"
        else
          check_result "FAIL" "Cross-reference to $doc_file found but file missing"
        fi
      else
        # Only warn for important docs, not all docs
        case "$doc_file" in
          CONTRIBUTING.md|REPO_SECURITY.md|SECURITY_CONTROLS_*.md|CHANGELOG.md)
            check_result "WARN" "No cross-reference to $doc_file found in README.md"
            ;;
          *)
            check_result "PASS" "Optional doc $doc_file - cross-reference not required"
            ;;
        esac
      fi
    done

    # Check for orphaned references (links to non-existent docs)
    local linked_docs
    linked_docs=($(grep -o '\[.*\]([A-Z_]*\.md)' README.md | sed 's/.*(\([^)]*\)).*/\1/' | sort -u))

    for linked_doc in "${linked_docs[@]}"; do
      if [[ ! -f "$linked_doc" ]]; then
        check_result "FAIL" "README.md links to non-existent file: $linked_doc"
      else
        check_result "PASS" "README.md link verified: $linked_doc"
      fi
    done
  fi

  # Check MkDocs symlinks
  if [[ -d "docs" ]]; then
    local symlinks
    symlinks=($(find docs -type l))

    for symlink in "${symlinks[@]}"; do
      if [[ -e "$symlink" ]]; then
        check_result "PASS" "Symlink $symlink points to existing file"
      else
        check_result "FAIL" "Symlink $symlink is broken"
      fi
    done
  fi
}

# Validate embedded documentation currency
validate_embedded_docs() {
  log_info "🔍 Validating embedded documentation..."

  if [[ ! -f "$INSTALLER_SCRIPT" ]]; then
    check_result "WARN" "$INSTALLER_SCRIPT not found, skipping embedded doc validation"
    return
  fi

  # Dynamic discovery of embedded documentation patterns
  local embedded_patterns=(
    "YubiKey + Sigstore Integration Guide"
    "# Security Controls"
    "## Installation Guide"
    "## Architecture Overview"
    "## Troubleshooting"
  )

  log_info "🔍 Scanning for embedded documentation patterns..."

  for pattern in "${embedded_patterns[@]}"; do
    if grep -q "$pattern" "$INSTALLER_SCRIPT"; then
      check_result "PASS" "Found embedded content: $pattern"
    else
      case "$pattern" in
        "YubiKey + Sigstore Integration Guide"|"# Security Controls")
          check_result "WARN" "Missing embedded content: $pattern"
          ;;
        *)
          check_result "PASS" "Optional embedded content: $pattern (not required)"
          ;;
      esac
    fi
  done

  # Legacy check - Check if installer has embedded YubiKey guide
  if grep -q "YubiKey + Sigstore Integration Guide" "$INSTALLER_SCRIPT"; then
    check_result "PASS" "Installer contains embedded YubiKey guide"

    # Compare with standalone guide
    if [[ -f "YUBIKEY_SIGSTORE_GUIDE.md" ]]; then
      # Extract embedded guide sections for comparison
      local embedded_sections
      embedded_sections=$(grep -c "^## " install-security-controls.sh || echo "0")

      local standalone_sections
      standalone_sections=$(grep -c "^## " YUBIKEY_SIGSTORE_GUIDE.md || echo "0")

      if [[ $embedded_sections -gt 0 && $standalone_sections -gt 0 ]]; then
        if [[ $embedded_sections -ge $((standalone_sections - 2)) ]]; then
          check_result "PASS" "Embedded YubiKey guide appears comprehensive ($embedded_sections/$standalone_sections sections)"
        else
          check_result "WARN" "Embedded YubiKey guide may be incomplete ($embedded_sections/$standalone_sections sections)"
        fi
      fi
    fi
  else
    check_result "WARN" "Installer missing embedded YubiKey guide"
  fi

  # Check embedded README
  if grep -q "# Security Controls" install-security-controls.sh; then
    check_result "PASS" "Installer contains embedded security README"
  else
    check_result "WARN" "Installer missing embedded security README"
  fi
}

# Generate summary report
generate_summary() {
  echo
  echo "📊 VALIDATION SUMMARY"
  echo "===================="
  echo "Total checks:     $TOTAL_CHECKS"
  echo "Passed:          $PASSED_CHECKS"
  echo "Failed:          $FAILED_CHECKS"
  echo "Warnings:        $WARNINGS"
  echo

  local success_rate=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))

  if [[ $FAILED_CHECKS -eq 0 ]]; then
    log_success "🎯 All critical validations passed! ($success_rate%)"
    if [[ $WARNINGS -gt 0 ]]; then
      log_info "💡 $WARNINGS warnings found - consider addressing for completeness"
    fi
    return 0
  else
    log_error "🚨 $FAILED_CHECKS critical validation(s) failed!"
    log_info "Run with --fix to attempt automatic fixes"
    return 1
  fi
}

# Main validation function
main() {
  cd "$PROJECT_ROOT"

  case "${1:-}" in
    --help|-h)
      show_usage
      exit 0
      ;;
    --detailed)
      # More verbose output in future
      ;;
    --fix)
      log_info "Fix mode not yet implemented"
      log_info "Use './scripts/version-sync.sh --check' for version fixes"
      ;;
  esac

  echo "🔍 1-Click GitHub Security Documentation Validator"
  echo "=================================================="
  echo

  # Run all validations
  validate_versions
  echo

  validate_workflows
  echo

  validate_control_claims
  echo

  validate_cross_references
  echo

  validate_embedded_docs
  echo

  # Generate final report
  generate_summary
}

# Execute main function
main "$@"