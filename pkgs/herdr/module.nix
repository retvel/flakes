self:
{
  config,
  options,
  lib,
  pkgs,
  ...
}:

# One module for both nix-darwin and NixOS. The platform is
# detected from the declared options rather than `pkgs`, which would recurse.
let
  cfg = config.programs.herdr;
  isDarwin = options ? launchd;
  releases = "file://${cfg.package}/share/herdr/releases";
  # "0" turns the app's usage report off; "1" only keeps herdr-app's own
  # default (0) out of the way, so Herdr's setting decides.
  telemetry = if cfg.telemetry then "1" else "0";
in
{
  options.programs.herdr = {
    enable = lib.mkEnableOption "Herdr (app, herdr-core and CLI), updated through Nix only";
    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.herdr;
      defaultText = lib.literalExpression "xr3t.packages.\${pkgs.stdenv.hostPlatform.system}.herdr";
      description = "Herdr package to install.";
    };
    telemetry = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Let the app send its daily usage report upstream. false sets
        HERDR_TELEMETRY=0, which turns it off whatever Herdr's settings say;
        true leaves it to Herdr's own `telemetry` setting.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      { environment.systemPackages = [ cfg.package ]; }

      # Every launch, also from Finder, the Dock or a desktop entry, sees the
      # pinned release manifests, so the app's own updater stays quiet, and
      # sends no usage reports.
      (lib.optionalAttrs isDarwin {
        launchd.user.envVariables = {
          HERDR_RELEASES_URL = releases;
          HERDR_TELEMETRY = telemetry;
        };
      })

      (lib.optionalAttrs (!isDarwin) {
        environment.sessionVariables = {
          HERDR_RELEASES_URL = releases;
          HERDR_TELEMETRY = telemetry;
        };
      })
    ]
  );
}
