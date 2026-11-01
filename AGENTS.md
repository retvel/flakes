# AGENTS.md

Guidance for coding agents working in this repo. `README.md` is the user-facing
doc; keep it and each package's README in sync with behavior. Remote:
`xr3t/flakes`.

## Layout

See `LAYOUT.md`; keep it in sync when adding a kind of file or workflow.

## Adding a package

1. `pkgs/<name>/package.nix` (+ `hashes.json` and `update.sh` if it tracks upstream releases).
   `update.sh` sources `lib/update.sh` and passes every upstream version
   through `check_version`. Where upstream publishes checksums (a sums file,
   `.sha256` files, a manifest), check downloads against them (`sums`, or
   `prefetch URL SHA256`); GitHub release assets are checked against GitHub's
   digest by `prefetch` itself. If the package runs as root or acts with the
   user's access, add it to `REVIEW` in `.github/workflows/update.yml`.
   Give the package an install check that runs it (`--version`, or
   `lib/check-app.py` for a macOS app bundle): building is not starting.
2. Set `meta.platforms` to the systems it really supports; that's what filters `packages.<system>`.
   If evaluating it fetches another flake, also list it in `fixedPlatforms` in
   `flake.nix`.
3. Add a row to the README package table and a `pkgs/<name>/README.md` if it has options.
   Package-specific notes (gotchas, what to recheck on a bump) go in that README
   or as comments in the package's own files, not in this file.
4. `git add` new files; flakes ignore untracked files.

## Modules

Run a package and its service the way upstream's own installer does (recheck
its unit or plist on a bump), with the binary in the store: Nix makes it
declarative, it doesn't change how it behaves. Updates and telemetry go
through Nix instead (next section). Anything else beyond upstream, such as a
sandbox it doesn't ship, is an option that is off by default.

## Updates and telemetry

Turn off every package's self-update, update check and telemetry wherever it
can be done; updates come from this flake. When adding or bumping a package,
look for all three in its docs, its config schema and its binary.

1. Use upstream's documented switch first: a setting, an env var, a flag, or
   an override that upstream offers redistributions.
2. Without one, an undocumented knob will do, but say so in the package
   README and recheck it on every bump: upstream may drop it.
3. Last resort for an update command: a guard wrapper that refuses it.

Telemetry and update checks are defaults the user can set back: the user's
Nix config or the program's own config wins. So apply them only while that
config doesn't set them (a flag or env var added conditionally), or as a
module option. A self-update stays off: it would replace the store copy, and
a root daemon could write into the store.

In the package README, say what is off, how, and how to turn it back on.
Where nothing in the package can turn it off (an updater inside a signed app
bundle), say that and how to turn it off in the app.

## Checking changes

```sh
nix flake check --all-systems   # evaluate everything, build this host's packages
nix build .#<name> && ./result/bin/<prog> --version
nix fmt                         # nixfmt; checks.formatting fails otherwise
```

Avoid `--no-build`: its read-only store fails on filtered sources that are
read during evaluation.

A local check builds only the host's own system; CI builds Linux x86_64,
Linux aarch64 and macOS. To try a change in a system config, build that
config against this checkout (`--override-input <input> path:<checkout>`);
don't switch to it unless asked.

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

- No links to private sessions or chats (such as an agent's session trailer).
- Author and committer emails are noreply addresses only.
- No hostnames, usernames, IPs, local paths or other details of anyone's
  machines in code, comments, docs or commit messages; use `alice`,
  `example.com` and the like in examples.
- READMEs, notes and comments describe a package for anyone who installs
  it, not how its maintainer uses it. Leave out their setup and habits: which
  features, channels or services they run, the other tools they pair it with,
  what they tested on, and incidents seen on their machines. Write such facts
  as upstream behavior or a general case ("a polling channel", "another
  VPN", "a transient API error"); upstream's own release, bug or issue is
  fine to cite.
