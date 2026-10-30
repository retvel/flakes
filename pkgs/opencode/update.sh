#!/usr/bin/env bash
# Bump hashes.json to the latest opencode-ai on npm (OpenCode 1). Each
# platform's package carries its integrity hash in the registry, so nothing is
# downloaded. Needs curl and jq.
set -euo pipefail
cd "$(dirname "$0")"

version="$(curl -fsS https://registry.npmjs.org/opencode-ai/latest | jq -r '.version // empty')"
[ -n "$version" ] || { echo "opencode: no latest version on npm" >&2; exit 1; }
current="$(jq -r .version hashes.json)"
[ "$version" != "$current" ] || { echo "opencode: $current is latest"; exit 0; }

integrity() { curl -fsS "https://registry.npmjs.org/opencode-$1/$version" | jq -er .dist.integrity; }
jq -n --arg v "$version" \
  --arg d "$(integrity darwin-arm64)" \
  --arg l "$(integrity linux-x64)" \
  --arg a "$(integrity linux-arm64)" \
  '{version: $v, hashes: {"aarch64-darwin": $d, "x86_64-linux": $l, "aarch64-linux": $a}}' > hashes.json
echo "opencode: $current -> $version"
