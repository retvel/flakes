#!/usr/bin/env bash
# Bump hashes.json to the latest upstream release. Needs gh, jq and nix.
set -euo pipefail
cd "$(dirname "$0")"
. ../../lib/update.sh

# gh_latest skips pre-releases.
version="$(gh_latest utm utmapp/UTM)"
skip_if_current utm "$version"

write_hashes "$version" \
  UTM.dmg="https://github.com/utmapp/UTM/releases/download/v$version/UTM.dmg"
echo "utm: $current -> $version"
