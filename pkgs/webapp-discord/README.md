# webapp-discord

Discord (https://discord.com/app) as a desktop app, built with [Pake](https://github.com/tw93/Pake)
(Tauri + the system WebView). Supported systems: `aarch64-darwin`,
`aarch64-linux`, and `x86_64-linux`.

```nix
inputs.retvel.url = "github:retvel/flakes";
environment.systemPackages = [ inputs.retvel.packages.${system}.webapp-discord ];
```

The overlay also provides `pkgs.retvel.webapp-discord`. On macOS the app is
`Discord.app` under `Applications/` in the package; on Linux, `bin/webapp-discord`
plus a desktop entry named Discord.

The build is `lib/pake-webapp.nix`: it applies `package.nix`'s settings to
Pake's release source the way `pake <url>` would, then compiles it with
`cargo tauri build` (several minutes, unlike most packages here). `window` in
`package.nix` takes the field names of Pake's `src-tauri/pake.json`.

Discord's web client in the system WebView: no Discord desktop app features
such as Krisp noise suppression, game activity or overlay. Voice and video
depend on WebRTC support in WKWebView (macOS) or WebKitGTK (Linux); screen
sharing may not work on Linux.

`update.sh` follows Pake's latest GitHub release through
`lib/pake-webapp-update.sh`. On a bump, check that the `jq` edits in
`lib/pake-webapp.nix` still match Pake's `pake.json` and `tauri*.conf.json`.
