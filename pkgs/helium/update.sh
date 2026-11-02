#!/usr/bin/env bash
# Bump hashes.json to the latest upstream release. Downloads both dmgs (~230 MB)
# on a bump to hash them. Needs gh, jq and nix.
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source-path=SCRIPTDIR source=../../lib/update.sh
. ../../lib/update.sh

# gh_latest skips pre-releases. Helium's tags have no "v".
version="$(gh_latest helium imputnet/helium-macos)"
skip_if_current helium "$version"

base="https://github.com/imputnet/helium-macos/releases/download/$version"
write_hashes "$version" \
  aarch64-darwin="$base/helium_${version}_arm64-macos.dmg" \
  x86_64-darwin="$base/helium_${version}_x86_64-macos.dmg"
echo "helium: $current -> $version"
