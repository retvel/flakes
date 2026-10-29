#!/usr/bin/env bash
# Bump hashes.json to Pake's latest release. Needs gh, jq and nix.
set -euo pipefail
cd "$(dirname "$0")"

tag="$(gh release view -R tw93/Pake --json tagName -q .tagName)"
version="${tag#V}"
current="$(jq -r .version hashes.json)"
[ "$version" != "$current" ] || { echo "claude-pake: $current is latest"; exit 0; }

hash="$(nix flake prefetch --json "github:tw93/Pake/$tag" | jq -r .hash)"

# The vendored crates' hash is only known once they are fetched: build them
# against a fake hash and take the one Nix reports.
fake="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
jq -n --arg v "$version" --arg h "$hash" --arg c "$fake" \
  '{version: $v, hash: $h, cargoHash: $c}' > hashes.json
cargoHash="$(nix build "../..#claude-pake.cargoDeps" --no-link 2>&1 \
  | sed -n 's/.*got: *\(sha256-[^ ]*\).*/\1/p' | head -n1)"
[ -n "$cargoHash" ] || { echo "claude-pake: could not determine cargoHash" >&2; git checkout -- hashes.json; exit 1; }

jq -n --arg v "$version" --arg h "$hash" --arg c "$cargoHash" \
  '{version: $v, hash: $h, cargoHash: $c}' > hashes.json
echo "claude-pake: $current -> $version"
