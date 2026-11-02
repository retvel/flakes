# helium

[Helium](https://helium.computer/), a Chromium-based browser that is private
by default. Upstream's prebuilt release, nothing compiled: the signed,
notarized `Helium.app` from the Apple Silicon dmg (`imputnet/helium-macos`),
untouched (`dontFixup`), in `$out/Applications`, with a `bin/helium` launcher.

Systems: `aarch64-darwin` (macOS 13 or later).

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

Helium updates itself with Sparkle, from updates.helium.computer, which can't
replace a bundle in the read-only Nix store. Its update check is a per-profile
setting, on by default: the updates toggle on the Helium services page of the
privacy settings (`helium.services.browser_updates` in
`~/Library/Application Support/net.imput.helium/<profile>/Preferences`).
Helium checks while any profile has it on.

The module turns it off in every profile that hasn't set it yet, including
the default profile before the first launch. Helium rewrites its profiles
when it quits, so they are only changed while it isn't running; a profile
created later is covered at the next activation. Without the module, turn the
toggle off in each profile. New releases come through this flake.

`update.sh` follows upstream's latest (non-pre-)release on GitHub.

## Maintenance

On a bump, check that the bundle is still `Helium.app` with executable
`Helium`, that the dmg is still named `helium_<version>_arm64-macos.dmg`, and
that upstream's `add-updater-preference.patch` still names the setting
`helium.services.browser_updates` and the user data directory is still
`net.imput.helium` (`change-product-dir-name.patch`).
