#!/usr/bin/env bash
# Bump hashes.json to the latest upstream release. Needs curl, gh, jq and nix.
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source-path=SCRIPTDIR source=../../lib/update.sh
. ../../lib/update.sh

version="$(gh_latest muxin LumaryLabsLLC/muxin)"
skip_if_current muxin "$version"

base="https://github.com/LumaryLabsLLC/muxin/releases/download/v$version"
sums="$base/SHA256SUMS.txt"
write_hashes "$version" \
  aarch64-darwin="$base/Muxin-$version-macos.dmg" \
  aarch64-linux="$base/Muxin-$version-linux-aarch64.tar.gz" \
  x86_64-linux="$base/Muxin-$version-linux-x86_64.tar.gz"
echo "muxin: $current -> $version"
