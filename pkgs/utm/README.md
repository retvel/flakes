# utm

[UTM](https://mac.getutm.app/) from upstream's release `UTM.dmg`, as
`$out/Applications/UTM.app` plus `bin/UTM` and `bin/utmctl` launchers. Nothing
is compiled: the derivation only unpacks the dmg and copies the signed,
notarized bundle, left untouched (`dontFixup`). Unlike nixpkgs' `utm`, which
lags upstream, `update.sh` bumps it to the latest upstream (non-pre-)release.

macOS only (universal binary, macOS 12+). Home Manager and nix-darwin link
`Applications/*.app` into the usual app folders.
