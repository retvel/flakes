# Layout

| Path | Role |
|---|---|
| `flake.nix` | Discovers `pkgs/*/package.nix` and the module files; builds all packages in one `makeScope` so they can depend on each other by argument name; filters `packages.<system>` with `lib.meta.availableOn`. |
| `overlays/default.nix` | `pkgs.retvel.<name>`, built against the consumer's nixpkgs. |
| `pkgs/<name>/package.nix` | The derivation. Read `version`/hashes from `hashes.json` for prebuilt binaries. |
| `pkgs/<name>/hashes.json` | `{ "version": ..., "hashes": { "<key>": "sha256-..." } }`, written by `update.sh`. Keys are whatever the package looks up (usually the system). Exception: `hermes-agent` pins an upstream flake as `{ version, rev, narHash }`. |
| `pkgs/<name>/update.sh` | Optional. Bumps `hashes.json` to the latest upstream; no-op when current. Run by `.github/workflows/update.yml`. |
| `pkgs/<name>/module.nix` | Optional. `self: { config, ... }: { ... }`; exported as both `darwinModules.<name>` and `nixosModules.<name>`. Default package is `self.packages.${system}.<name>`. |
| `pkgs/<name>/nixos-module.nix`, `darwin-module.nix` | Same shape as `module.nix`, exported only to `nixosModules` or `darwinModules`. |
| `pkgs/<name>/home-module.nix` | Same shape, exported as `homeManagerModules.<name>`. |
| `pkgs/<name>/README.md` | Optional. The package's usage, options and maintenance notes. |
| `.github/workflows/check.yml` | `nix flake check` on Linux x86_64/aarch64 and macOS; the x86_64 job pushes `hermes-agent` (only) to retvel.cachix.org. |
| `.github/workflows/update.yml` | Twice daily (03:17, 15:17 UTC): runs every `update.sh`, checks the flake, commits `Update <name> to vX.Y.Z` to `main`, then pushes `hermes-agent` to retvel.cachix.org. |
