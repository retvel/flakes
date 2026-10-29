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
builds it with pake-cli on a macOS runner, uploads `Discord-aarch64.dmg` to this
repo's "Pake (X.Y.Z)" release (tag `pake-vX.Y.Z`), then pins it in
`hashes.json`. A config change replaces the dmg in that release, so pins from
before it fail their hash check until updated. It runs daily
for new pake-cli releases and on any change to `pake.json` or `icon.png`.
Until the first release is pinned, `hashes.json` is empty and the package is
not in `packages`.

`icon.png` is Discord's white Symbol.svg from discord.com/branding on Blurple
(#5865F2), with a white "W" with a black outline (JetBrains Mono, OFL) in the
middle.

`camera` and `microphone` let voice and video calls ask for access. Desktop-client features (overlay, Krisp noise suppression, game
activity) are not available.

`safeDomain` keeps Discord's own domains (invites on discord.gg, attachments on
discordapp.com and discordapp.net, gifts) in the app; other links open in the
default browser.
