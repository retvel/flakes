# Upstream's rolling tip build. Same package as pkgs/ghostty; only the download
# and hashes.json (here, bumped daily by update.sh) differ.
{ ghostty }:

ghostty.override { tip = true; }
