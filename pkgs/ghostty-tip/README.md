# ghostty-tip

[Ghostty](https://ghostty.org/)'s rolling [`tip`](https://github.com/ghostty-org/ghostty/releases/tag/tip)
build from upstream's `Ghostty.dmg`, as `$out/Applications/Ghostty.app` plus a
`bin/ghostty` launcher. Nothing is compiled: the derivation only unpacks the dmg
and copies the signed, notarized bundle, left untouched (`dontFixup`).
`update.sh` bumps it daily; the version is `<build date>-<short commit>`.

Outputs match nixpkgs' `ghostty-bin` (`man`, `shell_integration`, `terminfo`,
`vim`, copied out of the bundle), so it can replace it, e.g. as Home Manager's
`programs.ghostty.package`.

macOS only (universal binary). On Linux, tip ships only as source; use
upstream's flake, `github:ghostty-org/ghostty`.

## Notes

- **Pins expire.** Every tip build replaces `Ghostty.dmg` at the same URL, so a
  pinned hash only downloads until the next build. After that it only builds
  from a store or cache that already has it. Stay on the daily bump.
- **Auto-update.** The app sits in the read-only Nix store, but its built-in
  updater still checks the tip channel. Set `auto-update = off` in the Ghostty
  config.
- **Don't install next to stable.** The bundle ID is `com.mitchellh.ghostty`,
  same as the stable release, so with `ghostty-bin` installed too, macOS may
  open either one (e.g. for `open -b`). Pick one.
