#!/usr/bin/env bash
# Bump hashes.json to the latest upstream release. Needs gh, jq and nix.
set -euo pipefail
cd "$(dirname "$0")"
. ../../lib/update.sh

version="$(gh_latest 1mcp 1mcp-app/agent)"
skip_if_current 1mcp "$version"

base="https://github.com/1mcp-app/agent/releases/download/v$version"
write_hashes "$version" \
  aarch64-darwin="$base/1mcp-darwin-arm64.tar.gz" \
  aarch64-linux="$base/1mcp-linux-arm64.tar.gz" \
  x86_64-linux="$base/1mcp-linux-x64.tar.gz"
echo "1mcp: $current -> $version"
