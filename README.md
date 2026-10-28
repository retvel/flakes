# Flakes

Nix packages by `Prompter`.

> [!WARNING]
> **DYOR (Do Your Own Research).** These packages are written largely with AI
> agents and provided as-is, without warranty. Upstream binaries are fetched
> from their official release pages and pinned by hash, but that only proves
> the download is unchanged, not that the program is safe. Read the package
> definition and the upstream project before installing, especially anything
> that runs as a system service or with root privileges.

## Packages

| Package | Description |
|---|---|
| [1mcp](pkgs/1mcp) | Unified MCP runtime that aggregates MCP servers behind one endpoint, with a NixOS service module |
| [nh](pkgs/nh) | Nix CLI helper from prebuilt upstream binaries, without Rust compilation |
| [pi](pkgs/pi) | Pi coding agent from published npm packages with Node.js 24 LTS; local assembly, no Pi source compilation |
| [nodejs-24-lts](pkgs/nodejs-24-lts) | Official prebuilt Node.js 24 LTS with independently pinned npm latest; no source compilation |
| [ghostty](pkgs/ghostty) | Ghostty terminal's latest release from upstream's Ghostty.dmg; macOS only, no compilation |
| [ghostty-tip](pkgs/ghostty) | Ghostty's rolling tip build from main, bumped daily |
| [google-chrome](pkgs/google-chrome) | Google Chrome's latest Stable release from Google's signed dmg (unfree); macOS only, no compilation |
| [hermes-agent](pkgs/hermes-agent) | Hermes Agent pinned to upstream's latest stable release tag (`minimal` + telegram, mcp), with upstream's NixOS and Home Manager modules; x86_64 Linux only |
| [littlesnitch](pkgs/littlesnitch) | Little Snitch for Linux network monitor (unfree freeware binary), with a NixOS service module |
| [lite-xl](pkgs/lite-xl) | Lite XL editor from upstream's addons release (language plugins, colour schemes) as Lite XL.app, Apple Silicon only |
| [nullclaw](pkgs/nullclaw) | Small, fully autonomous AI assistant in one static Zig binary, with a nix-darwin/NixOS service module |
| [nullclaw-nightly](pkgs/nullclaw) | NullClaw's rolling nightly build, bumped daily |
| [nullclaw-chat-ui](pkgs/nullclaw-chat-ui) | NullClaw's web chat UI as static files, to serve from any web server |
| [rayfish](pkgs/rayfish) | P2P mesh VPN (iroh), with a nix-darwin/NixOS service module |
| [utm](pkgs/utm) | UTM virtual machine host for macOS from the upstream release dmg, no compilation |

## Usage

```nix
{
  inputs.retvel.url = "github:retvel/flakes";
  inputs.retvel.inputs.nixpkgs.follows = "nixpkgs";

  # Either take packages straight from the flake (pinned nixpkgs) ...
  environment.systemPackages = [ inputs.retvel.packages.${system}.rayfish ];

  # ... or build them against your own nixpkgs through the overlay.
  nixpkgs.overlays = [ inputs.retvel.overlays.default ];
  environment.systemPackages = [ pkgs.retvel.rayfish ];

  # Packages with a service module:
  modules = [ inputs.retvel.darwinModules.rayfish ];  # or nixosModules
}
```

Or run one without installing: `nix run github:retvel/flakes#rayfish -- --version`.

## Outputs

- `packages.<system>.<name>`: only packages that build on `<system>`
- `overlays.default`: adds `pkgs.retvel.<name>`
- `darwinModules.<name>`, `nixosModules.<name>`: for packages that have a
  `module.nix` (both), `darwin-module.nix` or `nixos-module.nix` (one only)
- `homeManagerModules.<name>`: for packages that have a `home-module.nix`
- `checks.<system>.<name>`: builds every package
- `formatter`: `nixfmt`

Systems: `aarch64-darwin`, `aarch64-linux`, `x86_64-linux`.

## Updates

`.github/workflows/update.yml` runs twice a day (03:17 and 15:17 UTC). For each
`pkgs/<name>/update.sh`, it runs the script. If files changed, it builds every
Linux package and commits `Update <name> to vX.Y.Z` to `main`. Run it from the
Actions tab to update a single package.

CI pushes only `hermes-agent` (its runtime closure, built on x86_64 Linux) to
`retvel.cachix.org`; every other package builds or downloads from upstream.

## License

Each packaged program keeps its own license, set by its authors. All product
names, logos and trademarks belong to their respective owners and creators.
This repository is not affiliated with or endorsed by them.
