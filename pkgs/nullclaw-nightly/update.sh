#!/usr/bin/env bash
# Bump hashes.json to upstream's current nightly. The `nightly` release is
# rebuilt in place, so its assets are replaced under the same names; hashes come
# from the per-asset .sha256 files, so nothing is downloaded.
# Needs gh, curl, jq and nix.
set -euo pipefail
cd "$(dirname "$0")"
. ../../lib/update.sh

repo=nullclaw/nullclaw
base="https://github.com/$repo/releases/download/nightly"

# The release notes carry "- Version: `nightly-YYYYMMDD-<sha>`", as the binary's --version does.
version="$(gh release view nightly -R "$repo" --json body -q .body |
  sed -n 's/^- Version: `nightly-\([^`]*\)`.*/\1/p')"
check_version nullclaw-nightly "$version" '^[0-9]{8}-[0-9a-f]{7,40}$'
skip_if_current nullclaw-nightly "$version"

declare -A targets=(
  [aarch64-darwin]=macos-aarch64
  [aarch64-linux]=linux-aarch64
  [x86_64-linux]=linux-x86_64
)

hashes='{}'
for system in "${!targets[@]}"; do
  asset="nullclaw-${targets[$system]}"
  # Upstream deletes the old assets before uploading new ones; skip this run
  # rather than fail the whole update workflow if we land in that window.
  hex="$(curl -fsSL "$base/$asset.sha256" | awk '{ print $1 }')" ||
    { echo "nullclaw-nightly: $asset.sha256 missing, nightly is being published; skipping"; exit 0; }
  [[ $hex =~ ^[0-9a-f]{64}$ ]] || { echo "nullclaw-nightly: bad checksum for $asset" >&2; exit 1; }
  sri="$(nix hash convert --hash-algo sha256 --to sri "$hex")"
  hashes="$(jq --arg s "$system" --arg h "$sri" '. + {($s): $h}' <<<"$hashes")"
done

jq -n --arg v "$version" --argjson h "$hashes" '{version: $v, hashes: ($h | to_entries | sort_by(.key) | from_entries)}' > hashes.json
echo "nullclaw-nightly: $current -> $version"
