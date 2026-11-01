self:
{
  config,
  lib,
  pkgs,
  ...
}:

# Installs Muxin and keeps its update check off by default: Nix's default,
# not a lock. Muxin keeps its settings in config.toml ([settings]
# check_updates, Settings › General › Updates in the app); this only adds
# `check_updates = false` there while the key is absent, so whatever the user
# sets afterwards stays.
let
  cfg = config.programs.muxin;
  # Muxin's own default: $XDG_CONFIG_HOME/muxin, else ~/.config/muxin.
  dir = "${config.xdg.configHome}/muxin";
  python = pkgs.python3.withPackages (ps: [ ps.tomlkit ]);
  # Adds the key to [settings], keeping the rest of the file (comments
  # included) as Muxin wrote it, and its mode.
  addDefault = pkgs.writeText "muxin-check-updates.py" ''
    import os, sys, tomlkit
    path = sys.argv[1]
    with open(path) as f:
        doc = tomlkit.parse(f.read())
    settings = doc.get("settings")
    if settings is not None and "check_updates" in settings:
        sys.exit(0)
    if settings is None:
        settings = tomlkit.table()
        doc["settings"] = settings
    settings["check_updates"] = False
    tmp = path + ".nix-tmp"
    with open(tmp, "w") as f:
        f.write(tomlkit.dumps(doc))
    os.chmod(tmp, os.stat(path).st_mode & 0o777)
    os.replace(tmp, path)
  '';
in
{
  options.programs.muxin = {
    enable = lib.mkEnableOption "Muxin, one app for all your machines and their AI agents";
    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.muxin;
      defaultText = lib.literalExpression "retvel.packages.\${pkgs.stdenv.hostPlatform.system}.muxin";
      description = "Muxin package to install.";
    };
    checkUpdates = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Let Muxin ask GitHub for a newer release (at launch and twice a day)
        and show it; it never installs one itself. false, the default, adds
        `check_updates = false` to config.toml's [settings] while the key is
        absent, as updates come through Nix. Once it's there, Muxin's own
        setting (Settings › General › Updates) decides. true leaves upstream's
        default, on.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    # After Muxin made config.toml itself (its first run writes the machine
    # list and moves an older config in); if there is none yet, `muxin
    # settings` makes it the same way.
    home.activation.muxinCheckUpdates = lib.mkIf (!cfg.checkUpdates) (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ ! -e ${lib.escapeShellArg "${dir}/config.toml"} ]; then
          run env XDG_CONFIG_HOME=${lib.escapeShellArg config.xdg.configHome} \
            ${lib.getExe cfg.package} settings >/dev/null 2>&1 || true
        fi
        if [ -e ${lib.escapeShellArg "${dir}/config.toml"} ]; then
          run ${python}/bin/python3 -I ${addDefault} ${lib.escapeShellArg "${dir}/config.toml"}
        fi
      ''
    );
  };
}
