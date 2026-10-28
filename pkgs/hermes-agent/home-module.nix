self:

let
  # Read with builtins: `imports` cannot depend on `pkgs`.
  pin = builtins.fromJSON (builtins.readFile ./hashes.json);
  upstream = builtins.getFlake "github:NousResearch/hermes-agent/${pin.rev}?narHash=${pin.narHash}";
in
{ lib, pkgs, ... }:
{
  imports = [ upstream.homeManagerModules.default ];
  services.hermes-agent.package =
    lib.mkDefault
      self.packages.${pkgs.stdenv.hostPlatform.system}.hermes-agent;
}
