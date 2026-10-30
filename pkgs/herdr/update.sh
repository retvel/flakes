#!/usr/bin/env bash
# Bump hashes.json to the latest Herdr app, herdr-core and herdr CLI, as listed
# in upstream's app/latest.json, core/latest.json and herdr.dev/latest.json
# (what their updaters read).
# Needs curl, jq and nix.
set -euo pipefail
cd "$(dirname "$0")"

releases=https://releases.herdr.dev
# Kept beside hashes.json: the herdr-app wrapper serves them to the app as its
# release server, so it sees itself as up to date.
app_manifest="$(curl -fsS "$releases/app/latest.json")"
core_manifest="$(curl -fsS "$releases/core/latest.json")"
cli_manifest="$(curl -fsS https://herdr.dev/latest.json)"
app="$(jq -r '.version // empty' <<<"$app_manifest")"
core="$(jq -r '.version // empty' <<<"$core_manifest")"
cli="$(jq -r '.version // empty' <<<"$cli_manifest")"
[ -n "$app" ] && [ -n "$core" ] && [ -n "$cli" ] ||
  { echo "herdr: no version in latest.json" >&2; exit 1; }

# The workflow names its commit after .version, so it carries all three.
version="$app+core.$core+cli.$cli"
current="$(jq -r .version hashes.json)"
[ "$version" != "$current" ] || { echo "herdr: $current is latest"; exit 0; }

prefetch() { nix store prefetch-file --json "$1" | jq -r .hash; }
cli_url="https://github.com/herdrdev/herdr/releases/download/v$cli/herdr"
hashes="$(jq -n \
  --arg dmg "$(prefetch "$releases/app/$app/Herdr.dmg")" \
  --arg al64 "$(prefetch "$releases/app/$app/herdr-app-linux-x86_64.tar.gz")" \
  --arg ala64 "$(prefetch "$releases/app/$app/herdr-app-linux-aarch64.tar.gz")" \
  --arg cm "$(prefetch "$releases/core/$core/herdr-core-macos-aarch64.tar.gz")" \
  --arg cl64 "$(prefetch "$releases/core/$core/herdr-core-linux-x86_64.tar.gz")" \
  --arg cla64 "$(prefetch "$releases/core/$core/herdr-core-linux-aarch64.tar.gz")" \
  --arg hm "$(prefetch "$cli_url-macos-aarch64")" \
  --arg hl64 "$(prefetch "$cli_url-linux-x86_64")" \
  --arg hla64 "$(prefetch "$cli_url-linux-aarch64")" \
  '{
    "app-aarch64-darwin": $dmg,
    "app-x86_64-linux": $al64,
    "app-aarch64-linux": $ala64,
    "core-aarch64-darwin": $cm,
    "core-x86_64-linux": $cl64,
    "core-aarch64-linux": $cla64,
    "cli-aarch64-darwin": $hm,
    "cli-x86_64-linux": $hl64,
    "cli-aarch64-linux": $hla64
  }')"

jq -n --arg v "$version" --arg a "$app" --arg c "$core" --arg l "$cli" --argjson h "$hashes" \
  '{version: $v, app: $a, core: $c, cli: $l, hashes: $h}' > hashes.json
jq . <<<"$app_manifest" > app-latest.json
jq . <<<"$core_manifest" > core-latest.json
echo "herdr: $current -> $version"
