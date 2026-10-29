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

## Usage

Two modules, both upstream's from the pinned commit with
`services.hermes-agent.package` defaulting to this flake's package. All
options are upstream's; see `nix/moduleCommon.nix`, `nix/homeManagerModules.nix`
and `nix/nixosModules.nix` in the pinned source.

| Module | Runs as | `HERMES_HOME` |
|---|---|---|
| `homeManagerModules.hermes-agent` | your user, systemd user services, config editable from the CLI | `~/.hermes` (like upstream's `install.sh`) |
| `nixosModules.hermes-agent` | system user `hermes`, hardened system service | `/var/lib/hermes/.hermes` |

Either way, use the input without `inputs.nixpkgs.follows`; Hermes is built
from upstream's nixpkgs anyway, and keeping the lock as is lets the host fetch
it from `retvel.cachix.org` instead of compiling it. Add the cache in the
NixOS config (a Home Manager user can't add trusted substituters):

```nix
nix.settings = {
  extra-substituters = [ "https://retvel.cachix.org" ];
  extra-trusted-public-keys = [ "retvel.cachix.org-1:F90N/+Y4l6GI7+1gw86cdlu1Uc13oxJrKr/9XmbNDKc=" ];
};
```

### As your user, like install.sh (Home Manager)

```nix
{
  # NixOS: systemd stops user services at logout without linger.
  users.users.alice.linger = true;

  home-manager.users.alice = {
    imports = [ inputs.retvel.homeManagerModules.hermes-agent ];

    programs.hermes-agent.enable = true; # `hermes` on PATH, HERMES_HOME exported
    services.hermes-agent = {
      enable = true;
      gateway.enable = true; # Telegram
    };
  };
}
```

Then set it up as after install.sh: `hermes setup`, `hermes model`, keys in
`~/.hermes/.env`. What matches a normal Linux install:

- Runs as your user, `HERMES_HOME=~/.hermes`, working directory `~`.
- The CLI may change the config (`nixManagesConfig = false`, the default):
  this module deletes the `.managed` marker that upstream's activation writes
  and runs the services with `HERMES_MANAGED=false`.
- The gateway (and the backend, if `backend.mode` is set) runs as a systemd
  user service with your PATH (`~/.local/bin`, your Nix profiles,
  `/run/current-system/sw/bin`) after Hermes' own tools, like the unit
  `hermes gateway install` writes.
- The gateway unit also has the rest of that unit (in both modes):
  `HERMES_SUPERVISED_CHILD=1`, exit 75 as a requested restart and 78 as a
  fatal config error, the planned-stop mark on `ExecStop` (a `systemctl
  stop` or a switch no longer leaves the unit failed), the cgroup cleanup on
  `ExecStopPost`, `ExecReload` (SIGUSR1) and `TimeoutStopSec=70`.

What differs:

- Updates come from Nix (`nix flake update retvel` and a rebuild), not
  `hermes update`; the services restart on the new version after the switch.
- With `gateway.enable` the unit is `hermes-agent`, which Hermes' CLI does
  not know: `hermes gateway status` reports "Running manually". Use
  `hermesGatewayUnit` (below) for the Tier 1 unit.
- Once Hermes downloads a tool into `~/.hermes/tools` (the browser tool
  fetches agent-browser on first use when none is on PATH), `hermes gateway
  status` warns "install out of sync" for node, npm, ripgrep and ffmpeg,
  which it then expects there too. Put `pkgs.agent-browser` in
  `home.packages` to avoid it.
- Each switch merges `settings` (and `terminal.cwd` from `workingDirectory`)
  into `config.yaml`; other keys you set with the CLI stay. `.env` is only
  touched when `environment` or `environmentFiles` is set.

Hermes' update check compares with the latest stable release, like Tier 1:
without a git checkout it would follow upstream's main branch and always
report an update. Hermes refuses `hermes update --set-channel` on Nix, so
each switch writes the `update.installs.<id>` record for the current store
path to `config.yaml` (`stable-channel.py`). A new release shows as "Update
available"; take it with `nix flake update retvel` and a rebuild.

Set `services.hermes-agent.nixManagesConfig = true` for upstream's managed
mode instead: the CLI refuses config changes, and the services see only
Hermes, bash, coreutils, git and `extraPackages`.

#### The Tier 1 gateway unit (Linux)

```nix
services.hermes-agent = {
  gateway.enable = false;
  hermesGatewayUnit.enable = true;
  # Optional, not for secrets (the drop-in is in the store):
  hermesGatewayUnit.environment.AGENT_BROWSER_EXECUTABLE_PATH = "${pkgs.chromium}/bin/chromium";
};
```

The gateway then runs as Hermes' own user unit `hermes-gateway`, the one
`hermes gateway install` writes after install.sh, so `hermes gateway
status`, `start`, `stop`, `restart` and `uninstall` manage it. That unit is
Hermes' file in `~/.config/systemd/user`, not a store link: Hermes compares it
with what it would generate and rewrites it when they differ.

- Hermes' unit starts the store's Python without the package's wrapper (no
  bundled skills, locales or node, only FHS dirs on PATH). The drop-in
  `hermes-gateway.service.d/10-nix.conf` replaces `ExecStart` with
  `<package>/bin/hermes gateway run` and sets `PATH`, `HERMES_MANAGED=false`
  and `hermesGatewayUnit.environment`.
- Each switch, after the user units are reloaded: `hermes gateway install
  --start-now --start-on-login` if the unit is missing. Otherwise, when the
  package, the drop-in, `settings`, `environment` or `environmentFiles`
  changed (Hermes reads config.yaml and .env only at start), it starts
  `hermes-gateway-refresh`, which runs `hermes gateway restart` (that also
  refreshes the unit's store paths). Hermes refuses that while chat turns,
  cron jobs or delegations are live, so the refresh retries every minute
  until the gateway is idle: a switch never interrupts a conversation and
  never fails because of one (`journalctl --user -u hermes-gateway-refresh`).
  A stopped gateway stays stopped; its unit is refreshed on the next
  `hermes gateway start`. `~/.hermes/.nix-gateway-unit` links to the stamp
  last applied.
- Needs `nixManagesConfig = false`: managed mode refuses `hermes gateway
  install`.

### As a system service (NixOS)

```nix
{
  imports = [ inputs.retvel.nixosModules.hermes-agent ];

  services.hermes-agent = {
    enable = true;
    environmentFiles = [ config.sops.secrets."hermes-env".path ];
    addToSystemPackages = true;
    extraPackages = with pkgs; [ jq ]; # tools the agent may run
  };
}
```

### Keep the cache hit

Do not set `services.hermes-agent.extraDependencyGroups` or
`extraPythonPackages`: either changes the derivation, so the host builds it
locally instead of using the cache. Add groups to `package.nix` here instead.
Tools for the agent go in `extraPackages`, which leaves the package untouched.

## Updates

`update.sh` reads the release GitHub marks latest, resolves the annotated
tag to its commit and writes `{ version, rev, narHash }` to `hashes.json`.
`update.yml` then builds it on x86_64 Linux, commits
`Update hermes-agent to vX.Y.Z` and pushes its runtime closure to Cachix; a
failed build drops the bump and `main` stays on the previous release. CI
pushes no other package to the cache. Run `update.sh` by hand for a manual bump.

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
- `homeManagerModules.hermes-agent`
