# herdr

[Herdr](https://herdr.dev/)'s desktop app together with herdr-core, from
upstream's prebuilt releases. Nothing is compiled.

- `bin/herdr-app`: a wrapper that starts the app (see below). On macOS the app
  comes from `Herdr.dmg` as `$out/Applications/Herdr.app`, copied untouched
  (`dontFixup`) so its signature holds. On Linux it is upstream's `herdr-app`
  tarball in `libexec/`, patched with autoPatchelf, with a desktop entry and
  icon.
- `bin/herdr-core`, `bin/hc`: herdr-core, which runs the app's terminals and
  agents in the background. The app looks for it on `PATH` (and in
  `~/.local/bin`), so installing this package is enough.

## Update notices

The app updates itself from `releases.herdr.dev`, which can't work from the
read-only store. `bin/herdr-app` (also what the Linux desktop entry runs) sets
`HERDR_RELEASES_URL` to a copy of the pinned release manifests in
`share/herdr/releases`, so the app sees itself as up to date and doesn't
download updates. Adding an ssh machine installs the pinned herdr-core there
too. herdr-core needs nothing: run from the store, it reports itself as managed
by nix and the app leaves it alone.

In the background, at most every 6 hours, the wrapper checks upstream's
`latest.json` and posts a desktop notification (`notify-send` on Linux,
`osascript` on macOS) once per newer release, saying to update through Nix.
State is in `~/.cache/herdr-nix`; `HERDR_NIX_NO_UPDATE_CHECK=1` turns the check
off.

On macOS, opening `Herdr.app` from Finder or the Dock skips the wrapper (the
signed bundle can't be changed), so the app's own updater is back. Start it
with `herdr-app` instead, or set the variable for every app, e.g. in
nix-darwin:

```nix
launchd.user.envVariables.HERDR_RELEASES_URL =
  "file://${pkgs.retvel.herdr}/share/herdr/releases";
```

Systems: `aarch64-darwin` (the dmg is arm64 only), `x86_64-linux`,
`aarch64-linux`.

## Updates

The app and herdr-core are released separately. `update.sh` follows the
versions in `app/latest.json` and `core/latest.json` on `releases.herdr.dev`
and pins the versioned files (`app/<version>/…`, `core/<version>/…`); the
unversioned `app/Herdr.dmg` always serves the latest release. It keeps both
manifests as `app-latest.json` and `core-latest.json` for the wrapper.
`version` is `<app>+core.<core>`, so the update commit names both.

On a bump, check `core_min` in `app/latest.json`: the oldest herdr-core the app
works with. Don't run `hc update` on this herdr-core: it installs into
`~/.local/bin`, outside the Nix store.
