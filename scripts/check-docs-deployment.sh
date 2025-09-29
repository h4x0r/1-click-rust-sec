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

# GitHub Pages Deployment Checker
# Waits for GitHub Pages deployment and validates documentation accessibility
#
# PURPOSE: Deployment timing validation
# - Prevents 404 errors during GitHub Pages deployment lag (typically 30s-12min)
# - Use before updating documentation site URLs in source files
# - Complements lychee CI validation by handling deployment timing

set -euo pipefail

# Configuration
DOCS_BASE_URL="https://h4x0r.github.io/1-click-github-sec"
MAX_WAIT_TIME=720 # 12 minutes maximum wait (covers 90% of deployments)
CHECK_INTERVAL=30 # Check every 30 seconds
TIMEOUT=10        # HTTP request timeout

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage information
usage() {
  cat <<EOF
Usage: $0 [OPTIONS] [FILE_PATHS...]

Check if documentation files are accessible on GitHub Pages before updating links.

OPTIONS:
    -w, --wait          Wait for deployment if files are not yet accessible
    -t, --timeout SEC   Maximum wait time in seconds (default: 300)
    -i, --interval SEC  Check interval in seconds (default: 30)
    -h, --help          Show this help message

EXAMPLES:
    # Check if signing-guide is deployed
    $0 signing-guide

    # Check multiple files with wait
    $0 --wait signing-guide installation architecture

    # Check with custom timeout
    $0 --wait --timeout 600 signing-guide

EOF
}

# Logging functions
log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Check if a documentation file is accessible
check_doc_file() {
  local file_path="$1"
  local url="${DOCS_BASE_URL}/${file_path}"

  log_info "Checking: $url"

  if curl --silent --fail --max-time "$TIMEOUT" --head "$url" >/dev/null 2>&1; then
    log_success "✅ $file_path is accessible"
    return 0
  else
    log_warning "❌ $file_path is not accessible (404 or timeout)"
    return 1
  fi
}

# Wait for deployment with retry logic
wait_for_deployment() {
  local files=("$@")
  local start_time
  start_time=$(date +%s)
  local end_time=$((start_time + MAX_WAIT_TIME))

  log_info "🔄 Waiting for GitHub Pages deployment (max ${MAX_WAIT_TIME}s)..."

  while true; do
    local current_time
    current_time=$(date +%s)

    # Check if we've exceeded the maximum wait time
    if [[ $current_time -gt $end_time ]]; then
      log_error "⏰ Timeout reached (${MAX_WAIT_TIME}s). Deployment may still be in progress."
      return 1
    fi

    # Check all files
    local all_accessible=true
    for file in "${files[@]}"; do
      if ! check_doc_file "$file"; then
        all_accessible=false
        break
      fi
    done

    # If all files are accessible, we're done
    if [[ $all_accessible == "true" ]]; then
      log_success "🎉 All documentation files are now accessible!"
      return 0
    fi

    # Wait before next check
    local elapsed=$((current_time - start_time))
    log_info "⏳ Still waiting... (${elapsed}s elapsed, retrying in ${CHECK_INTERVAL}s)"
    sleep "$CHECK_INTERVAL"
  done
}

# Get GitHub Pages deployment status via API
check_deployment_status() {
  log_info "🔍 Checking GitHub Pages deployment status..."

  # Check if gh CLI is available
  if ! command -v gh &>/dev/null; then
    log_warning "GitHub CLI not available. Skipping deployment status check."
    return 0
  fi

  # Get latest deployment
  local deployment_info
  if deployment_info=$(gh api repos/h4x0r/1-click-github-sec/deployments --jq '.[0] | {id, sha, environment, created_at}' 2>/dev/null); then
    log_info "📋 Latest deployment: $deployment_info"

    # Check deployment status
    local deployment_id
    deployment_id=$(echo "$deployment_info" | jq -r '.id')

    local status_info
    if status_info=$(gh api "repos/h4x0r/1-click-github-sec/deployments/$deployment_id/statuses" --jq '.[0] | {state, description, created_at}' 2>/dev/null); then
      log_info "📊 Deployment status: $status_info"
    fi
  else
    log_warning "Could not retrieve deployment information"
  fi
}

# Main function
main() {
  local files=()
  local wait_mode=false

  # Parse command line arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -w | --wait)
        wait_mode=true
        shift
        ;;
      -t | --timeout)
        MAX_WAIT_TIME="$2"
        shift 2
        ;;
      -i | --interval)
        CHECK_INTERVAL="$2"
        shift 2
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      -*)
        log_error "Unknown option: $1"
        usage
        exit 1
        ;;
      *)
        files+=("$1")
        shift
        ;;
    esac
  done

  # Default to common files if none specified
  if [[ ${#files[@]} -eq 0 ]]; then
    files=("installation" "architecture" "cryptographic-verification")
    log_info "No files specified. Checking common documentation files..."
  fi

  echo "🔍 GitHub Pages Deployment Checker"
  echo "=================================="
  echo ""

  # Show configuration
  log_info "Configuration:"
  log_info "  Base URL: $DOCS_BASE_URL"
  log_info "  Files to check: ${files[*]}"
  log_info "  Wait mode: $wait_mode"
  log_info "  Max wait time: ${MAX_WAIT_TIME}s"
  log_info "  Check interval: ${CHECK_INTERVAL}s"
  echo ""

  # Check deployment status
  check_deployment_status
  echo ""

  # Initial check
  local all_accessible=true
  for file in "${files[@]}"; do
    if ! check_doc_file "$file"; then
      all_accessible=false
    fi
  done

  echo ""

  # Handle results
  if [[ $all_accessible == "true" ]]; then
    log_success "🎉 All documentation files are accessible!"
    exit 0
  elif [[ $wait_mode == "true" ]]; then
    wait_for_deployment "${files[@]}"
    exit $?
  else
    log_error "❌ Some documentation files are not accessible."
    log_info "💡 Use --wait flag to wait for deployment, or check GitHub Pages status"
    log_info "💡 GitHub Pages deployment typically takes 1-2 minutes after push"
    exit 1
  fi
}

# Run main function if script is executed directly
if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
  main "$@"
fi
