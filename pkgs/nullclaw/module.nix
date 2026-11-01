self:
{
  config,
  options,
  lib,
  pkgs,
  ...
}:

# One module for both nix-darwin (launchd) and NixOS (systemd), like rayfish.
# Runs what `nullclaw service install` sets up upstream (`nullclaw gateway`,
# restart on exit, NULLCLAW_HOME, optional .env), but pointed at the Nix
# package instead of the store path of whatever binary ran `service install`,
# which goes stale on update and disappears on GC.
let
  inherit (lib)
    concatStringsSep
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
  isDarwin = options ? launchd;
  home = config.users.users.${cfg.user}.home;
  format = pkgs.formats.json { };
  settingsFile = format.generate "nullclaw-settings.json" cfg.settings;
  hasSettings = cfg.settings != { };

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
in
{
  options.services.nullclaw = {
    enable = mkEnableOption "the NullClaw gateway (runs an autonomous AI agent as `user`)";
    package = mkOption {
      type = types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.nullclaw;
      defaultText = literalExpression "retvel.packages.\${pkgs.stdenv.hostPlatform.system}.nullclaw";
      description = "NullClaw package to run, e.g. `nullclaw-nightly`.";
    };
    user = mkOption {
      type = types.str;
      example = "alice";
      description = ''
        User the gateway runs as. Its config, credentials and workspace live in
        `stateDir`, created by `nullclaw onboard` as this user.
      '';
    };
    stateDir = mkOption {
      type = types.str;
      default = "${home}/.nullclaw";
      defaultText = literalExpression ''"''${config.users.users.<user>.home}/.nullclaw"'';
      description = "NullClaw home (NULLCLAW_HOME): config.json, auth.json, workspace.";
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
      default = "${cfg.stateDir}/.env";
      defaultText = literalExpression ''"''${stateDir}/.env"'';
      description = ''
        Optional KEY=value file loaded into the gateway's environment, e.g.
        provider API keys. Skipped when missing. On macOS it is sourced by
        the launcher shell.
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
          A timer checks the current run's log for the stale-thread warning and
          restarts the whole service. NixOS only.
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
        default = true;
        description = ''
          Confine the gateway and every command its agent runs with systemd
          sandboxing: the whole filesystem read-only except `stateDir` (and a
          private /tmp), no privilege gain (setuid, so no sudo), kernel
          tunables/modules/cgroups protected. NullClaw's own `sandbox` setting
          does nothing useful on NixOS (Landlock is a stub upstream, and
          firejail/bubblewrap/docker hide the host), so this is the
          enforcement. Network, processes and devices stay visible, so the
          agent can still monitor the machine. On by default: the agent runs
          commands chosen by a model and reachable from chat. NixOS only.
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
    { environment.systemPackages = [ cfg.package ]; }

    (optionalAttrs isDarwin {
      launchd.daemons.nullclaw = {
        serviceConfig = {
          Label = "com.nullclaw.gateway";
          UserName = cfg.user;
          # Like rayfish: wait for the Nix store at boot instead of letting
          # launchd cache a missing executable.
          ProgramArguments = [
            "/bin/sh"
            "-c"
            ''
              while [ ! -x "${cfg.package}/bin/nullclaw" ]; do sleep 1; done
              ${optionalString hasSettings "${mergeSettings}"}
              ${optionalString (cfg.environmentFile != null) ''
                if [ -r "${cfg.environmentFile}" ]; then set -a; . "${cfg.environmentFile}"; set +a; fi
              ''}
              exec "${cfg.package}/bin/nullclaw" gateway
            ''
          ];
          EnvironmentVariables = {
            HOME = home;
            NULLCLAW_HOME = cfg.stateDir;
            # The agent runs tools (git, shell): the same programs as a login shell.
            PATH = concatStringsSep ":" [
              "/etc/profiles/per-user/${cfg.user}/bin"
              "/run/current-system/sw/bin"
              "/nix/var/nix/profiles/default/bin"
              "/usr/bin"
              "/bin"
              "/usr/sbin"
              "/sbin"
            ];
          };
          WorkingDirectory = home;
          RunAtLoad = true;
          KeepAlive = true;
          ThrottleInterval = 10;
          StandardOutPath = "${cfg.stateDir}/gateway.log";
          StandardErrorPath = "${cfg.stateDir}/gateway.log";
        };
      };
    })

    (optionalAttrs (!isDarwin) {
      systemd = {
        services = {
          nullclaw = {
            description = "NullClaw gateway";
            wantedBy = [ "multi-user.target" ];
            wants = [ "network-online.target" ];
            after = [ "network-online.target" ];
            # The agent runs tools (git, shell): the same programs as a login shell.
            path = [
              "/run/wrappers"
              "/etc/profiles/per-user/${cfg.user}"
              "/run/current-system/sw"
            ];
            environment = {
              HOME = home;
              NULLCLAW_HOME = cfg.stateDir;
            };
            serviceConfig = {
              ExecStartPre = lib.optional hasSettings mergeSettings;
              User = cfg.user;
              Group = config.users.users.${cfg.user}.group;
              WorkingDirectory = home;
              ExecStart = "${cfg.package}/bin/nullclaw gateway";
              EnvironmentFile = optional (cfg.environmentFile != null) "-${cfg.environmentFile}";
              Restart = "always";
              RestartSec = 3;
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
          };

          # Only this run's log (by invocation ID), so the restart it triggers
          # starts clean and cannot loop on an old warning. The string comes from
          # upstream's src/channel_manager.zig: recheck it when bumping nullclaw.
          # Don't match ` issue: health check failed`: it is transient.
          nullclaw-watchdog = mkIf cfg.watchdog.enable {
            description = "Restart NullClaw when a channel is stuck";
            serviceConfig.Type = "oneshot";
            script = ''
              systemctl is-active --quiet nullclaw.service || exit 0
              id=$(systemctl show --property=InvocationID --value nullclaw.service)
              [ -n "$id" ] || exit 0
              if journalctl --quiet --output=cat _SYSTEMD_INVOCATION_ID="$id" \
                  | grep -q ' issue: polling thread stale'; then
                echo "nullclaw: a channel is stuck, restarting nullclaw.service"
                systemctl restart nullclaw.service
              fi
            '';
            path = [
              config.systemd.package
              pkgs.gnugrep
            ];
          };
        };
        timers.nullclaw-watchdog = mkIf cfg.watchdog.enable {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = cfg.watchdog.interval;
            OnUnitActiveSec = cfg.watchdog.interval;
          };
        };
      };
    })
  ]);
}
