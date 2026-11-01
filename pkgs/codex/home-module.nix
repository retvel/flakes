self:
{
  config,
  lib,
  pkgs,
  ...
}:

# Extends Home Manager's own programs.codex (settings, AGENTS.md, skills and
# the rest stay its options): this flake's codex as the default package, and
# the app-server daemon pinned to it declaratively.
let
  cfg = config.programs.codex;
  # The directory Home Manager's programs.codex writes config.toml to, and
  # sets CODEX_HOME to when it isn't ~/.codex.
  codexHome =
    if config.home.preferXdgDirectories then
      lib.removePrefix "${config.home.homeDirectory}/" "${config.xdg.configHome}/codex"
    else
      ".codex";
in
{
  config = lib.mkMerge [
    { programs.codex.package = lib.mkDefault self.packages.${pkgs.stdenv.hostPlatform.system}.codex; }

    # `codex app-server daemon` runs `current` and keeps it updated unless it
    # names a package; linked to the store, it runs this package and never
    # downloads one. Only for packages that say where (this flake's).
    (lib.mkIf (cfg.enable && cfg.package != null && cfg.package ? appServerDaemon) {
      home.file."${codexHome}/packages/app-server-daemon/current".source = cfg.package.appServerDaemon;
    })
  ];
}
