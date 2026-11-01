#!/usr/bin/env bash
# Bump hashes.json to the latest upstream release. Needs gh, jq and nix.
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source-path=SCRIPTDIR source=../../lib/update.sh
. ../../lib/update.sh

version="$(gh_latest rayfish rayfish/rayfish)"
skip_if_current rayfish "$version"

base="https://github.com/rayfish/rayfish/releases/download/v$version"
write_hashes "$version" \
  aarch64-darwin="$base/ray-macos-aarch64" \
  aarch64-linux="$base/ray-linux-aarch64" \
  x86_64-linux="$base/ray-linux-x86_64"
echo "rayfish: $current -> $version"
