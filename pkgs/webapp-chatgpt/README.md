# webapp-chatgpt

ChatGPT (https://chatgpt.com) as a macOS app, built with [Pake](https://github.com/tw93/Pake)
(Tauri + the system WebView). Apple Silicon (`aarch64-darwin`) only; nothing
is compiled on install.

```nix
inputs.retvel.url = "github:retvel/flakes";
home.packages = [ inputs.retvel.packages.${system}.webapp-chatgpt ];
```

The package is `ChatGPT.app` under `Applications/`.

`pake.json` is the app's Pake config (`pake --config`). `.github/workflows/webapp.yml`
builds it with pake-cli on a macOS runner, uploads `ChatGPT-aarch64.dmg` to this
repo's "Pake (X.Y.Z)" release (tag `pake-vX.Y.Z`), then pins it in
`hashes.json`. A config change replaces the dmg in that release, so pins from
before it fail their hash check until updated. It runs daily
for new pake-cli releases and on any change to `pake.json` or `icon.png`.
Until the first release is pinned, `hashes.json` is empty and the package is
not in `packages`.

`icon.png` is ChatGPT's own `apple-touch-icon` from cdn.oaistatic.com,
unchanged apart from a white "W" with a black outline (JetBrains Mono, OFL) in
the middle.

Google, Apple and Microsoft sign-in may be blocked inside the embedded
WebView; email sign-in works.
