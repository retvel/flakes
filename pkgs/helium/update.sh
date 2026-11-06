#!/usr/bin/env bash
# Bump hashes.json to the latest release upstream has published for both
# macOS (imputnet/helium-macos) and Linux (imputnet/helium-linux): they release
# from separate repositories, usually the same version, and one hashes.json
# pins one version. Downloads the Apple Silicon dmg (~115 MB) and both Linux
# tarballs (~120 MB each) on a bump to hash them. Needs gh, jq and nix.
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source-path=SCRIPTDIR source=../../lib/update.sh
. ../../lib/update.sh

# gh_latest skips pre-releases. Helium's tags have no "v". Until the other
# repository catches up, the older of the two latest releases is the newest
# both have.
macos="$(gh_latest helium imputnet/helium-macos)"
linux="$(gh_latest helium imputnet/helium-linux)"
version="$(printf '%s\n' "$macos" "$linux" | sort -V | head -n 1)"
skip_if_current helium "$version"

mac="https://github.com/imputnet/helium-macos/releases/download/$version"
lin="https://github.com/imputnet/helium-linux/releases/download/$version"
write_hashes "$version" \
  aarch64-darwin="$mac/helium_${version}_arm64-macos.dmg" \
  aarch64-linux="$lin/helium-$version-arm64_linux.tar.xz" \
  x86_64-linux="$lin/helium-$version-x86_64_linux.tar.xz"
echo "helium: $current -> $version"
