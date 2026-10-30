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

## Usage

Through the module (nix-darwin or NixOS), which also covers launches from
Finder, the Dock or a desktop entry:

```nix
{
  imports = [ inputs.retvel.darwinModules.herdr ];  # or nixosModules
  programs.herdr.enable = true;
}
```

| Option | Default | |
|---|---|---|
| `programs.herdr.enable` | `false` | Install the package and set up the below |
| `programs.herdr.package` | this flake's `herdr` | |
| `programs.herdr.updateCheck.enable` | `true` | Timer for update notifications |

## Update notices

The app updates itself from `releases.herdr.dev`, which can't work from the
read-only store. Pointing `HERDR_RELEASES_URL` at a copy of the pinned release
manifests (`share/herdr/releases`) makes the app see itself as up to date, so
it doesn't download updates; adding an ssh machine then installs the pinned
herdr-core there too. herdr-core needs nothing: run from the store, it reports
itself as managed by nix and the app leaves it alone.

`bin/herdr-update-check` tells about newer releases instead: it reads
upstream's `latest.json` and posts a desktop notification (`notify-send` on
Linux, `osascript` on macOS) once per newer release, saying to update through
Nix. It checks at most every 5 hours, keeps its state in `~/.cache/herdr-nix`,
and does nothing with `HERDR_NIX_NO_UPDATE_CHECK=1`.

- The module sets `HERDR_RELEASES_URL` for every launch: launchd's user
  environment on macOS (`launchd.user.envVariables`), the session variables
  on NixOS. It runs `herdr-update-check` at login and every 6 hours from a
  launchd agent or a systemd user timer.
- Without the module, `bin/herdr-app` (also what the Linux desktop entry runs)
  sets the variable and runs the check on each start. On macOS, opening
  `Herdr.app` from Finder or the Dock skips it (the signed bundle can't be
  changed), so the app's own updater is back; use the module there.

After enabling the module, quit and reopen Herdr so it starts with the
variable (on NixOS, log in again first: session variables are read at login).

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
