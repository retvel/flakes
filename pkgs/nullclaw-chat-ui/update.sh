#!/usr/bin/env bash
# Bump hashes.json to the latest upstream release. Needs gh, jq and nix.
set -euo pipefail
cd "$(dirname "$0")"
. ../../lib/update.sh

version="$(gh_latest nullclaw-chat-ui nullclaw/nullclaw-chat-ui)"
skip_if_current nullclaw-chat-ui "$version"

write_hashes "$version" \
  tar.gz="https://github.com/nullclaw/nullclaw-chat-ui/releases/download/v$version/nullclaw-chat-ui-v$version.tar.gz"
echo "nullclaw-chat-ui: $current -> $version"
