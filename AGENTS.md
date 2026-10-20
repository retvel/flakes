# AGENTS.md

Guidance for coding agents working in this repo. `README.md` is the user-facing
doc; keep it and each package's README in sync with behavior. Remote:
`retvel/flakes`.

## Layout

See `LAYOUT.md`; keep it in sync when adding a kind of file or workflow.

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
