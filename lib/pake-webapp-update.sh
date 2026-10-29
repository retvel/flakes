#!/usr/bin/env bash
# Bump a webapp's hashes.json to Pake's latest release. Run from the webapp's
# own update.sh as `pake-webapp-update.sh <name>`. Needs gh, jq and nix.
set -euo pipefail
name="$1"
cd "$(dirname "$0")/../pkgs/$name"

tag="$(gh release view -R tw93/Pake --json tagName -q .tagName)"
version="${tag#V}"
current="$(jq -r .version hashes.json)"
[ "$version" != "$current" ] || { echo "$name: $current is latest"; exit 0; }

hash="$(nix flake prefetch --json "github:tw93/Pake/$tag" | jq -r .hash)"

# The vendored crates' hash is only known once they are fetched: build them
# against a fake hash and take the one Nix reports.
write() {
  jq -n --arg v "$version" --arg h "$hash" --arg c "$1" \
    '{version: $v, hash: $h, cargoHash: $c}' > hashes.json
}
write "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
cargoHash="$(nix build "../..#$name.cargoDeps" --no-link 2>&1 \
  | sed -n 's/.*got: *\(sha256-[^ ]*\).*/\1/p' | head -n1)"
if [ -z "$cargoHash" ]; then
  echo "$name: could not determine cargoHash" >&2
  git checkout -- hashes.json
  exit 1
fi
write "$cargoHash"
echo "$name: $current -> $version"
