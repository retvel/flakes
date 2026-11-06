#!/usr/bin/env bash
# Bump hashes.json to trycua/cua's latest cua-driver release. The repository
# releases other programs too: only tags cua-driver-rs-v<version> count.
# Needs curl, gh, git, jq and nix.
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source-path=SCRIPTDIR source=../../lib/update.sh
. ../../lib/update.sh

# The repository makes so many releases that the last cua-driver one can
# fall outside any page of `gh release list`: take the tags from git instead,
# newest first, and the first with a published release that carries its
# SHA256SUMS (a tag can come before its release). Upstream marks its stable
# cua-driver releases as prereleases, so, as its installer does, the tag's
# x.y.z form is what makes a release stable, not that flag; nightlies are
# tagged nightly-cua-driver-rs-v*.
prefix=cua-driver-rs-v
version=""
for tag in $(git ls-remote --tags --refs https://github.com/trycua/cua "refs/tags/$prefix*" |
  sed -n "s|.*refs/tags/\($prefix[0-9]*\.[0-9]*\.[0-9]*\)\$|\1|p" | sort -rV | head -n 10); do
  if ready="$(gh release view "$tag" -R trycua/cua --json isDraft,assets \
    -q '(.isDraft | not) and any(.assets[]; .name == "SHA256SUMS")' 2>/dev/null)" &&
    [ "$ready" = true ]; then
    version="${tag#"$prefix"}"
    break
  fi
done
check_version cua-driver "$version"
skip_if_current cua-driver "$version"

base="https://github.com/trycua/cua/releases/download/$prefix$version"
# One checksum list per release, sha256sum's format.
sums="$base/SHA256SUMS"
write_hashes "$version" \
  aarch64-linux="$base/cua-driver-rs-$version-linux-arm64-binary.tar.gz" \
  x86_64-linux="$base/cua-driver-rs-$version-linux-x86_64-binary.tar.gz"
echo "cua-driver: $current -> $version"
