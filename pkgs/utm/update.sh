#!/usr/bin/env bash
# Bump hashes.json to the latest upstream release. Needs gh, jq and nix.
set -euo pipefail
cd "$(dirname "$0")"

# `gh release view` without a tag skips pre-releases.
latest="$(gh release view -R utmapp/UTM --json tagName -q .tagName)"
version="${latest#v}"
current="$(jq -r .version hashes.json)"
[ "$version" != "$current" ] || { echo "utm: $current is latest"; exit 0; }

hash="$(nix store prefetch-file --json \
  "https://github.com/utmapp/UTM/releases/download/v$version/UTM.dmg" | jq -r .hash)"

jq -n --arg v "$version" --arg h "$hash" '{version: $v, hashes: {"UTM.dmg": $h}}' > hashes.json
echo "utm: $current -> $version"
