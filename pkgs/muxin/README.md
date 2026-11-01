# muxin

[Muxin](https://muxin.dev): one desktop app for all your machines and the AI
agents on them (sessions, desktops, logs, files and servers, over ssh), with
the `muxin` command line and MCP server (`muxin mcp`). Upstream's prebuilt
release, nothing compiled:

- macOS: the signed, universal `Muxin.app` from the release dmg, untouched
  (`dontFixup`), in `$out/Applications`; `bin/muxin` links to its binary.
- Linux: the release tarball's `muxin` in `libexec/muxin`, patched with
  autoPatchelf (Vulkan and Wayland added for what it loads at run time), with
  a desktop entry and icon.

Both keep upstream's `agents/` next to the binary: the static `muxen-agent`
builds Muxin copies to each machine it manages (`~/.muxen/bin`). They are
installed byte for byte as released, never stripped or patched. `bin/muxen`
is the command's name from before, as upstream's packages install it.

Systems: `aarch64-darwin`, `x86_64-linux`, `aarch64-linux`.

## Usage

```nix
home.packages = [ inputs.retvel.packages.${pkgs.stdenv.hostPlatform.system}.muxin ];
```

Or with the Home Manager module, which also keeps its update check off:

```nix
{
  imports = [ inputs.retvel.homeManagerModules.muxin ];
  programs.muxin.enable = true;
}
```

| Option | Default | |
|---|---|---|
| `programs.muxin.enable` | `false` | Install Muxin |
| `programs.muxin.package` | this flake's `muxin` | |
| `programs.muxin.checkUpdates` | `false` | `false` adds `check_updates = false` to `[settings]` in `config.toml` while the key is absent; after that Muxin's own setting decides. `true` leaves upstream's default (on). |

## Updates and telemetry

Muxin doesn't update itself: it asks GitHub for its latest release at launch
and twice a day, and shows it with a link. That check is off by default with
the module (above); without it, turn it off in Settings › General › Updates,
or with `check_updates = false` under `[settings]` in
`~/.config/muxin/config.toml` (`$XDG_CONFIG_HOME/muxin`, or `$MUXIN_HOME`).
New releases come through this flake.

Muxin has no telemetry. Besides the machines you add, it contacts GitHub (the
update check, and its GitHub features when you use them), and muxin.dev only
for sharing and for alerts to Muxin for iPad.

`update.sh` follows upstream's latest GitHub release. Muxin runs agents and
reaches your machines with your ssh, so its updates come as a pull request.

## Maintenance

On a bump, check that the release still ships `agents/` next to the binary
(the tarball, and `Contents/Resources/agents` in the app), the libraries the
Linux binary loads at run time (`strings` for `lib*.so`), and that
`check_updates` is still the setting's name in upstream's `src/config.rs`.
