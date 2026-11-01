#!/usr/bin/env bash
# Bump hashes.json to the latest upstream release. Needs gh, jq and nix.
set -euo pipefail
cd "$(dirname "$0")"
. ../../lib/update.sh

version="$(gh_latest nullclaw nullclaw/nullclaw)"
skip_if_current nullclaw "$version"

base="https://github.com/nullclaw/nullclaw/releases/download/v$version"
write_hashes "$version" \
  aarch64-darwin="$base/nullclaw-macos-aarch64.bin" \
  aarch64-linux="$base/nullclaw-linux-aarch64.bin" \
  x86_64-linux="$base/nullclaw-linux-x86_64.bin"
echo "nullclaw: $current -> $version"
