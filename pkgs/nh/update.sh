#!/usr/bin/env bash
# Bump hashes.json to the latest upstream release. Needs gh, jq and nix.
set -euo pipefail
cd "$(dirname "$0")"
. ../../lib/update.sh

version="$(gh_latest nh nix-community/nh)"
skip_if_current nh "$version"

base="https://github.com/nix-community/nh/releases/download/v$version"
write_hashes "$version" \
  aarch64-darwin="$base/nh-aarch64-darwin" \
  aarch64-linux="$base/nh-aarch64-linux" \
  x86_64-linux="$base/nh-x86_64-linux"
echo "nh: $current -> $version"
