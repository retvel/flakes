#!/usr/bin/env bash
# Bump hashes.json to the latest upstream release. Needs gh, jq and nix.
set -euo pipefail
cd "$(dirname "$0")"
. ../../lib/update.sh

version="$(gh_latest anoa porcupine-md/anoa-browser)"
skip_if_current anoa "$version"

base="https://github.com/porcupine-md/anoa-browser/releases/download/v$version"
write_hashes "$version" \
  aarch64-linux="$base/anoa-linux-aarch64.tar.gz" \
  x86_64-linux="$base/anoa-linux-x86_64.tar.gz"
echo "anoa: $current -> $version"
