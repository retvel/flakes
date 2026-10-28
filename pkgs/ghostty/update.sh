#!/usr/bin/env bash
# Bump hashes.json to upstream's latest tagged release. Stable dmgs are not
# GitHub release assets; they live on release.files.ghostty.org, and the Sparkle
# appcast there lists a version only once its download is published. Downloads
# the dmg (~35 MB) on a bump to hash it. Needs curl, jq and nix.
set -euo pipefail
cd "$(dirname "$0")"

base=https://release.files.ghostty.org

version="$(curl -fsSL "$base/appcast.xml" \
  | grep -oE '<sparkle:shortVersionString>[0-9]+\.[0-9]+\.[0-9]+<' \
  | sed -E 's/.*>([0-9.]+)</\1/' | sort -V | tail -n1)"
[ -n "$version" ] || { echo "ghostty: no release version in the appcast" >&2; exit 1; }

current="$(jq -r .version hashes.json)"
[ "$version" != "$current" ] || { echo "ghostty: $current is latest"; exit 0; }

hash="$(nix store prefetch-file --json "$base/$version/Ghostty.dmg" | jq -r .hash)"
jq -n --arg v "$version" --arg h "$hash" '{version: $v, hashes: {"Ghostty.dmg": $h}}' > hashes.json
echo "ghostty: $current -> $version"
