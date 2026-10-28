# ghostty

[Ghostty](https://ghostty.org/) from upstream's `Ghostty.dmg`, as
`$out/Applications/Ghostty.app` plus a `bin/ghostty` launcher. Nothing is
compiled: the derivation only unpacks the dmg and copies the signed, notarized
bundle, left untouched (`dontFixup`). Two packages share this `package.nix`:

- `ghostty`: the latest tagged release (`version` in `hashes.json`), from
  `release.files.ghostty.org`. `update.sh` checks daily and picks the newest
  version in upstream's Sparkle appcast.
- `ghostty-tip`: the rolling [`tip`](https://github.com/ghostty-org/ghostty/releases/tag/tip)
  build from main (`version` in `../ghostty-tip/hashes.json`, as
  `<build date>-<short commit>`), bumped daily.

Outputs match nixpkgs' `ghostty-bin` (`man`, `shell_integration`, `terminfo`,
`vim`, copied out of the bundle), so either can replace it, e.g. as Home
Manager's `programs.ghostty.package`.

macOS only (universal binary). On Linux upstream ships source only; use
nixpkgs' `ghostty` or upstream's flake, `github:ghostty-org/ghostty`.

## Notes

- **Auto-update.** The app sits in the read-only Nix store, but its built-in
  updater still checks its channel. Set `auto-update = off` in the Ghostty
  config.
- **Install one.** Stable and tip share the bundle ID `com.mitchellh.ghostty`
  (as does nixpkgs' `ghostty-bin`), so with two installed, macOS may open
  either one (e.g. for `open -b`).
- **Tip pins expire.** Every tip build replaces `Ghostty.dmg` at the same URL,
  so a pinned tip hash only downloads until the next build. After that it only
  builds from a store or cache that already has it. Stay on the daily bump.
  Release dmgs keep their versioned URL.
- **Release hashing.** The file host publishes no checksums, so `update.sh`
  downloads the dmg (~35 MB) to hash it, only when the version changes.
