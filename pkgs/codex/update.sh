#!/usr/bin/env bash
# Bump hashes.json to the latest @openai/codex on npm. Each platform's package
# carries its integrity hash in the registry, so nothing is downloaded. Needs
# curl and jq.
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source-path=SCRIPTDIR source=../../lib/update.sh
. ../../lib/update.sh

registry=https://registry.npmjs.org/@openai/codex
version="$(curl -fsS "$registry/latest" | jq -r '.version // empty')"
check_version codex "$version" '^[0-9]+\.[0-9]+\.[0-9]+$'
skip_if_current codex "$version"

integrity() { curl -fsS "$registry/$version-$1" | jq -er .dist.integrity; }
jq -n --arg v "$version" \
  --arg d "$(integrity darwin-arm64)" \
  --arg l "$(integrity linux-x64)" \
  --arg a "$(integrity linux-arm64)" \
  '{version: $v, hashes: {"aarch64-darwin": $d, "x86_64-linux": $l, "aarch64-linux": $a}}' > hashes.json
echo "codex: $current -> $version"
