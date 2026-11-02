# helium

[Helium](https://helium.computer/) from upstream's release dmg
(`imputnet/helium-macos`), as `$out/Applications/Helium.app` plus a
`bin/helium` launcher. Nothing is compiled: the derivation only unpacks the dmg
for the system's architecture and copies the signed, notarized bundle, left
untouched (`dontFixup`). nixpkgs has no Helium, and the community flakes wrap
the Linux AppImage only. `update.sh` bumps it to the latest upstream
(non-pre-)release.

macOS only (Apple Silicon and Intel dmgs, macOS 13+). Home Manager and
nix-darwin link `Applications/*.app` into the usual app folders.

## Updates

Helium updates itself through Sparkle, which can't replace a bundle in the
read-only Nix store. The bundle can't be changed without breaking its
signature, so turn the updater off in the app: the updates toggle on the
Helium services page of the privacy settings, or the profile preference
`helium.services.browser_updates = false` (in `<profile>/Preferences`; on by
default, registered by upstream's `add-updater-preference.patch`). Bump with
`nix flake update` instead.

On a bump, recheck that the bundle is still `Helium.app` with executable
`Helium`, and that the dmg names still follow
`helium_<version>_{arm64,x86_64}-macos.dmg`.
