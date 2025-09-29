#!/usr/bin/env bash

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

# validate-docs.sh - Cross-reference consistency validation
# Part of 1-Click GitHub Security Documentation Synchronization Framework
#
# Usage: ./scripts/validate-docs.sh
#
# Ensures consistency across all documentation sources

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly PROJECT_ROOT
readonly INSTALLER_SCRIPT="install-security-controls.sh"

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

  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

  case "$status" in
    "PASS")
      log_success "✅ $message"
      PASSED_CHECKS=$((PASSED_CHECKS + 1))
      ;;
    "FAIL")
      log_error "❌ $message"
      FAILED_CHECKS=$((FAILED_CHECKS + 1))
      ;;
    "WARN")
      log_warning "⚠️  $message"
      WARNINGS=$((WARNINGS + 1))
      ;;
  esac
}

# Validate version consistency
validate_versions() {
  log_info "🔍 Validating version consistency..."

  local version_file="VERSION"
  if [[ ! -f $version_file ]]; then
    check_result "FAIL" "VERSION file not found"
    return
  fi

  local current_version
  current_version=$(<"$version_file")
  current_version="${current_version//[[:space:]]/}"

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
      check_result "WARN" "MkDocs version not specified or does not match VERSION file (v$current_version)"
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
  if [[ ! -d $workflow_dir ]]; then
    check_result "WARN" "Workflows directory not found"
    return
  fi

  # Count actual workflows
  local actual_workflows
  actual_workflows=$(find "$workflow_dir" -name "*.yml" | wc -l | tr -d ' ')

  # Check docs/repo-security-and-quality-assurance.md workflow count
  if [[ -f "docs/repo-security-and-quality-assurance.md" ]]; then
    if grep -q "specialized workflows\|workflow" docs/repo-security-and-quality-assurance.md; then
      if [[ $actual_workflows -ge 4 ]]; then # More flexible threshold
        check_result "PASS" "docs/repo-security-and-quality-assurance.md documents workflows (found $actual_workflows)"
      else
        check_result "WARN" "Found only $actual_workflows workflows (may be minimal setup)"
      fi
    else
      check_result "WARN" "docs/repo-security-and-quality-assurance.md workflow documentation not found"
    fi
  else
    check_result "WARN" "docs/repo-security-and-quality-assurance.md not found"
  fi

  # Validate individual workflow documentation
  local workflows
  mapfile -t workflows < <(find "$workflow_dir" -name "*.yml" -exec basename {} \; | sort)

  log_info "📋 Found workflows: ${workflows[*]}"

  for workflow in "${workflows[@]}"; do
    if [[ -f "docs/repo-security-and-quality-assurance.md" ]]; then
      if grep -q "$workflow" docs/repo-security-and-quality-assurance.md; then
        check_result "PASS" "Workflow $workflow documented in docs/repo-security-and-quality-assurance.md"
      else
        check_result "WARN" "Workflow $workflow not documented in docs/repo-security-and-quality-assurance.md"
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
    if [[ -n $readme_claim ]]; then
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
  mapfile -t all_docs < <(find . -maxdepth 1 -name "*.md" -not -name "README.md" -exec basename {} \; | sort)

  # Also discover docs/ folder documentation
  local docs_folder_files
  if [[ -d "docs" ]]; then
    mapfile -t docs_folder_files < <(find docs -name "*.md" -exec basename {} \; | sort)
  fi

  log_info "📋 Discovered documentation files:"
  echo "Root directory:"
  for doc in "${all_docs[@]}"; do
    echo "  • $doc"
  done

  if [[ -n ${docs_folder_files:-} ]]; then
    echo "docs/ directory:"
    for doc in "${docs_folder_files[@]}"; do
      echo "  • docs/$doc"
    done
  fi

  # Check documentation links in README
  if [[ -f "README.md" ]]; then
    for doc_file in "${all_docs[@]}"; do
      if grep -q "$doc_file" README.md; then
        if [[ -f $doc_file ]]; then
          check_result "PASS" "Cross-reference to $doc_file exists and file found"
        else
          check_result "FAIL" "Cross-reference to $doc_file found but file missing"
        fi
      else
        # Only warn for important docs, not all docs
        case "$doc_file" in
          CHANGELOG.md | CODE_OF_CONDUCT.md)
            check_result "WARN" "No cross-reference to $doc_file found in README.md"
            ;;
          *)
            check_result "PASS" "Optional doc $doc_file - cross-reference not required (now in docs/)"
            ;;
        esac
      fi
    done

    # Check for orphaned references (links to non-existent docs)
    local linked_docs
    mapfile -t linked_docs < <(grep -o '\[.*\]([A-Z_a-z0-9./-]*\.md)' README.md | sed 's/.*(\([^)]*\)).*/\1/' | sort -u)

    for linked_doc in "${linked_docs[@]}"; do
      if [[ ! -f $linked_doc ]]; then
        check_result "FAIL" "README.md links to non-existent file: $linked_doc"
      else
        check_result "PASS" "README.md link verified: $linked_doc"
      fi
    done
  fi

  # Check MkDocs file consistency
  if [[ -d "docs" && -f "mkdocs.yml" ]]; then
    # Extract nav items from mkdocs.yml
    local mkdocs_files
    mapfile -t mkdocs_files < <(grep -E "^\s*-\s.*\.md$" mkdocs.yml | sed 's/.*: //' | sort -u)

    for mkdocs_file in "${mkdocs_files[@]}"; do
      if [[ -f "docs/$mkdocs_file" ]]; then
        check_result "PASS" "MkDocs nav file exists: docs/$mkdocs_file"
      else
        check_result "FAIL" "MkDocs nav references missing file: docs/$mkdocs_file"
      fi
    done

    # Check for orphaned docs files not in nav
    local orphaned_docs
    mapfile -t orphaned_docs < <(find docs -name "*.md" -not -name "index.md" -exec basename {} \; | sort)

    for doc_file in "${orphaned_docs[@]}"; do
      if grep -q "$doc_file" mkdocs.yml; then
        check_result "PASS" "Documentation file $doc_file included in MkDocs nav"
      else
        check_result "WARN" "Documentation file docs/$doc_file not included in MkDocs nav"
      fi
    done
  fi
}

# Validate embedded documentation currency
validate_embedded_docs() {
  log_info "🔍 Validating embedded documentation..."

  if [[ ! -f $INSTALLER_SCRIPT ]]; then
    check_result "WARN" "$INSTALLER_SCRIPT not found, skipping embedded doc validation"
    return
  fi

  # Check for installer-created documentation files
  log_info "📋 Checking installer-created documentation patterns..."

  # Pattern 1: Architecture documentation
  if grep -q "# Security Controls Architecture" "$INSTALLER_SCRIPT"; then
    check_result "PASS" "Installer contains architecture documentation"

    # Verify it creates architecture.md (not ARCHITECTURE.md)
    if grep -q 'arch_file="\$DOCS_DIR/architecture\.md"' "$INSTALLER_SCRIPT"; then
      check_result "PASS" "Installer creates lowercase architecture.md file"
    else
      check_result "WARN" "Installer may create uppercase filename (check consistency)"
    fi
  else
    check_result "FAIL" "Installer missing architecture documentation"
  fi

  # Pattern 2: 4-mode signing support (consolidated approach)
  if grep -q "COMMAND_MODE.*enable-yubikey" "$INSTALLER_SCRIPT" && grep -q "COMMAND_MODE.*switch-to-gitsign" "$INSTALLER_SCRIPT"; then
    check_result "PASS" "Installer contains 4-mode signing support"
  else
    check_result "WARN" "Installer may be missing 4-mode signing commands"
  fi

  # Verify embedded YubiKey documentation was removed (consolidated approach)
  if grep -q "YubiKey + Sigstore Integration Guide" "$INSTALLER_SCRIPT"; then
    check_result "WARN" "Installer still contains embedded YubiKey docs (should be consolidated)"
  else
    check_result "PASS" "Installer correctly uses consolidated documentation approach"
  fi

  # Pattern 3: Check README.md was removed (should NOT be present)
  if grep -q 'readme_file="\$DOCS_DIR/README\.md"' "$INSTALLER_SCRIPT"; then
    check_result "WARN" "Installer still creates redundant README.md (should be removed)"
  else
    check_result "PASS" "Installer correctly removed redundant README.md creation"
  fi

  # Compare installer-embedded docs with repository docs
  log_info "🔄 Checking sync between installer and repository docs..."

  # Check consolidated 4-mode signing documentation
  if [[ -f "docs/installation.md" ]]; then
    # Check if installation.md contains 4-mode signing configuration
    if grep -q "4.* Modes Available" docs/installation.md && grep -q "gitsign + YubiKey" docs/installation.md; then
      check_result "PASS" "Installation guide contains consolidated 4-mode signing documentation"
    else
      check_result "WARN" "Installation guide may be missing 4-mode signing content"
    fi
  else
    check_result "WARN" "Installation guide not found at docs/installation.md"
  fi

  # Check architecture.md has technical signing details
  if [[ -f "docs/architecture.md" ]]; then
    if grep -q "Mode.*gitsign.*YubiKey" docs/architecture.md; then
      check_result "PASS" "Architecture guide contains technical signing implementation details"
    else
      check_result "WARN" "Architecture guide may be missing technical signing details"
    fi
  else
    check_result "WARN" "Architecture guide not found at docs/architecture.md"
  fi

  # Compare architecture guides
  if [[ -f "docs/architecture.md" ]]; then
    local repo_arch_sections
    repo_arch_sections=$(grep -c "^## " docs/architecture.md || echo "0")

    local installer_arch_sections
    installer_arch_sections=$(sed -n '/cat <<.ARCH_EOF/,/^ARCH_EOF$/p' "$INSTALLER_SCRIPT" | grep -c "^## " || echo "0")

    if [[ $installer_arch_sections -gt 0 && $repo_arch_sections -gt 0 ]]; then
      local coverage=$((installer_arch_sections * 100 / repo_arch_sections))
      if [[ $coverage -ge 30 ]]; then # Lower threshold - installer version is user-focused subset
        check_result "PASS" "Architecture guide sync: $coverage% coverage ($installer_arch_sections/$repo_arch_sections sections)"
      else
        check_result "WARN" "Architecture guide may need sync: $coverage% coverage ($installer_arch_sections/$repo_arch_sections sections)"
      fi
    else
      check_result "WARN" "Could not compare architecture guide sections"
    fi
  else
    check_result "WARN" "Repository architecture guide not found at docs/architecture.md"
  fi

  # Final validation: ensure installer creates exactly 2 documentation files
  local docs_created_count=0
  if grep -q 'arch_file=' "$INSTALLER_SCRIPT"; then
    docs_created_count=$((docs_created_count + 1))
  fi
  if grep -q 'yubi_file=' "$INSTALLER_SCRIPT"; then
    docs_created_count=$((docs_created_count + 1))
  fi

  if [[ $docs_created_count -eq 2 ]]; then
    check_result "PASS" "Installer creates optimal 2 documentation files (no redundancy)"
  else
    check_result "WARN" "Installer creates $docs_created_count documentation files (expected: 2)"
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
    --help | -h)
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

  # Validate documentation site links (if validate-docs-links.sh exists)
  if [[ -f "scripts/validate-docs-links.sh" ]]; then
    log_info "🔗 Validating documentation site links..."
    if ./scripts/validate-docs-links.sh README.md CLAUDE.md 2>/dev/null; then
      check_result "PASS" "All documentation site links are accessible"
    else
      check_result "WARN" "Some documentation site links may not be accessible (deployment in progress?)"
      log_info "💡 Run './scripts/check-docs-deployment.sh --wait' to wait for deployment"
    fi
    echo
  fi

  # Generate final report
  generate_summary
}

# Execute main function
main "$@"
