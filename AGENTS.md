# AGENTS.md

Guidance for coding agents working in this repo. `README.md` is the user-facing
doc; keep it and each package's README in sync with behavior. Remote:
`retpel/flakes`.

## Layout

| Path | Role |
|---|---|
| `flake.nix` | Discovers `pkgs/*/package.nix` and the module files; builds all packages in one `makeScope` so they can depend on each other by argument name; filters `packages.<system>` with `lib.meta.availableOn`. |
| `overlays/default.nix` | `pkgs.retpel.<name>`, built against the consumer's nixpkgs. |
| `pkgs/<name>/package.nix` | The derivation. Read `version`/hashes from `hashes.json` for prebuilt binaries. |
| `pkgs/<name>/hashes.json` | `{ "version": ..., "hashes": { "<key>": "sha256-..." } }`, written by `update.sh`. Keys are whatever the package looks up (usually the system). |
| `pkgs/<name>/update.sh` | Optional. Bumps `hashes.json` to the latest upstream; no-op when current. Run by `.github/workflows/update.yml`. |
| `pkgs/<name>/module.nix` | Optional. `self: { config, ... }: { ... }`; exported as both `darwinModules.<name>` and `nixosModules.<name>`. Default package is `self.packages.${system}.<name>`. |
| `pkgs/<name>/nixos-module.nix`, `darwin-module.nix` | Same shape as `module.nix`, exported only to `nixosModules` or `darwinModules`. |
| `.github/workflows/check.yml` | `nix flake check` on Linux x86_64/aarch64 and macOS. |

## Adding a package

1. `pkgs/<name>/package.nix` (+ `hashes.json` and `update.sh` if it tracks upstream releases).
2. Set `meta.platforms` to the systems it really supports; that's what filters `packages.<system>`.
3. Add a row to the README package table and a `pkgs/<name>/README.md` if it has options.
   Package-specific notes (gotchas, what to recheck on a bump) go in that README
   or as comments in the package's own files, not in this file.
4. `git add` new files; flakes ignore untracked files.

## Checking changes

```sh
nix flake check --all-systems --no-build   # evaluate everything
nix flake check                            # build this host's packages
nix build .#<name> && ./result/bin/<prog> --version
```

Only `aarch64-darwin` builds locally; Linux is exercised by CI. To test in the
system config, point the input in `/etc/nix-darwin` at this checkout and run
`nh darwin build`. Only run `nh darwin switch` when asked.

## Commits

Short imperative subject lines with no prefix. The update workflow commits as
`Update <name> to vX.Y.Z`.
