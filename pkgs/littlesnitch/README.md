# littlesnitch

A Nix package and NixOS module for
[Little Snitch for Linux](https://obdev.at/products/littlesnitch-linux/), a
network monitor that uses eBPF to show which programs connect where and to
filter those connections, with a web UI.

The package installs upstream's prebuilt static musl binary from obdev.at,
pinned by hash in `hashes.json` (the same checksums as upstream's
`littlesnitch-<version>.hashes.txt`), for:

- ARM64 Linux (`aarch64-linux`)
- x86_64 Linux (`x86_64-linux`)

Nothing is compiled, and the binary is installed unmodified (no strip, no
patchelf): the license allows redistribution only of the original binary.

## License: unfree

The daemon and CLI are proprietary freeware (free to use and redistribute
unmodified; see `share/doc/littlesnitch/copyright`), so `meta.license` is
unfree. This flake's own `packages` allow it. Through the overlay, allow it in
your nixpkgs:

```nix
nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "littlesnitch" ];
```

## NixOS module

```nix
{
  imports = [ inputs.retvel.nixosModules.littlesnitch ];
  services.littlesnitch.enable = true;
}
```

| Option | Default | Description |
|---|---|---|
| `services.littlesnitch.enable` | `false` | Run `littlesnitch --daemon` as upstream's systemd unit does. |
| `services.littlesnitch.package` | this flake's `littlesnitch` | Package to run. |
| `services.littlesnitch.updateCheck` | `false` | Let the daemon check for new versions (weekly). `false` links upstream's software update override with automatic checks off, as updates come through Nix; "Check now" in the About dialog still works. `true` leaves that override file to you. |

The service is upstream's own `littlesnitch.service` from the tarball
(`systemd.packages`), with `ExecStart` pointed into the store: its sandboxing,
capability bounding set and ordering before `network-pre.target` follow
upstream on every bump. The module only enables it. In a container whose
systemd lacks a capability the unit asserts, the unit won't start; drop the
assertions with `systemd.services.littlesnitch.unitConfig.AssertCapability = "";`.
The `littlesnitch` CLI is added to the system packages.

State lives in `/var/lib/littlesnitch`, which the daemon creates and manages:
rules, the connection log, and `override/config/*.toml` (for example
`web_ui.toml` for the web UI's bind address). Back it up to keep your rules.
