#!/usr/bin/env bash
# Bump hashes.json to the latest upstream release. Needs gh, jq and nix.
set -euo pipefail
cd "$(dirname "$0")"

latest="$(gh release view -R porcupine-md/anoa-browser --json tagName -q .tagName)"
version="${latest#v}"
current="$(jq -r .version hashes.json 2>/dev/null || echo none)"
[ "$version" != "$current" ] || { echo "anoa: $current is latest"; exit 0; }

declare -A assets=(
  [aarch64-linux]=linux-aarch64
  [x86_64-linux]=linux-x86_64
)

hashes='{}'
for system in "${!assets[@]}"; do
  hash="$(nix store prefetch-file --json \
    "https://github.com/porcupine-md/anoa-browser/releases/download/v$version/anoa-${assets[$system]}.tar.gz" | jq -r .hash)"
  hashes="$(jq --arg s "$system" --arg h "$hash" '. + {($s): $h}' <<<"$hashes")"
done

jq -n --arg v "$version" --argjson h "$hashes" '{version: $v, hashes: ($h | to_entries | sort_by(.key) | from_entries)}' > hashes.json
echo "anoa: $current -> $version"
