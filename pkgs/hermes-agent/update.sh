#!/usr/bin/env bash
# Pin hashes.json to the latest stable Hermes release. Needs gh, jq, git and nix.
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source-path=SCRIPTDIR source=../../lib/update.sh
. ../../lib/update.sh

repo=NousResearch/hermes-agent
# Same rule as Tier 1's stable channel: the release GitHub marks latest
# (never a draft or prerelease), checked against STABLE_TAG_RE from
# hermes_cli/update_channel.py, which also rejects calendar tags (v2026.9.24).
latest="$(gh release view -R "$repo" --json tagName -q .tagName)"
version="${latest#v}"
check_version hermes-agent "$version" '^(0|[1-9][0-9]{0,2})\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'
[ "$latest" = "v$version" ] || { echo "hermes-agent: unexpected tag $latest" >&2; exit 1; }
skip_if_current hermes-agent "$version"

# Annotated tags point at a tag object; ^{} gives the commit.
rev="$(git ls-remote "https://github.com/$repo" "refs/tags/$latest^{}" | cut -f1)"
[ -n "$rev" ] || rev="$(git ls-remote "https://github.com/$repo" "refs/tags/$latest" | cut -f1)"
[[ $rev =~ ^[0-9a-f]{40}$ ]] || { echo "hermes-agent: no commit for $latest" >&2; exit 1; }
narHash="$(nix flake metadata --json "github:$repo/$rev" | jq -er .locked.narHash)"

jq -n --arg v "$version" --arg r "$rev" --arg h "$narHash" \
  '{version: $v, rev: $r, narHash: $h}' > hashes.json
echo "hermes-agent: $current -> $version"
