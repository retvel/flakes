#!/usr/bin/env bash
# Bump hashes.json to the latest @openai/codex on npm. Each platform's package
# carries its integrity hash in the registry, so nothing is downloaded. Needs
# curl and jq.
set -euo pipefail
cd "$(dirname "$0")"

registry=https://registry.npmjs.org/@openai/codex
version="$(curl -fsS "$registry/latest" | jq -r '.version // empty')"
[ -n "$version" ] || { echo "codex: no latest version on npm" >&2; exit 1; }
current="$(jq -r .version hashes.json)"
[ "$version" != "$current" ] || { echo "codex: $current is latest"; exit 0; }

integrity() { curl -fsS "$registry/$version-$1" | jq -er .dist.integrity; }
jq -n --arg v "$version" \
  --arg d "$(integrity darwin-arm64)" \
  --arg l "$(integrity linux-x64)" \
  --arg a "$(integrity linux-arm64)" \
  '{version: $v, hashes: {"aarch64-darwin": $d, "x86_64-linux": $l, "aarch64-linux": $a}}' > hashes.json
echo "codex: $current -> $version"
