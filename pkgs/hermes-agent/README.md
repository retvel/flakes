# hermes-agent

[Hermes Agent](https://github.com/NousResearch/hermes-agent) pinned to the
same stable release as upstream's Tier 1 install (`install.sh`,
`hermes update`): the latest `vX.Y.Z` GitHub release, never a draft,
prerelease, rc or canary, at the tag's commit.

The package does not build Hermes itself. `package.nix` calls upstream's own
flake at the pinned commit with `builtins.getFlake`, so the build uses
upstream's `flake.lock` and nixpkgs, and the result does not depend on this
repo's or the consumer's nixpkgs (the overlay gives the same store path).

- Variant: `minimal` plus the dependency groups `telegram` and `mcp`. Cron
  needs no group: croniter is core, and the empty `cron` extra is missing
  from `uv.lock`, so uv2nix rejects it. Only groups listed under
  `optional-dependencies` of `hermes-agent` in `uv.lock` work. Upstream
  always adds the `all` extra (cron, pty, mcp, uvloop, sms, acp, google, web,
  youtube), so `mcp` is already in it; it is listed to keep it if `all`
  changes.
- Python dependencies come from upstream's `uv.lock`, so their versions are
  exactly what the Tier 1 install gets. llm-agents.nix's `hermes-agent`
  instead uses nixpkgs' Python packages with a few overrides and ships every
  messaging extra (Discord, Slack, Matrix, ...); this package has Telegram
  only.
- `version` is set from `hashes.json`; upstream's Nix package otherwise
  reports `0.0.0`.
- `meta.platforms` is `x86_64-linux` only, so other CI runners skip the build
  and the Cachix cache only holds the NixOS host's closure.

## Usage (NixOS)

Use the input without `inputs.nixpkgs.follows`; Hermes is built from
upstream's nixpkgs either way, and keeping the lock as is lets the host fetch
it from `retvel.cachix.org` instead of compiling it.

```nix
{
  imports = [ inputs.retvel.nixosModules.hermes-agent ];

  nix.settings = {
    extra-substituters = [ "https://retvel.cachix.org" ];
    extra-trusted-public-keys = [ "retvel.cachix.org-1:F90N/+Y4l6GI7+1gw86cdlu1Uc13oxJrKr/9XmbNDKc=" ];
  };

  services.hermes-agent = {
    enable = true;
    environmentFiles = [ config.sops.secrets."hermes-env".path ];
    addToSystemPackages = true;
    extraPackages = with pkgs; [ jq ]; # tools the agent may run
  };
}
```

`nixosModules.hermes-agent` is upstream's `nixosModules.default` from the
pinned commit, with `services.hermes-agent.package` defaulting to this
flake's package. All options are upstream's; see `nix/nixosModules.nix` and
`nix/moduleCommon.nix` in the pinned source.

Do not set `services.hermes-agent.extraDependencyGroups` or
`extraPythonPackages` on the host: either changes the derivation, so the host
builds it locally instead of using the cache. Add groups to `package.nix`
here instead. Tools for the agent go in `extraPackages`, which leaves the
package untouched.

## Updates

`update.sh` reads the release GitHub marks latest, resolves the annotated
tag to its commit and writes `{ version, rev, narHash }` to `hashes.json`.
`update.yml` then builds it on x86_64 Linux, pushes it to Cachix and commits
`Update hermes-agent to vX.Y.Z`; a failed build drops the bump and `main`
stays on the previous release. Run `update.sh` by hand for a manual bump.

On a bump, check:

- `hermes --version` shows the new version, not `0.0.0` (upstream may change
  the `version` argument of `nix/hermes-agent.nix`).
- The groups still exist in upstream's `uv.lock`.
- Module options used on the host still exist; build the host's `toplevel`
  before updating its lock.

## Outputs

- `packages.x86_64-linux.hermes-agent`
- `pkgs.retvel.hermes-agent` through `overlays.default`
- `nixosModules.hermes-agent`
