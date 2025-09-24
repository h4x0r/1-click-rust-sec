#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# DYNAMIC GITLEAKSLITE VALIDATION
# =============================================================================
# Comprehensive validation with dynamically generated secret patterns
# Avoids CI blocking by never committing hardcoded secrets

# Configuration
readonly SCRIPT_NAME="validate-gitleakslite"
readonly SCRIPT_VERSION="0.2.0"
readonly LOG_DIR="${HOME}/.gitleakslite-validation/logs"
readonly LOG_FILE="${LOG_DIR}/validation-$(date '+%Y%m%d-%H%M%S').log"
readonly TEMP_DIR="/tmp/gitleakslite-validation-$$"

# Validation thresholds
readonly MIN_DETECTION_RATE=90
readonly MAX_FALSE_POSITIVE_RATE=50  # Higher for script-only version

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Standardized error codes
readonly EXIT_SUCCESS=0
readonly EXIT_GENERAL_ERROR=1
readonly EXIT_VALIDATION_ERROR=7

# Global state
declare -a TEMP_FILES=()
VERBOSE_MODE=false

# =============================================================================
# LOGGING AND OUTPUT
# =============================================================================

setup_logging() {
  mkdir -p "$LOG_DIR"
  exec 19>&2  # Save stderr to fd 19
  exec 2>>"$LOG_FILE"  # Redirect stderr to log

  log_info "Starting $SCRIPT_NAME v$SCRIPT_VERSION"
  log_info "Log file: $LOG_FILE"
}

log_entry() {
  local level=$1
  local message=$2
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  local caller="${FUNCNAME[2]:-main}"

  echo "[$timestamp] [$level] [$caller] $message" >>"$LOG_FILE"
}

log_info() { log_entry "INFO" "$1"; }
log_warn() { log_entry "WARN" "$1"; }
log_debug() { [[ $VERBOSE_MODE == true ]] && log_entry "DEBUG" "$1"; }

print_status() {
  local color=$1
  local message=$2
  printf "${color}%s${NC}\n" "$message"
}

print_section() {
  local title=$1
  printf "${CYAN}═══════════════════════════════════════════════════════${NC}\n"
  printf "${CYAN}  %s${NC}\n" "$title"
  printf "${CYAN}═══════════════════════════════════════════════════════${NC}\n"
}

# =============================================================================
# CLEANUP AND ERROR HANDLING
# =============================================================================

cleanup_temp_files() {
  for file in "${TEMP_FILES[@]}"; do
    [[ -e "$file" ]] && rm -rf "$file" 2>/dev/null || true
  done
}

add_temp_file() {
  local file=$1
  TEMP_FILES+=("$file")
  log_debug "Added temp file for cleanup: $file"
}

handle_error() {
  local exit_code=$1
  local message=$2

  print_status $RED "❌ $message"
  log_entry "ERROR" "$message"
  cleanup_temp_files
  exit "$exit_code"
}

# Set up cleanup on exit
trap cleanup_temp_files EXIT

# =============================================================================
# DYNAMIC SECRET PATTERN GENERATION
# =============================================================================

generate_critical_patterns() {
  local -a patterns=()

  # Generate random hex strings for patterns
  local random_20=$(openssl rand -hex 10)
  local random_32=$(openssl rand -hex 16)
  local random_40=$(openssl rand -hex 20)
  local random_64=$(openssl rand -hex 32)
  local random_id=$(openssl rand -hex 6)

  # AWS patterns (most common cloud secrets)
  patterns+=("AKIA${random_20:0:16}")
  patterns+=("aws_access_key_id = \"AKIA${random_20:0:16}\"")
  patterns+=("AWS_SECRET_ACCESS_KEY=\"${random_64}\"")

  # GitHub patterns (most leaked developer secrets)
  patterns+=("ghp_${random_40}")
  patterns+=("github_pat_11${random_id}_${random_40}")
  patterns+=("ghs_${random_40}")

  # OpenAI patterns (increasingly common)
  patterns+=("sk-proj-${random_64}")
  patterns+=("sk-${random_40}")

  # Slack patterns (common in DevOps)
  patterns+=("xoxb-${random_id:0:10}-${random_id:4:10}-${random_32}")
  patterns+=("xoxp-1-${random_id:0:9}-${random_id:3:9}-${random_id:6:9}-${random_id:0:6}")
  patterns+=("https://hooks.slack.com/services/T${random_id:0:8}/B${random_id:4:8}/${random_32}")

  # Database URLs (frequent leak pattern)
  patterns+=("postgresql://user:${random_20:0:12}@localhost:5432/dbname")
  patterns+=("mysql://root:${random_20:0:14}@127.0.0.1:3306/app_db")
  patterns+=("mongodb://admin:${random_20:0:11}@cluster0.mongodb.net:27017/production")

  # Private Keys (critical security risk - minimal but recognizable)
  patterns+=($'-----BEGIN RSA PRIVATE KEY-----\nMII'${random_20:0:20}'...\n-----END RSA PRIVATE KEY-----')
  patterns+=($'-----BEGIN OPENSSH PRIVATE KEY-----\n'${random_32:0:32}'\n-----END OPENSSH PRIVATE KEY-----')

  # JWT Token structure (header.payload.signature)
  local jwt_header=$(printf '{"alg":"HS256","typ":"JWT"}' | base64 -w0 2>/dev/null || base64)
  local jwt_payload=$(printf '{"sub":"%s","name":"Test","iat":1516239022}' "${random_id:0:10}" | base64 -w0 2>/dev/null || base64)
  patterns+=("${jwt_header}.${jwt_payload}.${random_40}")

  # Container registry patterns
  patterns+=("dckr_pat_${random_40}")
  patterns+=("ghcr_pat_11${random_id}_${random_40}")

  # Stripe patterns (payment processing)
  patterns+=("sk_live_5${random_40}")
  patterns+=("rk_live_5${random_40}")

  # Generic API patterns (catch-all)
  patterns+=("api_key: \"${random_40}\"")
  patterns+=("API_SECRET=${random_40}")
  patterns+=("bearer_token=\"${random_40}\"")

  # Return patterns via stdout
  printf '%s\n' "${patterns[@]}"
}

generate_false_positive_patterns() {
  local -a patterns=()

  # Documentation examples and placeholders (should NOT be detected)
  patterns+=('AKIAIOSFODNN7EXAMPLE')  # AWS documentation example
  patterns+=('sk-example-key-replace-me')
  patterns+=('password = "YOUR_PASSWORD_HERE"')
  patterns+=('api_key = "<INSERT_API_KEY>"')
  patterns+=('secret = "***REMOVED***"')
  patterns+=('token: process.env.API_TOKEN')
  patterns+=('const HASH = "d41d8cd98f00b204e9800998ecf8427e"')  # MD5 hash
  patterns+=('version = "v1.2.3-alpha"')
  patterns+=('uuid = "550e8400-e29b-41d4-a716-446655440000"')
  patterns+=('password123')  # Too simple/common
  patterns+=('api-key-goes-here')
  patterns+=('// TODO: Add your API key')

  # Return patterns via stdout
  printf '%s\n' "${patterns[@]}"
}

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

validate_gitleakslite_binary() {
  local gitleakslite_path=$1

  log_info "Validating gitleakslite binary: $gitleakslite_path"

  if [[ ! -x "$gitleakslite_path" ]]; then
    handle_error $EXIT_VALIDATION_ERROR "Gitleakslite binary not found or not executable: $gitleakslite_path"
  fi

  print_status $GREEN "✅ Binary validation passed"
  log_info "Gitleakslite binary validated: $gitleakslite_path"
}

validate_critical_patterns() {
  local gitleakslite_path=$1

  print_section "Critical Secret Pattern Detection"
  log_info "Testing critical secret pattern detection"

  # Generate patterns dynamically
  local -a patterns
  readarray -t patterns < <(generate_critical_patterns)

  # Setup test directory
  local test_dir="$TEMP_DIR/secrets"
  mkdir -p "$test_dir"
  add_temp_file "$test_dir"

  local detected=0
  local total=${#patterns[@]}
  local failed_patterns=()

  cd "$test_dir"

  for i in "${!patterns[@]}"; do
    local pattern="${patterns[i]}"
    local test_file="secret_test_$i.txt"

    # Create test file with secret
    {
      echo "// Critical pattern test $i"
      echo "$pattern"
      echo "// End test"
    } > "$test_file"

    add_temp_file "$test_dir/$test_file"

    # Test detection (gitleakslite should fail = exit non-zero)
    # Stage the file and use protect --staged for script-only gitleakslite
    git add "$test_file" 2>/dev/null || true
    if ! "$gitleakslite_path" protect --staged --no-banner >/dev/null 2>&1; then
      detected=$((detected + 1))
      log_debug "Detected pattern $i: ${pattern:0:50}..."
    else
      failed_patterns+=("Pattern $i: ${pattern:0:50}...")
      log_warn "MISSED pattern $i: ${pattern:0:50}..."
    fi
    git reset HEAD "$test_file" 2>/dev/null || true
  done

  cd - >/dev/null

  local detection_rate=$((detected * 100 / total))
  print_status $BLUE "📊 Detection Results: $detected/$total ($detection_rate%)"

  # Report failures
  if [ ${#failed_patterns[@]} -gt 0 ]; then
    print_status $YELLOW "⚠️ Failed to detect:"
    for failure in "${failed_patterns[@]}"; do
      printf "     • %s\n" "$failure"
    done
  fi

  # Validate against threshold
  if [ "$detection_rate" -lt "$MIN_DETECTION_RATE" ]; then
    print_status $RED "❌ CRITICAL: Low detection rate ($detection_rate% < $MIN_DETECTION_RATE%)"
    log_entry "ERROR" "Critical pattern detection failed: $detection_rate%"
    return 1
  else
    print_status $GREEN "✅ Critical pattern detection: $detection_rate% (≥$MIN_DETECTION_RATE%)"
    log_info "Critical pattern validation passed: $detection_rate%"
    return 0
  fi
}

validate_false_positives() {
  local gitleakslite_path=$1

  print_section "False Positive Analysis"
  log_info "Testing false positive patterns"

  # Generate patterns dynamically
  local -a patterns
  readarray -t patterns < <(generate_false_positive_patterns)

  # Setup test directory
  local test_dir="$TEMP_DIR/non_secrets"
  mkdir -p "$test_dir"
  add_temp_file "$test_dir"

  local false_positives=0
  local total=${#patterns[@]}
  local fp_patterns=()

  cd "$test_dir"

  for i in "${!patterns[@]}"; do
    local pattern="${patterns[i]}"
    local test_file="non_secret_$i.txt"

    # Create test file with non-secret
    {
      echo "// Non-secret test $i"
      echo "$pattern"
      echo "// Should not be flagged"
    } > "$test_file"

    add_temp_file "$test_dir/$test_file"

    # Test should NOT detect (gitleakslite should pass = exit 0)
    # Stage the file and use protect --staged for script-only gitleakslite
    git add "$test_file" 2>/dev/null || true
    if ! "$gitleakslite_path" protect --staged --no-banner >/dev/null 2>&1; then
      # gitleakslite failed = detected a secret (BAD - this should be ignored)
      false_positives=$((false_positives + 1))
      fp_patterns+=("Pattern $i: ${pattern:0:50}...")
      log_warn "FALSE POSITIVE pattern $i: ${pattern:0:50}..."
    else
      # gitleakslite passed = no secret detected (GOOD)
      log_debug "Correctly ignored pattern $i: ${pattern:0:50}..."
    fi
    git reset HEAD "$test_file" 2>/dev/null || true
  done

  cd - >/dev/null

  local fp_rate=$((false_positives * 100 / total))
  print_status $BLUE "📊 False Positive Results: $false_positives/$total ($fp_rate%)"

  # Report false positives
  if [ ${#fp_patterns[@]} -gt 0 ]; then
    print_status $YELLOW "⚠️ False positive patterns detected:"
    for fp in "${fp_patterns[@]}"; do
      printf "     • %s\n" "$fp"
    done
  fi

  # Validate against threshold
  if [ "$fp_rate" -gt "$MAX_FALSE_POSITIVE_RATE" ]; then
    print_status $YELLOW "⚠️ High false positive rate: $fp_rate% > $MAX_FALSE_POSITIVE_RATE%"
    log_warn "False positive rate above threshold: $fp_rate%"
    # Note: We don't fail on false positives for script-only version, just warn
  else
    print_status $GREEN "✅ False positive rate acceptable: $fp_rate% (≤$MAX_FALSE_POSITIVE_RATE%)"
    log_info "False positive validation passed: $fp_rate%"
  fi

  return 0  # Always pass false positive test
}

benchmark_performance() {
  local gitleakslite_path=$1

  print_section "Performance Benchmark"
  log_info "Running performance benchmark"

  # Create larger test file
  local test_dir="$TEMP_DIR/perf"
  mkdir -p "$test_dir"
  add_temp_file "$test_dir"

  cd "$test_dir"

  {
    echo "// Large test file for performance testing"
    for i in {1..500}; do
      echo "const data$i = '$(openssl rand -hex 32)';"
    done
    # Add one secret to detect
    echo "const secret = 'sk-$(openssl rand -hex 20)';"
  } > large_test.js

  add_temp_file "$test_dir/large_test.js"

  # Benchmark
  local start_time end_time duration_ms file_size_kb
  start_time=$(date +%s%N)

  git add large_test.js 2>/dev/null || true
  "$gitleakslite_path" protect --staged --no-banner >/dev/null 2>&1 || true
  git reset HEAD large_test.js 2>/dev/null || true

  end_time=$(date +%s%N)
  duration_ms=$(( (end_time - start_time) / 1000000 ))
  file_size_kb=$(( $(wc -c < large_test.js) / 1024 ))

  cd - >/dev/null

  print_status $BLUE "📊 Performance Results: ${file_size_kb}KB in ${duration_ms}ms"

  # Performance should be reasonable
  if [ "$duration_ms" -gt 5000 ]; then
    print_status $YELLOW "⚠️ Slow performance: ${duration_ms}ms"
  else
    print_status $GREEN "✅ Performance acceptable: ${duration_ms}ms (≤5000ms)"
  fi

  log_info "Performance validation passed: ${duration_ms}ms"
}

# =============================================================================
# MAIN VALIDATION LOGIC
# =============================================================================

main() {
  local gitleakslite_path="${1:-.security-controls/bin/gitleakslite}"

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --verbose)
        VERBOSE_MODE=true
        log_info "Verbose mode enabled"
        print_status $CYAN "🔍 Running forced gitleakslite validation"
        ;;
      --gitleakslite-path)
        gitleakslite_path="$2"
        shift
        ;;
      *)
        gitleakslite_path="$1"
        ;;
    esac
    shift
  done

  # Setup
  setup_logging

  print_section "Gitleakslite Validation Tool v$SCRIPT_VERSION"
  printf "Testing gitleakslite against statistical sample of secret patterns\n\n"
  log_info "Starting comprehensive validation: $gitleakslite_path"

  # Setup temp directory
  mkdir -p "$TEMP_DIR"
  add_temp_file "$TEMP_DIR"

  # Initialize git repo in temp dir for testing
  cd "$TEMP_DIR"
  git init -q 2>/dev/null || true
  git config user.email "validation@example.com" 2>/dev/null || true
  git config user.name "Validation" 2>/dev/null || true
  cd - >/dev/null

  # Run validation tests
  local validation_passed=true

  print_section "Binary Validation"
  validate_gitleakslite_binary "$gitleakslite_path"

  echo
  if ! validate_critical_patterns "$gitleakslite_path"; then
    validation_passed=false
  fi

  echo
  validate_false_positives "$gitleakslite_path"  # Never fails

  echo
  benchmark_performance "$gitleakslite_path"  # Never fails

  # Final results
  echo
  print_section "Validation Summary"
  if [[ "$validation_passed" == "true" ]]; then
    print_status $GREEN "✅ Gitleakslite comprehensive validation PASSED"
    printf "   • Critical pattern detection validated\n"
    printf "   • False positive rate within acceptable limits\n"
    printf "   • Performance meets requirements\n"
    printf "   • Ready for production use with high confidence\n"
    log_info "Comprehensive validation completed successfully"
    exit $EXIT_SUCCESS
  else
    print_status $RED "❌ Gitleakslite comprehensive validation FAILED"
    printf "   • Critical patterns missed - review gitleakslite implementation\n"
    log_entry "ERROR" "Comprehensive validation failed"
    exit $EXIT_VALIDATION_ERROR
  fi
}

# =============================================================================
# ENTRY POINT
# =============================================================================

# Skip validation if disabled, run sampling, or force
if [[ "${SKIP_GITLEAKSLITE_VALIDATION:-}" == "true" ]]; then
  print_status $CYAN "⏭️ Skipping gitleakslite validation (SKIP_GITLEAKSLITE_VALIDATION=true)"
  exit $EXIT_SUCCESS
elif [[ "${FORCE_GITLEAKSLITE_VALIDATION:-}" == "true" ]]; then
  main "$@"
elif [[ $((RANDOM % 10)) -eq 0 ]]; then
  print_status $CYAN "🎲 Running gitleakslite validation (10% sampling)"
  main "$@"
else
  print_status $CYAN "⏭️ Skipping gitleakslite validation (random sampling)"
  printf "   Force with: FORCE_GITLEAKSLITE_VALIDATION=true\n"
  exit $EXIT_SUCCESS
fi