# herdr

[Herdr](https://herdr.dev/)'s desktop app together with herdr-core, from
upstream's prebuilt releases. Nothing is compiled.

- `bin/herdr-app`: the app. On macOS it comes from `Herdr.dmg` as
  `$out/Applications/Herdr.app`, copied untouched (`dontFixup`) so its
  signature holds. On Linux it is upstream's `herdr-app` tarball, patched with
  autoPatchelf, with a desktop entry and icon.
- `bin/herdr-core`, `bin/hc`: herdr-core, which runs the app's terminals and
  agents in the background. The app looks for it on `PATH` (and in
  `~/.local/bin`), so installing this package is enough.

Systems: `aarch64-darwin` (the dmg is arm64 only), `x86_64-linux`,
`aarch64-linux`.

## Updates

The app and herdr-core are released separately. `update.sh` follows the
versions in `app/latest.json` and `core/latest.json` on `releases.herdr.dev`
and pins the versioned files (`app/<version>/…`, `core/<version>/…`); the
unversioned `app/Herdr.dmg` always serves the latest release. `version` is
`<app>+core.<core>`, so the update commit names both.

On a bump, check `core_min` in `app/latest.json`: the oldest herdr-core the app
works with. herdr-core's own `hc update` and the app's "Update herdr-core" write
to `~/.local/bin`, outside the Nix store; update through this package instead.
