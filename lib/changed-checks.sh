#!/usr/bin/env bash
# Prints the checks of <system> whose derivation differs from those at <rev>
# (a git revision, such as origin/main), one name per line: what a change
# needs built on that system, the packages it takes as arguments included.
# formatting is left out: it takes the whole source, so it always differs, and
# the Linux jobs build it. Run by check.yml on macOS. Needs git, jq and nix.
set -euo pipefail
cd "$(dirname "$0")/.."
system=$1 rev=$2

drvs() {
  nix eval --json "$1#checks.$system" \
    --apply 'cs: builtins.mapAttrs (n: c: c.drvPath) (removeAttrs cs [ "formatting" ])'
}

head="$(drvs "git+file://$PWD")"
# shallow=1 also takes a shallow clone. A base that doesn't evaluate has
# nothing to compare against: build it all.
base="$(drvs "git+file://$PWD?shallow=1&rev=$(git rev-parse "$rev")")" ||
  { echo "warning: checks at $rev don't evaluate; building all" >&2; base='{}'; }
jq -rn --argjson h "$head" --argjson b "$base" \
  '$h | to_entries[] | select($b[.key] != .value) | .key'
