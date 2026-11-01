self:
{
  config,
  lib,
  pkgs,
  utils,
  ...
}:

let
  inherit (lib)
    literalExpression
    mkEnableOption
    mkIf
    mkOption
    optional
    optionalAttrs
    optionals
    types
    ;
  cfg = config.services."1mcp";
  home = config.users.users.${cfg.user}.home;
  format = pkgs.formats.json { };
  configFile =
    if cfg.settings == null then
      "${cfg.configDir}/mcp.json"
    else
      format.generate "1mcp-mcp.json" cfg.settings;
in
{
  options.services."1mcp" = {
    enable = mkEnableOption "the 1MCP runtime (aggregates MCP servers behind one HTTP endpoint)";
    package = mkOption {
      type = types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}."1mcp";
      defaultText = literalExpression ''xr3t.packages.''${pkgs.stdenv.hostPlatform.system}."1mcp"'';
      description = "1MCP package to run.";
    };
    user = mkOption {
      type = types.str;
      example = "alice";
      description = ''
        User the runtime and the MCP servers it starts run as. They get this
        user's PATH, so `npx`/`uvx`-style servers work.
      '';
    };
    configDir = mkOption {
      type = types.str;
      default = "${home}/.config/1mcp";
      defaultText = literalExpression ''"''${config.users.users.<user>.home}/.config/1mcp"'';
      description = ''
        1MCP config directory. Unless `settings` is set, `mcp.json` in it
        lists the MCP servers; it is created empty on first start and never
        overwritten, so it can be edited in place (or symlinked to a repo).
      '';
    };
    settings = mkOption {
      type = types.nullOr format.type;
      default = null;
      example = literalExpression ''
        {
          mcpServers.filesystem = {
            command = "npx";
            args = [ "-y" "@modelcontextprotocol/server-filesystem" "/home/alice/notes" ];
          };
        }
      '';
      description = ''
        The MCP servers as Nix, written to the store as the `mcp.json` 1MCP
        runs with, in place of the one in `configDir` (which commands like
        `1mcp mcp add` then can't change). The store is world-readable: keep
        API keys in `environmentFile`. `null` uses `configDir`'s `mcp.json`.
      '';
    };
    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address to listen on. Keep it on loopback and put a TLS proxy in front.";
    };
    port = mkOption {
      type = types.port;
      default = 3050;
      description = "HTTP port.";
    };
    externalUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "https://host.example:3050";
      description = "Public base URL, used for OAuth callbacks and advertised URLs.";
    };
    enableAuth = mkOption {
      type = types.bool;
      default = true;
      description = "Require OAuth 2.1 bearer tokens on /mcp (`--enable-auth`).";
    };
    environmentFile = mkOption {
      type = types.nullOr types.str;
      default = "${cfg.configDir}/.env";
      defaultText = literalExpression ''"''${configDir}/.env"'';
      description = ''
        Optional KEY=value file loaded into the environment, e.g. API keys the
        MCP servers need. Skipped when missing.
      '';
    };
    hardening.enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Confine the runtime and every MCP server it starts with systemd
        sandboxing: no privilege gain (setuid, so no sudo), a private /tmp,
        /usr, /boot and /etc read-only, kernel tunables and modules
        protected. The user's home stays writable, so npx/uvx caches work.
        Off by default: upstream ships no service, and MCP servers may need
        more than this allows.
      '';
    };
    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [
        "--enable-config-reload"
        "--enable-async-loading"
      ];
      description = "Extra `1mcp serve` arguments.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    systemd.services."1mcp" = {
      description = "1MCP runtime";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      path = [
        "/run/wrappers"
        "/etc/profiles/per-user/${cfg.user}"
        "/run/current-system/sw"
      ];
      environment.HOME = home;
      preStart = ''
        mkdir -p "${cfg.configDir}"
      ''
      + lib.optionalString (cfg.settings == null) ''
        [ -e "${configFile}" ] || echo '{ "mcpServers": {} }' > "${configFile}"
      '';
      serviceConfig = {
        User = cfg.user;
        Group = config.users.users.${cfg.user}.group;
        WorkingDirectory = home;
        ExecStart = utils.escapeSystemdExecArgs (
          [
            "${cfg.package}/bin/1mcp"
            "serve"
            "--config-dir"
            cfg.configDir
            "--config"
            configFile
            "--host"
            cfg.host
            "--port"
            (toString cfg.port)
          ]
          ++ optionals (cfg.externalUrl != null) [
            "--external-url"
            cfg.externalUrl
          ]
          ++ optional cfg.enableAuth "--enable-auth"
          ++ cfg.extraArgs
        );
        EnvironmentFile = optional (cfg.environmentFile != null) "-${cfg.environmentFile}";
        Restart = "always";
        RestartSec = 3;
      }
      // optionalAttrs cfg.hardening.enable (
        import ../../lib/hardening.nix
        // {
          PrivateTmp = true;
          ProtectSystem = "full";
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
        }
      );
    };
  };
}
