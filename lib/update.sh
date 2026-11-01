# shellcheck shell=bash
# Shared helpers for pkgs/*/update.sh. Source it after `cd "$(dirname "$0")"`:
#   . ../../lib/update.sh
# Needs jq and nix, and gh for gh_latest.

# Command substitutions such as version="$(gh_latest ...)" stop at the first
# failing command too.
shopt -s inherit_errexit

# check_version NAME VERSION [REGEX]: exit unless VERSION matches REGEX
# (default: a dotted release version such as 1.2.3). Upstream's version ends up
# in URLs, hashes.json and commit messages, so it may never carry a slash,
# whitespace or quotes, whatever REGEX allows.
check_version() {
  local name=$1 version=$2 re=${3:-'^[0-9]+(\.[0-9]+){1,3}$'}
  [[ $version =~ ^[0-9A-Za-z][0-9A-Za-z.+-]{0,63}$ && $version =~ $re ]] ||
    { echo "$name: unexpected version '$version'" >&2; exit 1; }
}

# gh_latest NAME REPO: the version of REPO's latest release (never a draft or
# prerelease), without the tag's "v", checked with check_version.
gh_latest() {
  local tag
  tag="$(gh release view -R "$2" --json tagName -q .tagName)"
  check_version "$1" "${tag#v}"
  printf '%s\n' "${tag#v}"
}

# skip_if_current NAME VERSION: exit 0 when hashes.json already pins VERSION.
# Sets $current to the pinned version ("none" without hashes.json).
skip_if_current() {
  current="$(jq -r '.version // "none"' hashes.json 2>/dev/null || echo none)"
  [ "$2" != "$current" ] || { echo "$1: $current is latest"; exit 0; }
}

# prefetch URL: the SRI sha256 of URL's content.
prefetch() {
  nix store prefetch-file --json "$1" | jq -er .hash
}

# write_hashes VERSION KEY=URL...: prefetch each URL and write
# { version, hashes: { KEY: hash } } to hashes.json, keys sorted.
write_hashes() {
  local version=$1 hashes='{}' pair hash
  shift
  for pair in "$@"; do
    hash="$(prefetch "${pair#*=}")"
    hashes="$(jq --arg k "${pair%%=*}" --arg h "$hash" '. + {($k): $h}' <<<"$hashes")"
  done
  jq -n --arg v "$version" --argjson h "$hashes" \
    '{version: $v, hashes: ($h | to_entries | sort_by(.key) | from_entries)}' > hashes.json
}
