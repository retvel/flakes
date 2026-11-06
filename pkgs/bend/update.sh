#!/usr/bin/env bash
# Bump hashes.json to the Bend release that bend-lang.com/install.sh installs.
# That script carries the version and the sha256 of each release archive, so
# each download is checked against it (and against GitHub's digest).
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source-path=SCRIPTDIR source=../../lib/update.sh
. ../../lib/update.sh

script="$(curl -fsSL https://bend-lang.com/install.sh)"
# field NAME: the value of NAME="..." in install.sh.
field() { sed -n "s/^$1=\"\\([^\"]*\\)\"\$/\\1/p" <<<"$script" | head -n1; }

version="$(field VER)"
check_version bend "$version" '^[0-9]+\.[0-9]+\.[0-9]+$'
skip_if_current bend "$version"

hashes='{}'
for pair in aarch64-darwin=DARWIN_ARM64:darwin-arm64 \
  x86_64-linux=LINUX_X64:linux-x64 aarch64-linux=LINUX_ARM64:linux-arm64; do
  system=${pair%%=*} rest=${pair#*=}
  want="$(field "SHA_${rest%%:*}")"
  [[ $want =~ ^[0-9a-f]{64}$ ]] || { echo "bend: no sha256 for $system in install.sh" >&2; exit 1; }
  url="https://github.com/bendlang/bend/releases/download/v$version/bend-$version-${rest#*:}.tar.gz"
  hash="$(prefetch "$url" "$want")"
  hashes="$(jq --arg k "$system" --arg h "$hash" '. + {($k): $h}' <<<"$hashes")"
done
jq -n --arg v "$version" --argjson h "$hashes" \
  '{version: $v, hashes: ($h | to_entries | sort_by(.key) | from_entries)}' > hashes.json
echo "bend: $current -> $version"
