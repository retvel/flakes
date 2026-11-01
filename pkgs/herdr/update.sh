#!/usr/bin/env bash
# Bump hashes.json to the latest Herdr app, herdr-core and herdr CLI, as listed
# in upstream's app/latest.json, core/latest.json and herdr.dev/latest.json
# (what their updaters read).
# Each download is checked against the sha256 its manifest lists, and the CLI
# against GitHub's digest too. Needs curl, gh, jq and nix.
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source-path=SCRIPTDIR source=../../lib/update.sh
. ../../lib/update.sh

releases=https://releases.herdr.dev
# Kept beside hashes.json: the herdr-app wrapper serves them to the app as its
# release server, so it sees itself as up to date.
app_manifest="$(curl -fsS "$releases/app/latest.json")"
core_manifest="$(curl -fsS "$releases/core/latest.json")"
cli_manifest="$(curl -fsS https://herdr.dev/latest.json)"
app="$(jq -r '.version // empty' <<<"$app_manifest")"
core="$(jq -r '.version // empty' <<<"$core_manifest")"
cli="$(jq -r '.version // empty' <<<"$cli_manifest")"
check_version herdr "$app"
check_version herdr "$core"
check_version herdr "$cli"

# The workflow names its commit after .version, so it carries all three.
version="$app+core.$core+cli.$cli"
skip_if_current herdr "$version"

cli_url="https://github.com/herdrdev/herdr/releases/download/v$cli/herdr"
# The sha256 each manifest lists for a target (the macOS app's dmg has none).
app_sum() { jq -r --arg t "$1" '.targets[$t].sha256' <<<"$app_manifest"; }
core_sum() { jq -r --arg t "$1" '.targets[$t].sha256' <<<"$core_manifest"; }
cli_sum() { jq -r --arg t "$1" '.sha256[$t]' <<<"$cli_manifest"; }
hashes="$(jq -n \
  --arg dmg "$(prefetch "$releases/app/$app/Herdr.dmg")" \
  --arg al64 "$(prefetch "$releases/app/$app/herdr-app-linux-x86_64.tar.gz" "$(app_sum linux-x86_64)")" \
  --arg ala64 "$(prefetch "$releases/app/$app/herdr-app-linux-aarch64.tar.gz" "$(app_sum linux-aarch64)")" \
  --arg cm "$(prefetch "$releases/core/$core/herdr-core-macos-aarch64.tar.gz" "$(core_sum macos-aarch64)")" \
  --arg cl64 "$(prefetch "$releases/core/$core/herdr-core-linux-x86_64.tar.gz" "$(core_sum linux-x86_64)")" \
  --arg cla64 "$(prefetch "$releases/core/$core/herdr-core-linux-aarch64.tar.gz" "$(core_sum linux-aarch64)")" \
  --arg hm "$(prefetch "$cli_url-macos-aarch64" "$(cli_sum macos-aarch64)")" \
  --arg hl64 "$(prefetch "$cli_url-linux-x86_64" "$(cli_sum linux-x86_64)")" \
  --arg hla64 "$(prefetch "$cli_url-linux-aarch64" "$(cli_sum linux-aarch64)")" \
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
# A failed download or checksum inside the "$(prefetch ...)" above leaves an
# empty hash.
jq -e 'all(.[]; startswith("sha256-"))' <<<"$hashes" >/dev/null ||
  { echo "herdr: a download failed" >&2; exit 1; }

jq -n --arg v "$version" --arg a "$app" --arg c "$core" --arg l "$cli" --argjson h "$hashes" \
  '{version: $v, app: $a, core: $c, cli: $l, hashes: $h}' > hashes.json
jq . <<<"$app_manifest" > app-latest.json
jq . <<<"$core_manifest" > core-latest.json
echo "herdr: $current -> $version"
