#!/usr/bin/env bash
# Bump hashes.json to upstream's latest tagged release. Stable dmgs are not
# GitHub release assets; they live on release.files.ghostty.org, and the Sparkle
# appcast there lists a version only once its download is published. Downloads
# the dmg (~35 MB) on a bump to hash it. Needs curl, jq and nix.
set -euo pipefail
cd "$(dirname "$0")"
. ../../lib/update.sh

base=https://release.files.ghostty.org

version="$(curl -fsSL "$base/appcast.xml" \
  | grep -oE '<sparkle:shortVersionString>[0-9]+\.[0-9]+\.[0-9]+<' \
  | sed -E 's/.*>([0-9.]+)</\1/' | sort -V | tail -n1)"
check_version ghostty "$version"
skip_if_current ghostty "$version"

write_hashes "$version" Ghostty.dmg="$base/$version/Ghostty.dmg"
echo "ghostty: $current -> $version"
