# webapp-claude

Claude (https://claude.ai) as a desktop app, built with [Pake](https://github.com/tw93/Pake)
(Tauri + the system WebView). Supported systems: `aarch64-darwin`,
`aarch64-linux`, and `x86_64-linux`.

```nix
inputs.retvel.url = "github:retvel/flakes";
environment.systemPackages = [ inputs.retvel.packages.${system}.webapp-claude ];
```

The overlay also provides `pkgs.retvel.webapp-claude`. On macOS the app is
`Claude.app` under `Applications/` in the package; on Linux, `bin/webapp-claude`
plus a desktop entry named Claude.

The build is `lib/pake-webapp.nix`: it applies `package.nix`'s settings to
Pake's release source the way `pake <url>` would, then compiles it with
`cargo tauri build` (several minutes, unlike most packages here). `window` in
`package.nix` takes the field names of Pake's `src-tauri/pake.json`.

Sign in with email: Google blocks sign-in inside embedded WebViews. Anthropic
ships an official Claude desktop app for macOS and Windows; this is a lighter
wrapper that also runs on Linux.

`update.sh` follows Pake's latest GitHub release through
`lib/pake-webapp-update.sh`. On a bump, check that the `jq` edits in
`lib/pake-webapp.nix` still match Pake's `pake.json` and `tauri*.conf.json`.
