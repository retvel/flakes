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
  # "0" turns the app's usage report off whatever Herdr's settings say; "1"
  # only keeps herdr-app's own default (0) out of the way, so Herdr's setting
  # decides.
  telemetry = if cfg.telemetry == "off" then "0" else "1";
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
      # true/false from earlier versions still work: true is "app", false "off".
      type = lib.types.coercedTo lib.types.bool (b: if b then "app" else "off") (
        lib.types.enum [
          "off"
          "app"
        ]
      );
      default = "off";
      example = "app";
      description = ''
        Who decides whether the app sends its daily usage report upstream.
        "off": nobody, it is off (HERDR_TELEMETRY=0, which wins over Herdr's
        settings). "app": Herdr's own `telemetry` setting
        (~/.config/herdr-app/settings.json, or Settings, Privacy), which is
        on when absent.
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
