#!/usr/bin/env bash
# Bump hashes.json to the latest Stable Chrome for macOS. The target version is
# the newest release Google serves to at least half of Stable users
# (versionhistory API); the download URL comes from Google's update server
# (Omaha). Asked as an on-demand check ("Check for updates" in About Chrome) it
# skips the staged rollout; it is still asked until it serves the target. Never downgrades. Downloads the
# dmg (~280 MB) on a bump to hash it. Needs curl, jq, uuidgen and nix.
set -euo pipefail
cd "$(dirname "$0")"

releases="https://versionhistory.googleapis.com/v1/chrome/platforms/mac/channels/stable/versions/all/releases"
version="$(curl -fsS "$releases?filter=endtime=none,fraction%3E=0.5&order_by=version%20desc" \
  | jq -r '.releases[0].version // empty')"
[ -n "$version" ] || { echo "google-chrome: no Stable release in versionhistory" >&2; exit 1; }

current="$(jq -r .version hashes.json)"
[ "$version" != "$current" ] || { echo "google-chrome: $current is latest"; exit 0; }
newest="$(printf '%s\n%s\n' "$current" "$version" | sort -V | tail -n1)"
[ "$newest" = "$version" ] || { echo "google-chrome: $current is newer than Stable $version"; exit 0; }

url=""
for _ in $(seq 1 10); do
  id="$(uuidgen)"
  response="$(curl -fsS -X POST -H 'Content-Type: text/xml' \
    --data "<?xml version='1.0' encoding='UTF-8'?>
<request protocol='3.0' ismachine='1' installsource='ondemandcheckforupdate'
  sessionid='{$id}' requestid='{$id}'>
  <os platform='mac' version='15.0' arch='arm64'/>
  <app appid='com.google.Chrome' version='' lang='' brand='GGLS'><updatecheck/></app>
</request>" https://tools.google.com/service/update2)"
  served="$(grep -oE "<manifest version=['\"][0-9.]+" <<<"$response" | grep -oE '[0-9.]+$' || true)"
  if [ "$served" = "$version" ]; then
    base="$(grep -oE "codebase=['\"]https://dl\.google\.com/release2/[^'\"]+" <<<"$response" \
      | head -n1 | sed -E "s/codebase=['\"]//")"
    pkg="$(grep -oE "<package [^>]*name=['\"][^'\"]+\.dmg" <<<"$response" | sed -E "s/.*name=['\"]//")"
    [ -n "$base" ] && [ -n "$pkg" ] && url="$base$pkg" && break
  fi
  sleep 3
done
[ -n "$url" ] || { echo "google-chrome: update server doesn't serve $version yet; skipping"; exit 0; }

hash="$(nix store prefetch-file --json "$url" | jq -r .hash)"
jq -n --arg v "$version" --arg u "$url" --arg h "$hash" \
  '{version: $v, url: $u, hashes: {"GoogleChrome.dmg": $h}}' > hashes.json
echo "google-chrome: $current -> $version"
