# claude-pake

[claude.ai](https://claude.ai) as a desktop app, built with
[Pake](https://github.com/tw93/Pake) (Tauri + the system WebView). Supported
systems: `aarch64-darwin`, `aarch64-linux`, and `x86_64-linux`.

```nix
inputs.retvel.url = "github:retvel/flakes";
environment.systemPackages = [ inputs.retvel.packages.${system}.claude-pake ];
```

The overlay also provides `pkgs.retvel.claude-pake`. On macOS the app is
`Claude.app` under `Applications/` in the package; on Linux, `bin/pake` plus a
desktop entry named Claude.

## How it's built

Pake's CLI (`pake https://claude.ai ...`) needs the network at build time, so
this package skips it. It takes Pake's release source and makes the same edits
the CLI would make to `src-tauri/pake.json` and the `tauri*.conf.json` files,
then runs `cargo tauri build`. The result matches:

```sh
pake https://claude.ai --name Claude --identifier com.pake.claude \
  --width 1280 --height 860 --hide-title-bar --enable-find --new-window
```

The window settings are the `window` attribute set in `package.nix`, using the
field names in Pake's `src-tauri/pake.json`. Unlike most packages here, this
one compiles Rust: the first build takes several minutes.

`icon.png` is claude.ai's `apple-touch-icon.png`; `cargo tauri icon` turns it
into the platform icons.

## Notes

- Sign in with email. Google blocks sign-in inside embedded WebViews.
- Anthropic ships an official Claude desktop app for macOS and Windows; this
  package is a lighter wrapper and also works on Linux.

## Updating

`update.sh` follows Pake's latest GitHub release: it sets the version and
source hash, then gets `cargoHash` by building `claude-pake.cargoDeps` against a
fake hash. On a bump, check that the `jq` edits in `postPatch` still match
Pake's `pake.json` and `tauri*.conf.json` layout.
