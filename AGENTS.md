# AGENTS.md

Guidance for coding agents working in this repo. `README.md` is the user-facing
doc; keep it and each package's README in sync with behavior. Remote:
`retvel/flakes`.

## Layout

See `LAYOUT.md`; keep it in sync when adding a kind of file or workflow.

## Adding a package

1. `pkgs/<name>/package.nix` (+ `hashes.json` and `update.sh` if it tracks upstream releases).
   `update.sh` sources `lib/update.sh` and passes every upstream version
   through `check_version`. If the package runs as root or acts with the
   user's access, add it to `REVIEW` in `.github/workflows/update.yml`.
2. Set `meta.platforms` to the systems it really supports; that's what filters `packages.<system>`.
   If evaluating it fetches another flake, also list it in `fixedPlatforms` in
   `flake.nix`.
3. Add a row to the README package table and a `pkgs/<name>/README.md` if it has options.
   Package-specific notes (gotchas, what to recheck on a bump) go in that README
   or as comments in the package's own files, not in this file.
4. `git add` new files; flakes ignore untracked files.

## Modules

Run a package and its service as upstream's own installer does (its unit or
plist, recheck it on a bump), with the binary in the store: Nix makes it
declarative, it doesn't change how it behaves. Two things go through Nix
instead: updates (self-update and update checks off) and telemetry (off by
default, through upstream's own switch, which the user can set back).
Anything else beyond upstream, such as a sandbox it doesn't ship, is an
option that is off by default.

## Checking changes

```sh
nix flake check --all-systems   # evaluate everything, build this host's packages
nix build .#<name> && ./result/bin/<prog> --version
nix fmt                         # nixfmt; checks.formatting fails otherwise
```

Avoid `--no-build`: its read-only store fails on filtered sources that are
read during evaluation (`hermes-agent`).

Only `aarch64-darwin` builds locally; Linux is exercised by CI. To test in the
system config, point the input in `/etc/nix-darwin` at this checkout and run
`nh darwin build`. Only run `nh darwin switch` when asked.

## Workflows

Pin actions by commit SHA (with the tag in a comment). Give secrets only to
the step that needs them, never at job level, and default to
`permissions: contents: read`.

The update workflow opens pull requests for the packages in `REVIEW`, which
needs Settings → Actions → General → "Allow GitHub Actions to create and
approve pull requests" on the repository.

## Commits

Short imperative subject lines with no prefix. The update workflow commits as
`Update <name> to vX.Y.Z`.

This repo is public. Commits and files must not carry private data:

- No `Claude-Session:` trailers or other links to private sessions.
- Author and committer emails are noreply addresses only
  (`159290224+retvel@users.noreply.github.com` for the owner).
- No hostnames, usernames, IPs, paths or other details of the owner's machines
  in code, comments, docs or commit messages; use `alice`, `example.com` and
  the like in examples.
