self:

let
  # Read with builtins: `imports` cannot depend on `pkgs`.
  pin = builtins.fromJSON (builtins.readFile ./hashes.json);
  upstream = builtins.getFlake "github:NousResearch/hermes-agent/${pin.rev}?narHash=${pin.narHash}";
in
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.hermes-agent;
  common = import "${upstream}/nix/moduleCommon.nix" { inherit lib; };
  home = config.home.homeDirectory;

  # Like the unit `hermes gateway install` writes after install.sh: the
  # agent also sees the user's own tools, after upstream's unit PATH.
  userPath = lib.concatStringsSep ":" [
    (lib.makeBinPath (common.processPath { inherit pkgs cfg; }))
    "${home}/.local/bin"
    "${home}/.nix-profile/bin"
    "/etc/profiles/per-user/${config.home.username}/bin"
    "/run/wrappers/bin"
    "/run/current-system/sw/bin"
    "/usr/local/bin"
    "/usr/bin"
    "/bin"
  ];

  # systemd keeps the last assignment of a variable, so these override
  # upstream's HERMES_MANAGED=home-manager and PATH.
  unmanagedEnvironment = lib.mkAfter [
    "HERMES_MANAGED=false"
    "PATH=${userPath}"
  ];

  # Runs one of Hermes' modules the way the unit `hermes gateway install`
  # writes does (installation_command in hermes_cli/_launchers.py).
  hermesModule =
    module:
    "${(common.effectivePackage cfg).hermesVenv}/bin/python3 -I -c "
    + "'import hermes_bootstrap, runpy; runpy.run_module(\"${module}\", run_name=\"__main__\", alter_sys=True)'";
in
{
  imports = [ upstream.homeManagerModules.default ];

  options.services.hermes-agent.nixManagesConfig = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      false (default): behave like upstream's install.sh. `hermes setup`,
      `hermes model` and other config changes from the CLI work, and the
      services run with your PATH. Nix still merges `settings` into
      config.yaml on each switch.

      true: upstream's managed mode. The CLI refuses config changes, and the
      services see only Hermes, bash, coreutils, git and `extraPackages`.
    '';
  };

  config = lib.mkMerge [
    {
      services.hermes-agent.package =
        lib.mkDefault
          self.packages.${pkgs.stdenv.hostPlatform.system}.hermes-agent;
    }

    (lib.mkIf cfg.enable {
      # Without a git checkout Hermes follows upstream's main branch and keeps
      # reporting an update. Compare with the latest stable release instead.
      home.activation.hermesAgentStableChannel = lib.hm.dag.entryAfter [ "hermesAgentSetup" ] ''
        $DRY_RUN_CMD env HERMES_HOME=${lib.escapeShellArg cfg.hermesHome} \
          ${(common.effectivePackage cfg).hermesVenv}/bin/python3 -I ${./stable-channel.py} \
          ${lib.escapeShellArg "${cfg.hermesHome}/config.yaml"}
      '';
    })

    # The rest of the gateway unit `hermes gateway install` writes on Tier 1
    # (generate_systemd_unit in hermes_cli/gateway.py). Without the stop mark
    # Hermes takes every `systemctl stop` or restart, a switch included, for
    # an unexpected kill, exits 1 and leaves the unit failed. Exit 75 is a
    # requested restart (`/restart`), 78 a config error a restart cannot fix.
    # ExecStopPost kills helpers left in the cgroup. TimeoutStopSec is what
    # Hermes computes for its default drain timeouts.
    (lib.mkIf (cfg.enable && cfg.gateway.enable && pkgs.stdenv.hostPlatform.isLinux) {
      systemd.user.services.hermes-agent = {
        Unit.StartLimitIntervalSec = 0;
        Service = {
          Environment = [ "HERMES_SUPERVISED_CHILD=1" ];
          RestartForceExitStatus = 75;
          SuccessExitStatus = 75;
          RestartPreventExitStatus = 78;
          KillMode = "mixed";
          KillSignal = "SIGTERM";
          ExecReload = "${pkgs.coreutils}/bin/kill -USR1 $MAINPID";
          ExecStop = "-${hermesModule "gateway.systemd_stop_mark"}";
          ExecStopPost = "-${hermesModule "gateway.cgroup_cleanup"}";
          TimeoutStopSec = 70;
        };
      };
    })

    (lib.mkIf (cfg.enable && !cfg.nixManagesConfig) {
      # Upstream's activation writes the marker that turns on managed mode.
      home.activation.hermesAgentUnmanaged = lib.hm.dag.entryAfter [ "hermesAgentSetup" ] ''
        $DRY_RUN_CMD rm -f ${lib.escapeShellArg "${cfg.hermesHome}/.managed"}
      '';

      systemd.user.services = lib.mkIf pkgs.stdenv.hostPlatform.isLinux (
        lib.optionalAttrs cfg.gateway.enable {
          hermes-agent.Service.Environment = unmanagedEnvironment;
        }
        // lib.optionalAttrs (cfg.backend.mode != "none") {
          hermes-backend.Service.Environment = unmanagedEnvironment;
        }
      );
    })
  ];
}
