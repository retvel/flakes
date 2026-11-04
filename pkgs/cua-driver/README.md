# cua-driver

[cua-driver](https://github.com/trycua/cua) (the Rust driver, releases
`cua-driver-rs-v<version>`), the desktop control driver behind Hermes'
`computer_use` tool. Linux (x86_64, aarch64) only: upstream's release
binaries, patched to find their libraries in the store. `update.sh` follows
upstream's releases and checks each download against the release's
`SHA256SUMS`.

## With Hermes

The hermes-agent modules (NixOS and Home Manager) can point Hermes at this
package instead of the copy `hermes computer-use install` downloads:

```nix
services.hermes-agent.cuaDriver.enable = true;
```

This writes `HERMES_CUA_DRIVER_CMD=<package>/bin/cua-driver` to Hermes'
`.env`, which Hermes reads before its own package manager, and
`CUA_DRIVER_RS_UPDATE_CHECK=0` (see below; set it in
`services.hermes-agent.environment` to change it). `hermes computer-use
status` then reports "custom binary from HERMES_CUA_DRIVER_CMD", and
`hermes update` leaves the driver alone.

Hermes accepts any cua-driver from 0.20.0 whose `cua-driver manifest` lists
the subcommands and flags it needs, so this package can be newer than the one
Hermes' own lock pins. Recheck on a bump:

```sh
cua-driver manifest | jq '.binary_version, [.subcommands[] | {name, args: [.args[]?.name]}]'
```

against `_CUA_DRIVER_RUNTIME_CONTRACT_ARGS` in Hermes'
`tools/computer_use/cua_backend_driver.py`.

## Telemetry and updates

`bin/cua-driver` is a wrapper around upstream's binary:

- Telemetry (content-free PostHog events, on by default upstream) is off:
  the wrapper sets `CUA_DRIVER_RS_TELEMETRY_ENABLED=0` unless `DO_NOT_TRACK`,
  `CUA_DRIVER_RS_TELEMETRY_ENABLED`, `CUA_TELEMETRY_ENABLED` or
  `CUA_TELEMETRY` is set, or `~/.cua-driver/config.json` has
  `telemetry_enabled`. Turn it back on with `cua-driver telemetry enable`.
  Hermes turns it off for the driver it starts unless its
  `computer_use.cua_telemetry` is true.
- The hourly background update check is off the same way
  (`CUA_DRIVER_RS_UPDATE_CHECK=0`, unless that variable is set or
  `~/.cua-driver/config.json` has `update_check_enabled`). Turn it back on
  with `CUA_DRIVER_RS_UPDATE_CHECK=1`, or `"update_check_enabled": true` in
  that file. `cua-driver check-update` still checks when you run it.
- `cua-driver update --apply` is refused: it runs upstream's installer, which
  installs another copy outside the store. Updates come from this flake.

Upstream's MCP launch command (`cua-driver manifest`) names the binary behind
the wrapper, so clients that start that command, Hermes included, skip the
wrapper; that is why the Hermes option sets `CUA_DRIVER_RS_UPDATE_CHECK=0`.
