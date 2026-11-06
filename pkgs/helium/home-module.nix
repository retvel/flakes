self:
{
  config,
  lib,
  pkgs,
  ...
}:

# Installs Helium and keeps its update check off by default: Nix's default,
# not a lock. Helium keeps the switch per profile, in each profile's
# Preferences (helium.services.browser_updates, the updates toggle on the
# Helium services page of its privacy settings), and checks for updates while
# any profile has it on. This only adds `false` to profiles that don't have
# the key yet, so whatever the user sets afterwards stays. Only on macOS:
# Helium's Linux build has no update check (upstream builds it for macOS and
# Windows only), so on Linux the module just installs it.
let
  cfg = config.programs.helium;
  # Upstream's user data directory on macOS.
  dir = "${config.home.homeDirectory}/Library/Application Support/net.imput.helium";
  addDefault = pkgs.writeText "helium-browser-updates.py" ''
    import json, os, sys

    data = sys.argv[1]


    def write(path, prefs, mode):
        tmp = path + ".nix-tmp"
        with open(tmp, "w") as f:
            json.dump(prefs, f, separators=(",", ":"))
        os.chmod(tmp, mode)
        os.replace(tmp, path)


    # Never run yet: start the default profile with the key, as the user's
    # first launch would otherwise check for updates before any activation.
    if not os.path.exists(data):
        os.makedirs(os.path.join(data, "Default"), mode=0o700)
        prefs = {"helium": {"services": {"browser_updates": False}}}
        write(os.path.join(data, "Default", "Preferences"), prefs, 0o600)
        sys.exit(0)

    # Every profile Helium knows of (Local State), and the default one.
    profiles = {"Default"}
    try:
        with open(os.path.join(data, "Local State")) as f:
            state = json.load(f)
        profiles |= set(state.get("profile", {}).get("info_cache", {}))
    except (OSError, ValueError):
        pass

    for name in sorted(profiles):
        path = os.path.join(data, name, "Preferences")
        try:
            with open(path) as f:
                prefs = json.load(f)
        except (OSError, ValueError):
            continue
        services = prefs.setdefault("helium", {}).setdefault("services", {})
        if "browser_updates" in services:
            continue
        services["browser_updates"] = False
        write(path, prefs, os.stat(path).st_mode & 0o777)
  '';
in
{
  options.programs.helium = {
    enable = lib.mkEnableOption "Helium, a Chromium-based browser that is private by default";
    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.helium;
      defaultText = lib.literalExpression "xr3t.packages.\${pkgs.stdenv.hostPlatform.system}.helium";
      description = "Helium package to install.";
    };
    checkUpdates = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Let Helium check updates.helium.computer for a newer release (macOS;
        the Linux build has no update check). It can't install one into the
        Nix store. false, the default, sets
        `helium.services.browser_updates` to false in each profile that
        doesn't have it yet, as updates come through Nix; once it's there,
        Helium's own toggle decides. Profiles are only changed while Helium
        isn't running, since it rewrites them on exit. true leaves upstream's
        default, on.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    home.activation.heliumBrowserUpdates =
      lib.mkIf (pkgs.stdenv.hostPlatform.isDarwin && !cfg.checkUpdates)
        (
          lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            if /usr/bin/pgrep -xq Helium; then
              echo "helium: running; its update check is set off at the next activation while it is closed"
            else
              run ${lib.getExe pkgs.python3} -I ${addDefault} ${lib.escapeShellArg dir}
            fi
          ''
        );
  };
}
