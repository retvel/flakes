self:
{
  config,
  lib,
  pkgs,
  ...
}:

# What `nullclaw service install` sets up, as Home Manager config: a systemd
# user unit (~/.config/systemd/user/nullclaw.service) on Linux and the
# LaunchAgent com.nullclaw.daemon (~/Library/LaunchAgents) on macOS, both
# running `nullclaw gateway` as you, but always from the installed package
# instead of the store path of whatever binary ran `service install`, which
# goes stale on update and disappears on GC. Recheck both templates in the
# binary (strings, `[Service]` and `com.nullclaw.daemon`) when bumping.
let
  inherit (lib)
    literalExpression
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    optional
    optionalAttrs
    optionalString
    types
    ;
  cfg = config.services.nullclaw;
  inherit (pkgs.stdenv.hostPlatform) isDarwin isLinux;
  format = pkgs.formats.json { };
  settingsFile = format.generate "nullclaw-settings.json" cfg.settings;
  hasSettings = cfg.settings != { };
  nullclaw = "${cfg.package}/bin/nullclaw";

  # Merges `settings` into config.json before each start: Nix's values win,
  # and everything else (what `nullclaw onboard` wrote, tokens included)
  # stays. Written next to it and renamed, so a failed merge leaves it as it
  # was; umask 077, as config.json holds credentials.
  mergeSettings = pkgs.writeShellScript "nullclaw-merge-settings" ''
    set -eu
    umask 077
    config=${lib.escapeShellArg "${cfg.stateDir}/config.json"}
    mkdir -p ${lib.escapeShellArg cfg.stateDir}
    if [ -e "$config" ]; then
      ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$config" ${settingsFile} > "$config.nix-tmp"
    else
      cat ${settingsFile} > "$config.nix-tmp"
    fi
    mv "$config.nix-tmp" "$config"
  '';

  # Upstream's service-launch.sh for the LaunchAgent: NULLCLAW_HOME, then
  # `nullclaw gateway`.
  launcher = pkgs.writeShellScript "nullclaw-service-launch" ''
    set -eu
    export NULLCLAW_HOME=${lib.escapeShellArg cfg.stateDir}
    ${optionalString hasSettings "${mergeSettings}"}
    ${optionalString (cfg.environmentFile != null) ''
      if [ -r ${lib.escapeShellArg cfg.environmentFile} ]; then
        set -a; . ${lib.escapeShellArg cfg.environmentFile}; set +a
      fi
    ''}
    exec ${nullclaw} gateway
  '';
in
{
  options.services.nullclaw = {
    enable = mkEnableOption "the NullClaw gateway as your user service, like `nullclaw service install` (runs an autonomous AI agent as you)";
    package = mkOption {
      type = types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.nullclaw;
      defaultText = literalExpression "xr3t.packages.\${pkgs.stdenv.hostPlatform.system}.nullclaw";
      description = "NullClaw package to run, e.g. `nullclaw-nightly`.";
    };
    stateDir = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/.nullclaw";
      defaultText = literalExpression ''"''${config.home.homeDirectory}/.nullclaw"'';
      description = "NullClaw home (NULLCLAW_HOME): config.json, auth.json, workspace, logs.";
    };
    settings = mkOption {
      inherit (format) type;
      default = { };
      example = literalExpression ''
        {
          autonomy.level = "supervised";
          channels.telegram.allow_from = [ "123456789" ];
        }
      '';
      description = ''
        Settings merged into `stateDir`/config.json before every start
        (objects merged key by key, Nix winning; lists and other values
        replaced), so what Nix sets is always in effect and the keys
        `nullclaw onboard` wrote stay. Don't put tokens or API keys here: the
        store is world-readable. Keep them in config.json or
        `environmentFile`. `{ }` leaves config.json alone.
      '';
    };
    environmentFile = mkOption {
      type = types.nullOr types.str;
      default = if isLinux then "${cfg.stateDir}/.env" else null;
      defaultText = literalExpression ''if Linux then "''${stateDir}/.env" else null'';
      description = ''
        KEY=value file loaded into the gateway's environment, e.g. provider
        API keys; skipped when missing. Upstream's Linux unit loads
        `stateDir`/.env and its macOS agent loads none, hence the defaults.
      '';
    };
    watchdog = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Restart the gateway when one of its polling channels (e.g. Telegram)
          gets stuck. NullClaw restarts a stale channel thread itself, but that
          restart joins the old thread and hangs forever if the thread is stuck
          in a request: the process stays up and `Restart=always` never fires.
          A user timer checks the current run's log for the stale-thread
          warning and restarts the whole service. Not upstream's; Linux only.
        '';
      };
      interval = mkOption {
        type = types.str;
        default = "5min";
        description = "How often the watchdog checks (systemd time span).";
      };
    };
    hardening = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Confine the gateway and every command its agent runs with systemd
          sandboxing: the whole filesystem read-only except `stateDir` (and a
          private /tmp), no privilege gain (setuid, so no sudo), kernel
          tunables/modules/cgroups protected. NullClaw's own `sandbox` setting
          does nothing useful on NixOS (Landlock is a stub upstream, and
          firejail/bubblewrap/docker hide the host). Network, processes and
          devices stay visible, so the agent can still monitor the machine.
          Off by default, like upstream, whose service has no sandbox. Linux
          only, and the user manager needs unprivileged user namespaces.
        '';
      };
      readWritePaths = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "/home/alice/notes" ];
        description = "Extra paths the gateway may write to, besides `stateDir`.";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    { home.packages = [ cfg.package ]; }

    (mkIf isLinux {
      systemd.user.services = {
        # Upstream's unit, as `nullclaw service install` writes it.
        nullclaw = {
          Unit = {
            Description = "nullclaw gateway runtime";
            After = [ "network.target" ];
          };
          Service = {
            Type = "simple";
            ExecStartPre = optional hasSettings "${mergeSettings}";
            ExecStart = "${nullclaw} gateway";
            Restart = "always";
            RestartSec = 3;
            Environment = [ "NULLCLAW_HOME=${cfg.stateDir}" ];
            EnvironmentFile = optional (cfg.environmentFile != null) "-${cfg.environmentFile}";
          }
          # Read everything, write only stateDir. No PrivateNetwork,
          # ProtectProc=invisible or PrivateDevices: those would hide the
          # network, other processes and block devices from the agent.
          # Recheck nullclaw/nullclaw#882 (Landlock) when bumping nullclaw.
          // optionalAttrs cfg.hardening.enable (
            import ../../lib/hardening.nix
            // {
              ProtectSystem = "strict";
              ProtectHome = "read-only";
              ReadWritePaths = [ cfg.stateDir ] ++ cfg.hardening.readWritePaths;
              PrivateTmp = true;
              ProtectKernelTunables = true;
              ProtectKernelModules = true;
              ProtectHostname = true;
              RestrictNamespaces = true;
            }
          );
          Install.WantedBy = [ "default.target" ];
        };

        # Only this run's log (by invocation ID), so the restart it triggers
        # starts clean and cannot loop on an old warning. The string comes from
        # upstream's src/channel_manager.zig: recheck it when bumping nullclaw.
        # Don't match ` issue: health check failed`: it is transient.
        nullclaw-watchdog = mkIf cfg.watchdog.enable {
          Unit.Description = "Restart NullClaw when a channel is stuck";
          Service = {
            Type = "oneshot";
            ExecStart = toString (
              pkgs.writeShellScript "nullclaw-watchdog" ''
                PATH=${
                  lib.makeBinPath [
                    pkgs.systemd
                    pkgs.gnugrep
                  ]
                }
                systemctl --user is-active --quiet nullclaw.service || exit 0
                id=$(systemctl --user show --property=InvocationID --value nullclaw.service)
                [ -n "$id" ] || exit 0
                if journalctl --user --quiet --output=cat _SYSTEMD_INVOCATION_ID="$id" \
                    | grep -q ' issue: polling thread stale'; then
                  echo "nullclaw: a channel is stuck, restarting nullclaw.service"
                  systemctl --user restart nullclaw.service
                fi
              ''
            );
          };
        };
      };
      systemd.user.timers.nullclaw-watchdog = mkIf cfg.watchdog.enable {
        Unit.Description = "Check NullClaw for stuck channels";
        Timer = {
          OnActiveSec = cfg.watchdog.interval;
          OnUnitActiveSec = cfg.watchdog.interval;
        };
        Install.WantedBy = [ "timers.target" ];
      };
    })

    (mkIf isDarwin {
      # launchd opens the log files before it runs anything.
      home.activation.nullclawLogs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run mkdir -p ${lib.escapeShellArg "${cfg.stateDir}/logs"}
      '';

      # Upstream's LaunchAgent, as `nullclaw service install` writes it.
      launchd.agents.nullclaw = {
        enable = true;
        config = {
          Label = "com.nullclaw.daemon";
          ProgramArguments = [ "${launcher}" ];
          RunAtLoad = true;
          KeepAlive = true;
          StandardOutPath = "${cfg.stateDir}/logs/daemon.stdout.log";
          StandardErrorPath = "${cfg.stateDir}/logs/daemon.stderr.log";
        };
      };
    })
  ]);
}
