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
          HERDR_TELEMETRY = "0";
        };
      })

      (lib.optionalAttrs (!isDarwin) {
        environment.sessionVariables = {
          HERDR_RELEASES_URL = releases;
          HERDR_TELEMETRY = "0";
        };
      })
    ]
  );
}
