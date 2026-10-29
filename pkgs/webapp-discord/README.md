# webapp-discord

Discord (https://discord.com/app) as a macOS app, built with [Pake](https://github.com/tw93/Pake)
(Tauri + the system WebView). Apple Silicon (`aarch64-darwin`) only; nothing
is compiled on install.

```nix
inputs.retvel.url = "github:retvel/flakes";
home.packages = [ inputs.retvel.packages.${system}.webapp-discord ];
```

The package is `Discord.app` under `Applications/`.

`pake.json` is the app's Pake config (`pake --config`). `.github/workflows/webapp.yml`
builds it with pake-cli on a macOS runner, adds `Discord-<config hash>-aarch64.dmg`
to this repo's "Pake (X.Y.Z)" release (tag `pake-vX.Y.Z`), then pins it in
`hashes.json`. It runs daily
for new pake-cli releases and on any change to `pake.json` or `icon.png`.
Until the first release is pinned, `hashes.json` is empty and the package is
not in `packages`.

`icon.png` is Discord's white Symbol.svg from discord.com/branding on Blurple
(#5865F2), 512x512. `camera` and `microphone` let voice and video calls ask for
access. Desktop-client features (overlay, Krisp noise suppression, game
activity) are not available.
