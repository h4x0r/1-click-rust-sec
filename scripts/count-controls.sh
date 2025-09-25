#!/usr/bin/env bash
# count-controls.sh - Audit actual security control implementation counts
# Part of 1-Click GitHub Security Documentation Synchronization Framework
#
# Usage: ./scripts/count-controls.sh
#
# Prevents marketing claim drift by counting actual implemented security controls

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
🔍 Security Control Counter

USAGE:
    $0 [OPTIONS]

DESCRIPTION:
    Audits the actual number of security controls implemented in the installer
    and compares against marketing claims in documentation. Prevents drift
    between actual implementation and claimed capabilities.

    Counts controls in:
    - Pre-push hook security checks
    - Helper tools (pinactlite, gitleakslite)
    - CI/CD workflow controls
    - GitHub security features

OPTIONS:
    --detailed      Show detailed breakdown by category
    --help          Show this help message

OUTPUT:
    - Total control count
    - Category breakdown
    - Marketing claim verification
    - Inconsistency detection

EXAMPLES:
    $0                 # Quick count and verification
    $0 --detailed      # Detailed breakdown by category

EOF
}

# Count pre-push hook security checks
count_prepush_controls() {
  local installer="$PROJECT_ROOT/$INSTALLER_SCRIPT"
  # Removed unused local variable

  if [[ ! -f "$installer" ]]; then
    log_error "Installer script not found: $installer"
    return 1
  fi

  log_info "Analyzing pre-push hook security controls..."

  # Count pattern-based security checks
  # Look for distinct security validation patterns in the installer

  # Critical blocking controls (print_status $RED)
  local critical_controls
  critical_controls=$(grep -c "print_status.*RED.*❌" "$installer" 2>/dev/null || echo "0")

  # Warning controls (print_status $YELLOW)
  local warning_controls
  warning_controls=$(grep -c "print_status.*YELLOW.*⚠️" "$installer" 2>/dev/null || echo "0")

  # Security scanning phases
  local security_phases
  security_phases=$(grep -c "# PHASE [0-9]" "$installer" 2>/dev/null || echo "0")

  # Distinct security check comments
  local security_checks
  security_checks=$(grep -c "# [0-9][0-9]*\." "$installer" 2>/dev/null || echo "0")

  # Language-specific security tools
  local rust_tools
  rust_tools=$(grep -c "cargo-\(deny\|audit\|geiger\|machete\|fmt\|clippy\|test\)" "$installer" 2>/dev/null || echo "0")

  local nodejs_tools
  nodejs_tools=$(grep -c "\(npm audit\|eslint\|prettier\|snyk\|retire\)" "$installer" 2>/dev/null || echo "0")

  local python_tools
  python_tools=$(grep -c "\(safety\|bandit\|black\|flake8\|pip-audit\)" "$installer" 2>/dev/null || echo "0")

  local go_tools
  go_tools=$(grep -c "\(govulncheck\|gofmt\|golint\)" "$installer" 2>/dev/null || echo "0")

  # Universal security controls
  local universal_controls
  universal_controls=$(grep -c "\(gitleaks\|pinactlite\|CodeQL\)" "$installer" 2>/dev/null || echo "0")

  # Calculate estimated total
  local estimated_total=$((security_checks + rust_tools + nodejs_tools + python_tools + go_tools + universal_controls))

  echo "  📊 Pre-push Security Controls Analysis:"
  echo "    • Distinct security checks: $security_checks"
  echo "    • Critical blocking controls: $critical_controls"
  echo "    • Warning controls: $warning_controls"
  echo "    • Security phases: $security_phases"
  echo "    • Rust security tools: $rust_tools"
  echo "    • Node.js security tools: $nodejs_tools"
  echo "    • Python security tools: $python_tools"
  echo "    • Go security tools: $go_tools"
  echo "    • Universal controls: $universal_controls"
  echo "    📈 Estimated total pre-push controls: ~$estimated_total"

  echo "$estimated_total"
}

# Count helper tools
count_helper_tools() {
  log_info "Counting helper tools..."

  local tools=0

  # Check for pinactlite references
  if grep -q "pinactlite" "$PROJECT_ROOT/$INSTALLER_SCRIPT"; then
    ((tools++))
    echo "  ✅ pinactlite - GitHub Actions SHA pinning"
  fi

  # Check for gitleakslite references
  if grep -q "gitleakslite" "$PROJECT_ROOT/$INSTALLER_SCRIPT"; then
    ((tools++))
    echo "  ✅ gitleakslite - Secret detection"
  fi

  echo "    📈 Helper tools total: $tools"
  echo "$tools"
}

# Count CI/CD workflow controls
count_cicd_controls() {
  log_info "Counting CI/CD workflow controls..."

  local workflow_count
  workflow_count=$(find "$PROJECT_ROOT/.github/workflows" -name "*.yml" | wc -l | tr -d ' ')

  echo "  📊 CI/CD Workflows:"
  find "$PROJECT_ROOT/.github/workflows" -name "*.yml" -exec basename {} \; | sed 's/^/    • /'
  echo "    📈 Workflow total: $workflow_count"

  echo "$workflow_count"
}

# Count GitHub security features
count_github_features() {
  log_info "Counting GitHub security features..."

  local features=0
  local installer="$PROJECT_ROOT/$INSTALLER_SCRIPT"

  # Count GitHub security features mentioned in installer
  if grep -q "Dependabot.*vulnerability.*alerts" "$installer"; then
    ((features++))
    echo "  ✅ Dependabot vulnerability alerts"
  fi

  if grep -q "Dependabot.*security.*fixes" "$installer"; then
    ((features++))
    echo "  ✅ Dependabot automated security fixes"
  fi

  if grep -q "CodeQL" "$installer"; then
    ((features++))
    echo "  ✅ CodeQL security scanning"
  fi

  if grep -q "Branch protection" "$installer"; then
    ((features++))
    echo "  ✅ Branch protection rules"
  fi

  if grep -q "Secret.*scanning" "$installer"; then
    ((features++))
    echo "  ✅ Secret scanning"
  fi

  if grep -q "Push protection" "$installer"; then
    ((features++))
    echo "  ✅ Secret push protection"
  fi

  echo "    📈 GitHub features total: $features"
  echo "$features"
}

# Check marketing claims in documentation
check_marketing_claims() {
  local actual_total="$1"

  log_info "Verifying marketing claims..."

  # Check README.md badges
  local readme_claim=""
  if [[ -f "$PROJECT_ROOT/README.md" ]]; then
    readme_claim=$(grep -o "Installer%20Provides-[0-9]\+%2B%20Controls" README.md | head -1 | grep -o "[0-9]\+" || echo "0")
    echo "  📄 README.md claims: ${readme_claim}+ controls"
  fi

  # Check installer help message
  local help_claim=""
  if grep -q "35+ checks" "$PROJECT_ROOT/$INSTALLER_SCRIPT"; then
    help_claim="35"
    echo "  💡 Installer help claims: ${help_claim}+ checks"
  fi

  # Verification
  echo
  log_info "📊 Verification Results:"
  echo "  🎯 Actual implementation: ~$actual_total controls"
  echo "  📢 README.md marketing: ${readme_claim}+ controls"
  echo "  💬 Installer help: ${help_claim}+ checks"

  # Check for discrepancies
  if [[ -n "$readme_claim" && $actual_total -lt $readme_claim ]]; then
    log_warning "⚠️  Actual count ($actual_total) is below README claim (${readme_claim}+)"
    echo "    Action needed: Update README badge or add more controls"
  elif [[ -n "$readme_claim" && $actual_total -ge $readme_claim ]]; then
    log_success "✅ README claim verified: $actual_total ≥ ${readme_claim}+"
  fi

  if [[ -n "$help_claim" && $actual_total -lt $help_claim ]]; then
    log_warning "⚠️  Actual count ($actual_total) is below help claim (${help_claim}+)"
    echo "    Action needed: Update installer help or add more controls"
  elif [[ -n "$help_claim" && $actual_total -ge $help_claim ]]; then
    log_success "✅ Installer help claim verified: $actual_total ≥ ${help_claim}+"
  fi
}

# Main counting function
main() {
  cd "$PROJECT_ROOT"

  case "${1:-}" in
    --help|-h)
      show_usage
      exit 0
      ;;
    --detailed)
      local detailed=true
      ;;
    *)
      local detailed=false
      ;;
  esac

  echo "🔍 1-Click GitHub Security Control Audit"
  echo "========================================"
  echo

  # Count each category
  local prepush_count
  prepush_count=$(count_prepush_controls)
  echo

  local helper_count
  helper_count=$(count_helper_tools)
  echo

  local cicd_count
  cicd_count=$(count_cicd_controls)
  echo

  local github_count
  github_count=$(count_github_features)
  echo

  # Calculate total
  local total_count=$((prepush_count + helper_count + cicd_count + github_count))

  # Summary
  echo "📊 SECURITY CONTROL SUMMARY"
  echo "============================"
  echo "Pre-push controls:    ~$prepush_count"
  echo "Helper tools:          $helper_count"
  echo "CI/CD workflows:       $cicd_count"
  echo "GitHub features:       $github_count"
  echo "―――――――――――――――――――――――――"
  echo "TOTAL CONTROLS:       ~$total_count"
  echo

  # Marketing verification
  check_marketing_claims "$total_count"

  echo
  log_success "🎯 Security control audit complete!"

  if [[ "$detailed" == true ]]; then
    echo
    echo "💡 For detailed implementation analysis:"
    echo "   grep -n 'print_status.*❌\\|⚠️' $INSTALLER_SCRIPT"
    echo "   grep -n 'cargo-\\|npm \\|safety\\|govulncheck' $INSTALLER_SCRIPT"
  fi
}

# Execute main function
main "$@"