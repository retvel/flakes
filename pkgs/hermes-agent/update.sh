#!/usr/bin/env bash
# Pin hashes.json to the latest stable Hermes release. Needs gh, jq, git and nix.
set -euo pipefail
cd "$(dirname "$0")"

repo=NousResearch/hermes-agent
# The release marked latest is never a draft or prerelease (no canary/rc).
# Short major only: older calendar tags (v2026.9.24) are not this scheme.
latest="$(gh release view -R "$repo" --json tagName -q .tagName)"
[[ $latest =~ ^v[0-9]{1,3}\.[0-9]+\.[0-9]+$ ]] || { echo "hermes-agent: unexpected tag $latest" >&2; exit 1; }
version="${latest#v}"
current="$(jq -r .version hashes.json)"
[ "$version" != "$current" ] || { echo "hermes-agent: $current is latest"; exit 0; }

# Annotated tags point at a tag object; ^{} gives the commit.
rev="$(git ls-remote "https://github.com/$repo" "refs/tags/$latest^{}" | cut -f1)"
[ -n "$rev" ] || rev="$(git ls-remote "https://github.com/$repo" "refs/tags/$latest" | cut -f1)"
narHash="$(nix flake metadata --json "github:$repo/$rev" | jq -r .locked.narHash)"

jq -n --arg v "$version" --arg r "$rev" --arg h "$narHash" \
  '{version: $v, rev: $r, narHash: $h}' > hashes.json
echo "hermes-agent: $current -> $version"
