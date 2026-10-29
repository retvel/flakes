# webapp-claude

Claude (https://claude.ai) as a macOS app, built with [Pake](https://github.com/tw93/Pake)
(Tauri + the system WebView). Apple Silicon (`aarch64-darwin`) only; nothing
is compiled on install.

```nix
inputs.retvel.url = "github:retvel/flakes";
home.packages = [ inputs.retvel.packages.${system}.webapp-claude ];
```

The package is `Claude.app` under `Applications/`.

`pake.json` is the app's Pake config (`pake --config`). `.github/workflows/webapp.yml`
builds it with pake-cli on a macOS runner and publishes `Claude-aarch64.dmg` as a
release of this repo, then pins the release in `hashes.json`. It runs daily
for new pake-cli releases and on any change to `pake.json` or `icon.png`.
Until the first release is pinned, `hashes.json` is empty and the package is
not in `packages`.

`icon.png` is claude.ai's `apple-touch-icon.png`. Sign in with email: Google
blocks sign-in inside embedded WebViews.
