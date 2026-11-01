#!/usr/bin/env bash
# Bump hashes.json to the latest upstream release. Needs curl, jq and nix.
# The version comes from the download page on obdev.at, not from the
# releases/<version> tags on obdev/littlesnitch-linux: those lag behind (1.1.1
# shipped untagged), and obdev.at drops old tarballs once a new one is out.
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source-path=SCRIPTDIR source=../../lib/update.sh
. ../../lib/update.sh

base=https://obdev.at/downloads/littlesnitch-linux

version="$(curl -fsSL https://obdev.at/products/littlesnitch-linux/download.html \
  | grep -oE 'littlesnitch-[0-9]+(\.[0-9]+)+-amd64-linux-musl\.tar\.gz' \
  | sed -E 's/^littlesnitch-(.*)-amd64-linux-musl\.tar\.gz$/\1/' | sort -uV | tail -n1)"
check_version littlesnitch "$version"
skip_if_current littlesnitch "$version"

declare -A arches=(
  [aarch64-linux]=arm64
  [x86_64-linux]=amd64
)

# Upstream's checksum list, which each download must match.
sums="$base/littlesnitch-$version.hashes.txt"

hashes='{}'
for system in "${!arches[@]}"; do
  file="littlesnitch-$version-${arches[$system]}-linux-musl.tar.gz"
  want="$(upstream_sha256 "$base/$file")"
  hash="$(prefetch "$base/$file" "$want")"
  hashes="$(jq --arg s "$system" --arg h "$hash" '. + {($s): $h}' <<<"$hashes")"
done

jq -n --arg v "$version" --argjson h "$hashes" '{version: $v, hashes: ($h | to_entries | sort_by(.key) | from_entries)}' > hashes.json
echo "littlesnitch: $current -> $version"
