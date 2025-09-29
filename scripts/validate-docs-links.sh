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

# Documentation Links Validator
# Validates that all documentation site links are accessible before committing/releasing

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source deployment checker
# shellcheck source=scripts/check-docs-deployment.sh
source "$SCRIPT_DIR/check-docs-deployment.sh"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Extract documentation file paths from links
extract_doc_paths() {
  local file="$1"

  # Extract h4x0r.github.io URLs and get the path portion
  grep -oE 'https://h4x0r\.github\.io/1-click-github-sec/[a-zA-Z0-9_-]+' "$file" 2>/dev/null |
    sed 's|https://h4x0r\.github\.io/1-click-github-sec/||' |
    sort -u || true
}

# Check if files exist in mkdocs navigation
check_mkdocs_nav() {
  local doc_paths=("$@")
  local mkdocs_file="$PROJECT_ROOT/mkdocs.yml"
  local missing_files=()

  log_info "🔍 Checking MkDocs navigation for referenced files..."

  for path in "${doc_paths[@]}"; do
    # Convert URL path to filename (add .md extension)
    local filename="${path}.md"

    # Check if file exists in mkdocs.yml navigation
    if grep -q "$filename" "$mkdocs_file"; then
      log_success "✅ $filename found in MkDocs navigation"
    else
      log_warning "⚠️ $filename not found in MkDocs navigation"
      missing_files+=("$filename")
    fi
  done

  if [[ ${#missing_files[@]} -gt 0 ]]; then
    log_error "❌ Files missing from MkDocs navigation:"
    for file in "${missing_files[@]}"; do
      echo "  - $file"
    done
    return 1
  fi

  return 0
}

# Main validation function
validate_docs_links() {
  local target_files=("$@")
  local all_doc_paths=()

  echo "🔗 Documentation Links Validator"
  echo "==============================="
  echo ""

  # If no files specified, check common files
  if [[ ${#target_files[@]} -eq 0 ]]; then
    target_files=("$PROJECT_ROOT/README.md" "$PROJECT_ROOT/CLAUDE.md")
    log_info "No files specified. Checking README.md and CLAUDE.md..."
  fi

  # Extract all documentation paths from target files
  log_info "📋 Extracting documentation links from files..."
  for file in "${target_files[@]}"; do
    if [[ -f $file ]]; then
      local paths
      mapfile -t paths < <(extract_doc_paths "$file")
      if [[ ${#paths[@]} -gt 0 ]]; then
        log_info "  $file: ${paths[*]}"
        all_doc_paths+=("${paths[@]}")
      fi
    else
      log_warning "⚠️ File not found: $file"
    fi
  done

  # Remove duplicates
  IFS=" " read -r -a unique_paths <<<"$(printf '%s\n' "${all_doc_paths[@]}" | sort -u | tr '\n' ' ')"

  if [[ ${#unique_paths[@]} -eq 0 ]]; then
    log_info "ℹ️ No documentation site links found to validate"
    return 0
  fi

  echo ""
  log_info "🎯 Found ${#unique_paths[@]} unique documentation paths to validate:"
  for path in "${unique_paths[@]}"; do
    echo "  - $path"
  done
  echo ""

  # Check MkDocs navigation
  if ! check_mkdocs_nav "${unique_paths[@]}"; then
    log_error "❌ MkDocs navigation check failed"
    return 1
  fi

  echo ""

  # Check accessibility on live site
  log_info "🌐 Checking accessibility on live documentation site..."
  local inaccessible_files=()

  for path in "${unique_paths[@]}"; do
    if ! check_doc_file "$path"; then
      inaccessible_files+=("$path")
    fi
  done

  echo ""

  # Report results
  if [[ ${#inaccessible_files[@]} -eq 0 ]]; then
    log_success "🎉 All documentation links are accessible!"
    return 0
  else
    log_error "❌ ${#inaccessible_files[@]} documentation files are not accessible:"
    for file in "${inaccessible_files[@]}"; do
      echo "  - https://h4x0r.github.io/1-click-github-sec/$file"
    done
    echo ""
    log_info "💡 Possible solutions:"
    log_info "  1. Wait for GitHub Pages deployment: ./scripts/check-docs-deployment.sh --wait ${inaccessible_files[*]}"
    log_info "  2. Check if files are added to mkdocs.yml navigation"
    log_info "  3. Verify GitHub Pages is enabled and deploying correctly"
    return 1
  fi
}

# Usage information
usage() {
  cat <<EOF
Usage: $0 [FILES...]

Validate that all documentation site links in files are accessible.

ARGUMENTS:
    FILES...    Files to check for documentation links (default: README.md CLAUDE.md)

EXAMPLES:
    # Check default files
    $0

    # Check specific files
    $0 README.md docs/installation.md

    # Check all markdown files
    $0 *.md docs/*.md

EOF
}

# Main execution
main() {
  # Handle help flag
  if [[ $# -gt 0 && ($1 == "-h" || $1 == "--help") ]]; then
    usage
    exit 0
  fi

  # Run validation
  validate_docs_links "$@"
}

# Run main function if script is executed directly
if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
  main "$@"
fi
