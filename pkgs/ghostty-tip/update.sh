#!/usr/bin/env bash
# Bump hashes.json to upstream's current tip build. The `tip` release is rebuilt
# on every green commit to main and its assets are replaced under the same
# names; the hash comes from GitHub's asset digest, so nothing is downloaded.
# Needs gh, jq and nix.
set -euo pipefail
cd "$(dirname "$0")"

repo=ghostty-org/ghostty

# `tip` is an annotated tag: its tagger date is the build time, its object the commit.
tag="$(gh api "repos/$repo/git/ref/tags/tip" -q .object.sha)"
read -r date sha < <(gh api "repos/$repo/git/tags/$tag" -q '"\(.tagger.date) \(.object.sha)"')
[ -n "${sha:-}" ] || { echo "ghostty-tip: could not resolve the tip commit" >&2; exit 1; }
version="$(tr -d - <<<"${date%%T*}")-${sha:0:7}"

digest="$(gh release view tip -R "$repo" --json assets -q '.assets[] | select(.name == "Ghostty.dmg") | .digest')"
# Missing while upstream replaces the assets; skip this run rather than fail.
[ -n "$digest" ] || { echo "ghostty-tip: Ghostty.dmg missing, tip is being published; skipping"; exit 0; }
hash="$(nix hash convert --hash-algo sha256 --to sri "${digest#sha256:}")"

# Compare the hash too: the tag and the assets are not updated atomically.
current="$(jq -r .version hashes.json)"
if [ "$version" = "$current" ] && [ "$hash" = "$(jq -r '.hashes."Ghostty.dmg"' hashes.json)" ]; then
  echo "ghostty-tip: $current is latest"
  exit 0
fi

jq -n --arg v "$version" --arg h "$hash" '{version: $v, hashes: {"Ghostty.dmg": $h}}' > hashes.json
echo "ghostty-tip: $current -> $version"
