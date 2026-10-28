{ lib, stdenv }:

let
  pin = lib.importJSON ./hashes.json;
  # Locked ref (rev + narHash), so getFlake works in pure evaluation and
  # builds with upstream's own flake.lock and nixpkgs.
  upstream = builtins.getFlake "github:NousResearch/hermes-agent/${pin.rev}?narHash=${pin.narHash}";
  hermes = upstream.packages.${stdenv.hostPlatform.system}.minimal.override {
    # Upstream's Nix package defaults to "0.0.0".
    inherit (pin) version;
    # cron is a no-op (croniter is core); kept to state intent.
    extraDependencyGroups = [
      "telegram"
      "cron"
      "mcp"
    ];
  };
in
hermes.overrideAttrs (old: {
  # Built and cached for the NixOS host only.
  meta = old.meta // {
    platforms = [ "x86_64-linux" ];
  };
})
