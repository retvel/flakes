# shellcheck shell=bash
# Shared helpers for pkgs/*/update.sh. Source it after `cd "$(dirname "$0")"`:
#   . ../../lib/update.sh
# Needs jq and nix, gh for gh_latest and GitHub release downloads, curl for
# $sums.

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

# prefetch URL [SHA256]: the SRI sha256 of URL's content. Exits unless it
# matches SHA256 (hex, as upstream publishes it) when given, and, for a GitHub
# release asset, the digest GitHub recorded when it was uploaded (releases
# from before GitHub kept digests have none).
prefetch() {
  local url=$1 want=${2:-} hash hex digest
  hash="$(nix store prefetch-file --json "$url" | jq -er .hash)"
  hex="$(nix hash convert --hash-algo sha256 --to base16 "$hash")"
  if [ -n "$want" ] && [ "$hex" != "${want,,}" ]; then
    echo "$url: sha256 $hex, upstream lists $want" >&2; exit 1
  fi
  digest="$(gh_digest "$url")"
  if [ -n "$digest" ] && [ "$hex" != "${digest#sha256:}" ]; then
    echo "$url: sha256 $hex, GitHub's digest is $digest" >&2; exit 1
  fi
  printf '%s\n' "$hash"
}

# gh_digest URL: GitHub's digest (sha256:<hex>) of the release asset behind
# URL; nothing for other URLs or assets without one.
gh_digest() {
  local re='^https://github\.com/([^/]+/[^/]+)/releases/download/([^/]+)/([^/]+)$'
  [[ $1 =~ $re ]] || return 0
  gh api "repos/${BASH_REMATCH[1]}/releases/tags/${BASH_REMATCH[2]}" |
    jq -r --arg n "${BASH_REMATCH[3]}" '.assets[] | select(.name == $n) | .digest // empty'
}

# upstream_sha256 URL: the sha256 upstream lists for URL's file, from $sums:
# the URL of a checksum list (sha256sum's format), or a suffix (".sha256") for
# a checksum file beside each download. Nothing when $sums is unset; exits
# when the file isn't listed.
sums=""
upstream_sha256() {
  local url=$1 name=${1##*/} list want
  [ -n "$sums" ] || return 0
  if [[ $sums == .* ]]; then list="$(curl -fsSL "$url$sums")"; else list="$(curl -fsSL "$sums")"; fi
  want="$(awk -v n="$name" '$2 == n || $2 == "*" n { print $1; exit }' <<<"$list")"
  [[ $want =~ ^[0-9a-fA-F]{64}$ ]] || { echo "$url: no sha256 for $name in ${sums}" >&2; exit 1; }
  printf '%s\n' "$want"
}

# write_hashes VERSION KEY=URL...: prefetch each URL (checked against
# upstream's checksums when $sums says where they are) and write
# { version, hashes: { KEY: hash } } to hashes.json, keys sorted.
write_hashes() {
  local version=$1 hashes='{}' pair hash want
  shift
  for pair in "$@"; do
    want="$(upstream_sha256 "${pair#*=}")"
    hash="$(prefetch "${pair#*=}" "$want")"
    hashes="$(jq --arg k "${pair%%=*}" --arg h "$hash" '. + {($k): $h}' <<<"$hashes")"
  done
  jq -n --arg v "$version" --argjson h "$hashes" \
    '{version: $v, hashes: ($h | to_entries | sort_by(.key) | from_entries)}' > hashes.json
}
