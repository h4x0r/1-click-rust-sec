#!/usr/bin/env bash
set -euo pipefail

# sync-pinactlite.sh - Keep pinactlite versions in sync
# Usage: ./scripts/sync-pinactlite.sh [--check|--update]

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CANONICAL_PINACTLITE="$REPO_ROOT/.security-controls/bin/pinactlite"

usage() {
  cat <<EOF
sync-pinactlite.sh - Keep pinactlite versions synchronized

Usage:
    $0 --check    Check if versions are in sync
    $0 --update   Update installer to use canonical pinactlite
    $0 --help     Show this help

The canonical version is: .security-controls/bin/pinactlite
EOF
}

check_sync() {
  echo "🔍 Checking pinactlite version synchronization..."

  if [[ ! -f $CANONICAL_PINACTLITE ]]; then
    echo "❌ Canonical pinactlite not found: $CANONICAL_PINACTLITE"
    return 1
  fi

  # Check if installer references canonical source
  if grep -q "\.security-controls/bin/pinactlite" "$REPO_ROOT/install-security-controls.sh"; then
    echo "✅ Installer references canonical pinactlite source"
  else
    echo "❌ Installer doesn't reference canonical pinactlite source"
    return 1
  fi

  echo "✅ pinactlite versions are in sync"
  return 0
}

update_installer() {
  echo "🔄 Updating installer to use canonical pinactlite..."

  if check_sync; then
    echo "✅ Installer already uses canonical source"
  else
    echo "❌ Manual update required - see install_pinactlite_script() function"
    return 1
  fi
}

case "${1:-}" in
  --check)
    check_sync
    ;;
  --update)
    update_installer
    ;;
  --help | -h)
    usage
    ;;
  *)
    echo "Error: Invalid option. Use --help for usage."
    exit 1
    ;;
esac
