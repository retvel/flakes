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

  hermes = "${common.effectivePackage cfg}/bin/hermes";

  # What the running gateway was started with: the drop-in (and with it the
  # package) and what each switch writes to config.yaml and .env, which
  # Hermes only reads at start.
  gatewayStamp = pkgs.writeText "hermes-gateway-stamp" (
    builtins.toJSON {
      dropIn = "${gatewayDropIn}";
      inherit (cfg) settings environment environmentFiles;
    }
  );
  unitCfg = cfg.hermesGatewayUnit;
  unitDir = "${config.xdg.configHome}/systemd/user";

  # Hermes' own unit starts the store's Python directly, without the
  # package's wrapper: no bundled skills, locales or node, and only FHS dirs
  # on PATH. The drop-in runs the wrapper instead, which Hermes still
  # recognizes as its gateway (`hermes gateway run`).
  gatewayDropIn = pkgs.writeText "hermes-gateway-nix.conf" (
    lib.concatStringsSep "\n" (
      [
        "[Service]"
        "ExecStart="
        "ExecStart=${hermes} gateway run"
      ]
      ++ lib.mapAttrsToList (k: v: "Environment=\"${k}=${v}\"") (
        {
          HERMES_MANAGED = "false";
          PATH = userPath;
        }
        // unitCfg.environment
      )
    )
    + "\n"
  );
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

  options.services.hermes-agent.hermesGatewayUnit = {
    enable = lib.mkEnableOption ''
      the gateway as Hermes' own user unit `hermes-gateway`, the one
      `hermes gateway install` writes on Tier 1, in place of `gateway.enable`.
      `hermes gateway status`, `start`, `stop` and `restart` then manage it.
      Each switch installs it if missing, and otherwise runs
      `hermes gateway restart` when the package, the drop-in, `settings`,
      `environment` or `environmentFiles` changed, which also points the unit
      at the new store paths. A drop-in runs the package's
      wrapper and sets PATH (Linux only)
    '';

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Variables for the gateway, set in the drop-in. Not for secrets: the drop-in is in the Nix store.";
    };
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

    (lib.mkIf (cfg.enable && unitCfg.enable) {
      assertions = [
        {
          assertion = !cfg.gateway.enable;
          message = "services.hermes-agent: set gateway.enable = false with hermesGatewayUnit.enable; both would poll the same bot token.";
        }
        {
          assertion = !cfg.nixManagesConfig;
          message = "services.hermes-agent.hermesGatewayUnit needs nixManagesConfig = false; managed mode refuses `hermes gateway install`.";
        }
        {
          assertion = pkgs.stdenv.hostPlatform.isLinux;
          message = "services.hermes-agent.hermesGatewayUnit is for systemd (Linux) only.";
        }
      ];

      xdg.configFile."systemd/user/hermes-gateway.service.d/10-nix.conf".source = gatewayDropIn;

      # After reloadSystemd, so a `hermes-agent` unit this switch removes is
      # stopped first. The stamp links to gatewayStamp, which changes with
      # the package, the drop-in and the config. A stopped gateway stays
      # stopped; its unit is refreshed on the next `hermes gateway start`.
      home.activation.hermesGatewayUnit =
        lib.hm.dag.entryAfter
          [
            "reloadSystemd"
            "hermesAgentUnmanaged"
            "hermesAgentStableChannel"
          ]
          ''
            export XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
            # The activation PATH has no systemctl; Hermes runs it (and
            # loginctl) by name too.
            export PATH=${lib.escapeShellArg (dirOf config.systemd.user.systemctlPath)}:"$PATH"
            hermesGateway() {
              $DRY_RUN_CMD env HERMES_HOME=${lib.escapeShellArg cfg.hermesHome} ${hermes} gateway "$@"
            }
            stamp=${lib.escapeShellArg "${cfg.hermesHome}/.nix-gateway-unit"}
            if [ ! -e ${lib.escapeShellArg "${unitDir}/hermes-gateway.service"} ]; then
              $DRY_RUN_CMD systemctl --user daemon-reload
              hermesGateway install --start-now --start-on-login
            elif [ "$(readlink "$stamp" 2>/dev/null)" != ${gatewayStamp} ]; then
              $DRY_RUN_CMD systemctl --user daemon-reload
              if systemctl --user is-active --quiet hermes-gateway; then
                hermesGateway restart
              fi
            fi
            $DRY_RUN_CMD ln -sfn ${gatewayStamp} "$stamp"
          '';
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
