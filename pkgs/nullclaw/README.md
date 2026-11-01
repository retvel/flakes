# nullclaw

A Nix package for [NullClaw](https://github.com/nullclaw/nullclaw), a small,
fully autonomous AI assistant shipped as one static Zig binary. Two packages
share this `package.nix`:

- `nullclaw`: the latest tagged release (`version` in `hashes.json`).
- `nullclaw-nightly`: upstream's rolling `nightly` prerelease
  (`version` in `../nullclaw-nightly/hashes.json`, as `YYYYMMDD-<commit>`).

Both use upstream prebuilt release binaries and do not compile NullClaw
locally. They have SHA-256 checksums for:

- Apple Silicon macOS (`aarch64-darwin`)
- ARM64 Linux (`aarch64-linux`)
- x86_64 Linux (`x86_64-linux`)

The Linux binaries are statically linked against musl, so they run on NixOS
without patching. Both packages install `bin/nullclaw`; install one of them.

## Usage

```nix
{
  inputs.retvel.url = "github:retvel/flakes";
  inputs.retvel.inputs.nixpkgs.follows = "nixpkgs";

  environment.systemPackages = [ inputs.retvel.packages.${system}.nullclaw ];
  # or: inputs.retvel.packages.${system}.nullclaw-nightly
}
```

Through the overlay: `pkgs.retvel.nullclaw`, `pkgs.retvel.nullclaw-nightly`.

Or run it without installing:

```sh
nix run github:retvel/flakes#nullclaw -- --version
nix run github:retvel/flakes#nullclaw-nightly -- --version
```

Configuration lives in `~/.nullclaw`, as upstream documents; start with
`nullclaw onboard`.

## Nightly

Upstream rebuilds the `nightly` release in place: every day it replaces the
assets under the same file names. The pinned hashes therefore go stale as soon
as upstream publishes (its build starts at 02:23 UTC) and stay stale until this repo's next
update (03:17 or 15:17 UTC) commits the new ones.

While they are stale, a build that has to download the binary fails with a
hash mismatch. A binary already in your Nix store keeps working. So run
`nix flake update retvel` before rebuilding, and use `nullclaw` if you need
builds of an older lock to keep working.

## Service

`homeManagerModules.nullclaw` runs the gateway the way upstream's
`nullclaw service install` does, as your user service, but always from the
installed package (`service install` writes the store path of whatever binary
ran it, which goes stale on update and disappears on GC):

- **Linux:** the systemd user unit `nullclaw.service` (`Restart=always`,
  `WantedBy=default.target`, `stateDir`/.env loaded), logging to your journal:
  `journalctl --user -u nullclaw`. Restart with
  `systemctl --user restart nullclaw`.
- **macOS:** the LaunchAgent `com.nullclaw.daemon` (`KeepAlive`), logging to
  `stateDir`/logs/daemon.stdout.log and daemon.stderr.log, with launchd's
  default PATH, like upstream's. Restart with
  `launchctl kickstart -k gui/$(id -u)/com.nullclaw.daemon`.

```nix
{
  home-manager.users.alice = {
    imports = [ inputs.retvel.homeManagerModules.nullclaw ];

    services.nullclaw = {
      enable = true;
      # package = inputs.retvel.packages.${system}.nullclaw-nightly;
    };
  };

  # NixOS: user services stop at logout and start at login, as upstream's do.
  # For a gateway that runs from boot without a login:
  users.users.alice.linger = true;
}
```

The gateway runs an autonomous agent that can execute commands as you,
reachable from every configured channel. Review `autonomy` and each channel's
`allow_from` before enabling it, and set them through `settings`: the agent
can write to `stateDir`, `config.json` included, so it could widen what it
may do or who may reach it, but `settings` is merged back in on every start.

```nix
services.nullclaw.settings = {
  autonomy.level = "supervised";
  channels.telegram.allow_from = [ "123456789" ];
};
```

| Option | Default | Description |
|---|---|---|
| `services.nullclaw.enable` | `false` | Run the gateway and put `nullclaw` on `PATH`. |
| `services.nullclaw.package` | `nullclaw` | Package to run; `nullclaw-nightly` works too. |
| `services.nullclaw.stateDir` | `~/.nullclaw` | `NULLCLAW_HOME`: `config.json`, `auth.json`, workspace, logs. |
| `services.nullclaw.settings` | `{ }` | Merged into `config.json` before every start (objects key by key, Nix wins; lists replaced), so the keys Nix sets always apply and the rest stays as `nullclaw onboard` wrote it. Not for tokens or API keys: the store is world-readable. |
| `services.nullclaw.environmentFile` | `<stateDir>/.env` on Linux, `null` on macOS | `KEY=value` file for the gateway (e.g. API keys); skipped if missing. Upstream's Linux unit loads `.env`, its macOS agent doesn't. |
| `services.nullclaw.watchdog.enable` | `false` | Restart the gateway when a polling channel gets stuck (see below). Not upstream's; Linux only. |
| `services.nullclaw.watchdog.interval` | `"5min"` | How often the watchdog checks. |
| `services.nullclaw.hardening.enable` | `false` | Filesystem read-only except `stateDir`, no privilege gain (see below). Not upstream's; Linux only. |
| `services.nullclaw.hardening.readWritePaths` | `[ ]` | Extra writable paths besides `stateDir`. |

Run `nullclaw onboard` first, so `stateDir` exists. After editing
`config.json`, restart the service: `nullclaw config reload` only validates.

### Moving from the system service

`nixosModules.nullclaw` and `darwinModules.nullclaw` used to run the gateway
as a system service (`services.nullclaw.user`, launchd daemon
`com.nullclaw.gateway`, log in `stateDir`/gateway.log). They now only stop a
config that still sets `services.nullclaw` with a message pointing here. Move
the options to the user's Home Manager config without `user`, and on NixOS set
`users.users.<user>.linger = true` to keep it running from boot. On macOS the
old daemon's plist goes away with the switch; `stateDir` stays as it is.

### Watchdog

NullClaw restarts a stale channel thread itself (`<channel> issue: polling
thread stale`, then `Restarting <channel> (attempt N)`), but that restart first
joins the old thread. If the old thread is stuck in a request, the join never
returns: the process stays up, the channel stays dead, and `Restart=always`
never fires.

Opt in with `watchdog.enable = true`. On Linux the `nullclaw-watchdog` user
timer then checks the log of the current run (`_SYSTEMD_INVOCATION_ID`) every
`watchdog.interval` and restarts `nullclaw.service` when it finds
` issue: polling thread stale`: the case that can hang. Restarting starts a
new run with a clean log, so it does not loop on the same warning. A single
` issue: health check failed` is left alone: a transient API error from the
channel causes it too, and restarting then would cut off a reply in
progress.
Check what it did with `journalctl --user -u nullclaw-watchdog`.

### Hardening

NullClaw's own `security.sandbox` does not isolate anything on NixOS:
Landlock is still a stub upstream (`isAvailable()` returns false, and an
explicit `backend = "landlock"` silently falls back to no sandbox; see
nullclaw/nullclaw#882), and the firejail, bubblewrap and docker backends run
commands with no network, without `/nix/store`, or inside Alpine, which also
defeats an agent meant to look at the host. `nullclaw status` still says
"Sandbox: enabled".

With `hardening.enable = true`, systemd confines the gateway and every
command its agent runs instead: `ProtectSystem=strict` and `ProtectHome=read-only`
make the whole filesystem read-only except `stateDir` (plus
`hardening.readWritePaths`), `PrivateTmp`, `NoNewPrivileges` (setuid is
ignored, so `sudo` cannot work), and the kernel tunables, modules, logs,
cgroups, clock and hostname are protected. Network, processes (`/proc`) and
devices are left visible, so the agent can still monitor the machine; it just
cannot change files outside `stateDir`. Give it more with
`hardening.readWritePaths`. It is off by default, as upstream's service has
no sandbox; leave it off if the agent has to administer the machine (with
`sudo`).

## Updating

- `nullclaw update` detects the Nix store path and only prints instructions
  (for nixpkgs, not this flake). Upgrade with `nix flake update retvel`.
- Don't use `nullclaw service install`: it writes a user service pointing at
  the current `/nix/store` path, which keeps running the old version after an
  upgrade and breaks once that path is garbage-collected. Use
  `homeManagerModules.nullclaw` instead, which installs the same service.

## Updates

Each package has an `update.sh`, run by the repo's daily workflow:

- `nullclaw/update.sh` bumps to the latest upstream release.
- `nullclaw-nightly/update.sh` reads the nightly's version from its release
  notes and its hashes from the per-asset `.sha256` files. It exits cleanly
  when upstream is mid-upload.

Both run as agents with your access, so the workflow opens a pull request
for their updates instead of committing to `main`. Consumers pick them up
with `nix flake update retvel`.

## Outputs

- `packages.<system>.nullclaw`, `packages.<system>.nullclaw-nightly`
- `pkgs.retvel.nullclaw`, `pkgs.retvel.nullclaw-nightly` through `overlays.default`
- `homeManagerModules.nullclaw`: the `services.nullclaw` user service
- `nixosModules.nullclaw`, `darwinModules.nullclaw`: only a pointer to the Home
  Manager module, for configs that still set the old system service
