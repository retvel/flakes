#!/usr/bin/env bash
# Bump hashes.json to trycua/cua's latest cua-driver release. The repository
# releases other programs too: only tags cua-driver-rs-v<version> count.
# Needs curl, gh, jq and nix.
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source-path=SCRIPTDIR source=../../lib/update.sh
. ../../lib/update.sh

prefix=cua-driver-rs-v
tag="$(gh release list -R trycua/cua --exclude-drafts --exclude-pre-releases --limit 100 \
  --json tagName -q "[.[].tagName | select(startswith(\"$prefix\"))][0] // \"\"")"
version="${tag#"$prefix"}"
check_version cua-driver "$version"
skip_if_current cua-driver "$version"

base="https://github.com/trycua/cua/releases/download/$prefix$version"
# One checksum list per release, sha256sum's format.
sums="$base/SHA256SUMS"
write_hashes "$version" \
  aarch64-linux="$base/cua-driver-rs-$version-linux-arm64-binary.tar.gz" \
  x86_64-linux="$base/cua-driver-rs-$version-linux-x86_64-binary.tar.gz"
echo "cua-driver: $current -> $version"
