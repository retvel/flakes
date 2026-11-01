# Layout

| Path | Role |
|---|---|
| `SECURITY.md` | How to report a vulnerability, and the trust model: what pins, checks and sandboxes do and don't cover. Keep it in sync with the workflows, `lib/` and the modules. |
| `flake.nix` | Discovers `pkgs/*/package.nix` and the module files; builds all packages in one `makeScope` so they can depend on each other by argument name; filters `packages.<system>` with `lib.meta.availableOn`, except for the packages in `fixedPlatforms` (they fetch Hermes' flake when evaluated). `checks` builds every package but the `rolling` ones (`ghostty-tip`, whose pin expires with each upstream build) and adds `formatting` (`nixfmt --check`) and, on Linux, `nixos-modules` (a NixOS system with every NixOS module enabled, evaluated). |
| `overlays/default.nix` | `pkgs.xr3t.<name>`, built against the consumer's nixpkgs. |
| `pkgs/<name>/package.nix` | The derivation. Read `version`/hashes from `hashes.json` for prebuilt binaries. |
| `pkgs/<name>/hashes.json` | `{ "version": ..., "hashes": { "<key>": "sha256-..." } }`, written by `update.sh`. Keys are whatever the package looks up (usually the system). Exception: `hermes-agent` pins an upstream flake as `{ version, rev, narHash }`, and `cua-driver` has none: it reads version, URL and hash from that Hermes commit's `pm/lock.json`. |
| `pkgs/<name>/update.sh` | Optional. Bumps `hashes.json` to the latest upstream; no-op when current. Run by `.github/workflows/update.yml`. Sources `lib/update.sh`. |
| `lib/hardening.nix` | The systemd sandboxing the opt-in `hardening.enable` options share (`serviceConfig`); each module adds what its service can live without. Modules otherwise run services as upstream's installer does. |
| `lib/update.sh` | Helpers for `update.sh`: `check_version` (rejects unexpected upstream versions), `gh_latest`, `skip_if_current`, `prefetch`, `write_hashes`. |
| `pkgs/<name>/module.nix` | Optional. `self: { config, ... }: { ... }`; exported as both `darwinModules.<name>` and `nixosModules.<name>`. Default package is `self.packages.${system}.<name>`. |
| `pkgs/<name>/nixos-module.nix`, `darwin-module.nix` | Same shape as `module.nix`, exported only to `nixosModules` or `darwinModules`. |
| `pkgs/<name>/home-module.nix` | Same shape, exported as `homeManagerModules.<name>`. |
| `pkgs/<name>/README.md` | Optional. The package's usage, options and maintenance notes. |
| `.github/workflows/check.yml` | `nix flake check` on Linux x86_64/aarch64 and macOS, read-only token; only on `main` the x86_64 job pushes `hermes-agent` (only) to ret.cachix.org. |
| `.github/workflows/update.yml` | Twice daily (03:17, 15:17 UTC), one run at a time: runs every `update.sh`, checks the flake, commits `Update <name> to vX.Y.Z` to `main`, or for the packages in `REVIEW` opens a pull request from `update/<name>` and starts `check.yml` on it; on Monday's first run (or when asked for) updates the `nixpkgs` input the same way, always as a pull request (`update/nixpkgs`); then pushes `hermes-agent` to ret.cachix.org. |
| `.github/dependabot.yml` | Weekly bumps of the actions, which workflows pin by commit SHA. |
