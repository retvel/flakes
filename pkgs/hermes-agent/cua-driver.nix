# services.hermes-agent.cuaDriver, for the NixOS and Home Manager modules:
# this flake's cua-driver as the driver of Hermes' computer_use tool, in place
# of the one `hermes computer-use install` downloads.
self:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.hermes-agent.cuaDriver;
in
{
  options.services.hermes-agent.cuaDriver = {
    enable = lib.mkEnableOption ''
      this flake's cua-driver for Hermes' computer_use tool (Linux), set as
      HERMES_CUA_DRIVER_CMD in Hermes' .env. Hermes then uses it instead of the
      copy `hermes computer-use install` downloads, and `hermes update` leaves
      it alone
    '';

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.cua-driver;
      defaultText = lib.literalExpression "xr3t.packages.\${system}.cua-driver";
      description = "The cua-driver package.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.hermes-agent.environment = {
      HERMES_CUA_DRIVER_CMD = lib.getExe cfg.package;
      # Hermes starts the command cua-driver's manifest names, the binary
      # behind the package's wrapper, so the wrapper's default doesn't reach
      # it. Telemetry Hermes turns off itself (computer_use.cua_telemetry).
      CUA_DRIVER_RS_UPDATE_CHECK = lib.mkDefault "0";
    };
  };
}
