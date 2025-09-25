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

set -euo pipefail

# scripts/bump-version.sh <new_version>
# Updates installer version markers, VERSION file, and optionally CHANGELOG.md

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <new_version>" >&2
  exit 2
fi

NEW="$1"
if [[ ! $NEW =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Version must be semver (e.g., 1.5.0)" >&2
  exit 2
fi

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

INSTALL=install-security-controls.sh
if [[ ! -f $INSTALL ]]; then
  echo "install-security-controls.sh not found" >&2
  exit 1
fi

# Update header Version: X
if grep -q '^# Version:' "$INSTALL"; then
  sed -i.bak -E "s/^(# Version: )[0-9]+\.[0-9]+\.[0-9]+$/\1${NEW}/" "$INSTALL"
else
  echo "WARN: Version header not found in $INSTALL" >&2
fi

# Update SCRIPT_VERSION
if grep -q '^readonly SCRIPT_VERSION=' "$INSTALL"; then
  sed -i.bak -E "s/^(readonly SCRIPT_VERSION=)\"[0-9]+\.[0-9]+\.[0-9]+\"/\1\"${NEW}\"/" "$INSTALL"
else
  echo "WARN: SCRIPT_VERSION not found in $INSTALL" >&2
fi
rm -f "$INSTALL.bak"

# Update VERSION file
printf "%s\n" "$NEW" >VERSION

# Update CHANGELOG.md (prepend a new section if file exists, else create basic)
DATE=$(date +%Y-%m-%d)
if [[ -f CHANGELOG.md ]]; then
  TMP=$(mktemp)
  {
    echo "## v${NEW} - ${DATE}"
    echo
    echo "- Bump to v${NEW}"
    echo
    cat CHANGELOG.md
  } >"$TMP"
  mv "$TMP" CHANGELOG.md
else
  cat >CHANGELOG.md <<EOF
# Changelog

All notable changes to this project will be documented in this file.

## v${NEW} - ${DATE}

- Initial tracked version
EOF
fi

echo "Updated to version ${NEW}"
