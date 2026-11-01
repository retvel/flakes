# google-chrome

Google Chrome's latest Stable release for macOS, from Google's signed,
notarized universal dmg, installed untouched as
`$out/Applications/Google Chrome.app` with a `bin/google-chrome` wrapper.
Nothing is compiled. Unfree: this flake's own `packages` allow it; through the
overlay, allow `google-chrome` in your nixpkgs config.

## Updates

`update.sh` takes the newest version Google serves to at least half of Stable
users (the versionhistory API) and its download URL from Google's update
server, and never downgrades. It downloads the dmg (~280 MB) to hash it.

Chrome's own updater can't replace the copy in the read-only Nix store, so
updates come from this flake (`nix flake update xr3t`). Chrome may still
install Google's updater under `~/Library` on first launch and show an update
notice; that copy is not what runs.

On Linux use nixpkgs' `google-chrome`.
