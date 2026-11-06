# helium

[Helium](https://helium.computer/), a Chromium-based browser that is private
by default. Upstream's prebuilt releases, nothing compiled:

- macOS: the signed, notarized `Helium.app` from the Apple Silicon dmg
  (`imputnet/helium-macos`), untouched (`dontFixup`), in `$out/Applications`,
  with a `bin/helium` launcher.
- Linux: the binary tarball (`imputnet/helium-linux`) in `$out/libexec/helium`,
  its executables pointed at the store's loader and libraries, run through
  `bin/helium`, a wrapper in the way nixpkgs runs Google Chrome (libraries on
  `LD_LIBRARY_PATH`, nixpkgs' Vulkan loader, Wayland flags with
  `NIXOS_OZONE_WL`). Also `bin/helium-chromedriver`, and the desktop entry and
  icon.

Systems: `aarch64-darwin` (macOS 13 or later), `x86_64-linux`,
`aarch64-linux`.

## Usage

```nix
home.packages = [ inputs.xr3t.packages.${pkgs.stdenv.hostPlatform.system}.helium ];
```

Or with the Home Manager module, which also keeps its update check off:

```nix
{
  imports = [ inputs.xr3t.homeManagerModules.helium ];
  programs.helium.enable = true;
}
```

| Option | Default | |
|---|---|---|
| `programs.helium.enable` | `false` | Install Helium |
| `programs.helium.package` | this flake's `helium` | |
| `programs.helium.checkUpdates` | `false` | `false` sets `helium.services.browser_updates` to `false` in each profile's `Preferences` while the key is absent; after that Helium's own toggle decides. `true` leaves upstream's default (on). |

## Updates

On macOS, Helium updates itself with Sparkle, from updates.helium.computer,
which can't replace a bundle in the read-only Nix store. Its update check is a
per-profile setting, on by default: the updates toggle on the Helium services
page of the privacy settings (`helium.services.browser_updates` in
`~/Library/Application Support/net.imput.helium/<profile>/Preferences`).
Helium checks while any profile has it on.

The module turns it off in every profile that hasn't set it yet, including
the default profile before the first launch. Helium rewrites its profiles
when it quits, so they are only changed while it isn't running; a profile
created later is covered at the next activation. Without the module, turn the
toggle off in each profile. New releases come through this flake.

The Linux build has no update check: upstream's updater
(`add-updater-preference.patch` in `imputnet/helium`) is built for macOS and
Windows only. The toggle is there but does nothing, and the module leaves
Linux profiles alone.

`update.sh` follows upstream's latest (non-pre-)releases on GitHub, for both
systems: macOS and Linux release from separate repositories, and the package
moves to a version once both have published it.

## Maintenance

On a bump, check that the bundle is still `Helium.app` with executable
`Helium`, that the dmg is still named `helium_<version>_arm64-macos.dmg`, and
that upstream's `add-updater-preference.patch` still names the setting
`helium.services.browser_updates` and the user data directory is still
`net.imput.helium` (`change-product-dir-name.patch`).

On Linux, check that the tarball is still
`helium-<version>-{x86_64,arm64}_linux.tar.xz` with `helium`, `chromedriver`,
`helium_crashpad_handler`, `libvulkan.so.1`, `helium.desktop` and
`product_logo_256.png` at its top level, and that the updater patch still
builds the update check for macOS and Windows only (`UPDATES_SUPPORTED`).
