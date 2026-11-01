self:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.littlesnitch;

  # Upstream's software_update.toml (built into the binary; recheck it when
  # bumping littlesnitch), with automatic checks off: updates come through
  # Nix. Upstream made it overridable for redistributions, in
  # /var/lib/littlesnitch/override/config. The URLs stay, so the About
  # dialog's "Check now" still works.
  softwareUpdate = pkgs.writeText "littlesnitch-software_update.toml" ''
    [stable]
    update_interval_hours = 0
    current_version_url = "https://sw-update.obdev.at/update-feeds/littlesnitch-linux.php"
    download_url_template = "https://obdev.at/littlesnitch-linux/download-swu.php?arch=$arch&static=$static&currentVersion=$current_version"

    [prerelease]
    update_interval_hours = 0
    current_version_url = "https://sw-update.obdev.at/update-feeds/littlesnitch-linux.php?channel=prerelease"
    download_url_template = "https://obdev.at/littlesnitch-linux/download-swu.php?channel=prerelease&arch=$arch&static=$static&currentVersion=$current_version"
  '';
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
    updateCheck = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Let the daemon check obdev.at for new versions (weekly, upstream's
        default). false links an override of upstream's software update
        config with automatic checks off, as updates come through Nix; the
        About dialog's "Check now" still works. true leaves
        /var/lib/littlesnitch/override/config/software_update.toml to you
        (remove the link this option left there, if any).
      '';
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
    systemd.services.littlesnitch.wantedBy = [ "multi-user.target" ];

    systemd.tmpfiles.rules = lib.optionals (!cfg.updateCheck) [
      "d /var/lib/littlesnitch/override/config - - - -"
      "L+ /var/lib/littlesnitch/override/config/software_update.toml - - - - ${softwareUpdate}"
    ];
  };
}
