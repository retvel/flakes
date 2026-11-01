#!/usr/bin/env bash
# Bump hashes.json to the latest OpenCode 2 on npm (@opencode/cli, the package
# opencode.ai/v2/install reads from opencode.ai/update/api/latest/cli/npm). Each
# platform's package carries its integrity hash in the registry, so nothing is
# downloaded. Needs curl and jq.
set -euo pipefail
cd "$(dirname "$0")"
. ../../lib/update.sh

version="$(curl -fsS https://registry.npmjs.org/@opencode%2fcli/latest | jq -r '.version // empty')"
check_version opencode "$version" '^[0-9]+\.[0-9]+\.[0-9]+$'
skip_if_current opencode "$version"

integrity() { curl -fsS "https://registry.npmjs.org/@opencode%2fcli-$1/$version" | jq -er .dist.integrity; }
jq -n --arg v "$version" \
  --arg d "$(integrity darwin-arm64)" \
  --arg l "$(integrity linux-x64)" \
  --arg a "$(integrity linux-arm64)" \
  '{version: $v, hashes: {"aarch64-darwin": $d, "x86_64-linux": $l, "aarch64-linux": $a}}' > hashes.json
echo "opencode: $current -> $version"
