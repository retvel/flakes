#!/usr/bin/env bash
# Bump hashes.json to the latest Herdr app and herdr-core, as listed in
# upstream's app/latest.json and core/latest.json (what their updaters read).
# Needs curl, jq and nix.
set -euo pipefail
cd "$(dirname "$0")"

releases=https://releases.herdr.dev
app="$(curl -fsS "$releases/app/latest.json" | jq -r '.version // empty')"
core="$(curl -fsS "$releases/core/latest.json" | jq -r '.version // empty')"
[ -n "$app" ] && [ -n "$core" ] || { echo "herdr: no version in latest.json" >&2; exit 1; }

# The workflow names its commit after .version, so it carries both.
version="$app+core.$core"
current="$(jq -r .version hashes.json)"
[ "$version" != "$current" ] || { echo "herdr: $current is latest"; exit 0; }

prefetch() { nix store prefetch-file --json "$1" | jq -r .hash; }
hashes="$(jq -n \
  --arg dmg "$(prefetch "$releases/app/$app/Herdr.dmg")" \
  --arg al64 "$(prefetch "$releases/app/$app/herdr-app-linux-x86_64.tar.gz")" \
  --arg ala64 "$(prefetch "$releases/app/$app/herdr-app-linux-aarch64.tar.gz")" \
  --arg cm "$(prefetch "$releases/core/$core/herdr-core-macos-aarch64.tar.gz")" \
  --arg cl64 "$(prefetch "$releases/core/$core/herdr-core-linux-x86_64.tar.gz")" \
  --arg cla64 "$(prefetch "$releases/core/$core/herdr-core-linux-aarch64.tar.gz")" \
  '{
    "app-aarch64-darwin": $dmg,
    "app-x86_64-linux": $al64,
    "app-aarch64-linux": $ala64,
    "core-aarch64-darwin": $cm,
    "core-x86_64-linux": $cl64,
    "core-aarch64-linux": $cla64
  }')"

jq -n --arg v "$version" --arg a "$app" --arg c "$core" --argjson h "$hashes" \
  '{version: $v, app: $a, core: $c, hashes: $h}' > hashes.json
echo "herdr: $current -> $version"
