# Security

This is a personal flake, maintained on a best-effort basis. It repackages
other people's software. Read this before relying on it, especially for the
packages that run as system services.

## Reporting a vulnerability

Report it privately through GitHub: **Security → Report a vulnerability** on
this repository. Don't open a public issue for it.

Report here:

- the Nix code, modules and scripts in this repository (`flake.nix`,
  `pkgs/*/package.nix`, `*module.nix`, `update.sh`, `lib/`);
- the workflows in `.github/workflows/`;
- a pinned hash or URL that downloads something other than upstream's
  official release.

A vulnerability in a packaged program goes to its upstream project, linked
from each package's `meta.homepage`. Tell us too if this flake makes it worse,
for example by exposing it in a module.

Expect an answer within a week or so. Only the latest commit on `main` gets
fixes; there are no release branches.

## Trust model

- **Prebuilt upstream binaries.** Almost every package installs upstream's
  official release as published (GitHub releases, npm, vendor download
  servers). Nothing is audited here.
- **Hashes pin, they don't vouch.** `hashes.json` proves a download is the one
  that was fetched when the update ran, not that it is safe. Where upstream
  publishes more, `update.sh` checks it as well: Node's `SHASUMS256.txt` must
  carry a signature by a Node release key, Little Snitch's tarballs must match
  its checksum list, and npm packages are pinned by the registry's integrity
  hash. Every upstream version goes through `check_version`
  (`lib/update.sh`) before it reaches a URL, `hashes.json` or a commit
  message.
- **Rolling builds.** `ghostty-tip` and `nullclaw-nightly` follow upstream
  builds that are replaced in place. Their pins only download until the next
  build.
- **Updates.** `.github/workflows/update.yml` checks for new releases twice a
  day and only commits an update that passes `nix flake check`. Packages that
  run as root, filter the network or act as agents with your access (`REVIEW`
  in that workflow) don't go straight to `main`: their updates wait in a pull
  request for review. The rest are committed directly.
- **Binary cache.** CI pushes only `hermes-agent`'s closure, built from `main`,
  to `retvel.cachix.org`; builds from pull requests never reach it. Trusting
  that cache means trusting this repository's CI.

## CI hardening

- Workflows default to a read-only `GITHUB_TOKEN`; only the update workflow
  can write, and only to commit updates and open their pull requests.
- Secrets reach only the step that uses them (the Cachix push), never a
  whole job.
- Actions are pinned by commit SHA and bumped by Dependabot.

## Service modules

On NixOS the service modules run their daemons under systemd sandboxing.
`lib/hardening.nix` is the part they share (no privilege gain through setuid;
clock, kernel logs and cgroups protected), and each adds what its service can
live without. On macOS (launchd) there is no sandbox.

- `nullclaw` and `1mcp`: `hardening.enable`, on by default, and `sudo`
  doesn't work under it. nullclaw can write only to its `stateDir` (plus
  `hardening.readWritePaths`); 1mcp gets a private `/tmp` and read-only
  `/usr`, `/boot` and `/etc`. Turn it off only if the agent has to administer
  the machine.
- `littlesnitch`: upstream's own unit, with its capability bounding set and
  sandbox.
- `rayfish`: runs as root for its TUN device, routes and resolver, with the
  shared sandbox only.
- `hermes-agent`: upstream's NixOS module, with its own system user and
  hardening.

Agents (`nullclaw`, `hermes-agent`, `codex`, `opencode`, `pi`) run commands a
model chooses. Restrict who can reach them (e.g. nullclaw's `allow_from`) and
what they may do before enabling them.

## Secrets

Nothing in the Nix store is secret: it is world-readable. Options such as
`settings` and `environment` end up in the store, so keep tokens and API
keys in the files the modules read at run time (`environmentFile`, Hermes'
`environmentFiles`, nullclaw's `config.json`), ideally managed by sops-nix or
agenix.

This repository is public. Its code, docs and commits carry no private data:
noreply author emails only, and placeholders such as `alice` and
`example.com` in examples.
