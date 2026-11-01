#!/usr/bin/env bash
# Bump hashes.json to the latest upstream release. Needs gh, jq and nix.
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source-path=SCRIPTDIR source=../../lib/update.sh
. ../../lib/update.sh

version="$(gh_latest lite-xl lite-xl/lite-xl)"
skip_if_current lite-xl "$version"

write_hashes "$version" \
  macos-arm64.dmg="https://github.com/lite-xl/lite-xl/releases/download/v$version/lite-xl-v$version-addons-macos-arm64.dmg"
echo "lite-xl: $current -> $version"
