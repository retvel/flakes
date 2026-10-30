self:
{
  config,
  options,
  lib,
  pkgs,
  ...
}:

# One module for both nix-darwin (launchd) and NixOS (systemd). The platform is
# detected from the declared options rather than `pkgs`, which would recurse.
let
  cfg = config.programs.herdr;
  isDarwin = options ? launchd;
  releases = "file://${cfg.package}/share/herdr/releases";
  check = "${cfg.package}/bin/herdr-update-check";
in
{
  options.programs.herdr = {
    enable = lib.mkEnableOption "Herdr and herdr-core, updated through Nix";
    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.herdr;
      defaultText = lib.literalExpression "retvel.packages.\${pkgs.stdenv.hostPlatform.system}.herdr";
      description = "Herdr package to install.";
    };
    updateCheck.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Check upstream every 6 hours, and at login, and post a desktop
        notification once per newer release saying to update through Nix.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      { environment.systemPackages = [ cfg.package ]; }

      # Every launch, also from Finder, the Dock or a desktop entry, sees the
      # pinned release manifests, so the app's own updater stays quiet.
      (lib.optionalAttrs isDarwin {
        launchd.user.envVariables.HERDR_RELEASES_URL = releases;
        launchd.user.agents.herdr-update-check = lib.mkIf cfg.updateCheck.enable {
          serviceConfig = {
            ProgramArguments = [ check ];
            RunAtLoad = true;
            StartInterval = 6 * 60 * 60;
            ProcessType = "Background";
          };
        };
      })

      (lib.optionalAttrs (!isDarwin) {
        environment.sessionVariables.HERDR_RELEASES_URL = releases;
        systemd.user.services.herdr-update-check = lib.mkIf cfg.updateCheck.enable {
          description = "Check for a newer Herdr release";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = check;
          };
        };
        systemd.user.timers.herdr-update-check = lib.mkIf cfg.updateCheck.enable {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnStartupSec = "2min";
            OnUnitActiveSec = "6h";
          };
        };
      })
    ]
  );
}
