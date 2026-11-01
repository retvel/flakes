self:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.littlesnitch;
in
{
  options.services.littlesnitch = {
    enable = lib.mkEnableOption "the Little Snitch for Linux network monitor daemon";
    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.littlesnitch;
      defaultText = lib.literalExpression "xr3t.packages.\${pkgs.stdenv.hostPlatform.system}.littlesnitch";
      description = "Little Snitch package to run.";
    };
  };

  config = lib.mkIf cfg.enable {
    # The `littlesnitch` CLI talks to the running daemon.
    environment.systemPackages = [ cfg.package ];

    # Upstream's own littlesnitch.service, as the package ships it (ExecStart
    # pointed into the store): its ordering before network-pre.target,
    # capability bounding set and sandboxing all come from the tarball, so a
    # bump picks up upstream's changes. State, rules and web UI overrides
    # live in /var/lib/littlesnitch (the daemon creates it).
    systemd.packages = [ cfg.package ];
    systemd.services.littlesnitch = {
      wantedBy = [ "multi-user.target" ];
      # Its AssertCapability= lines test systemd's own capability set, which
      # is smaller in some containers; CapabilityBoundingSet= still limits
      # what the daemon gets.
      unitConfig.AssertCapability = "";
    };
  };
}
