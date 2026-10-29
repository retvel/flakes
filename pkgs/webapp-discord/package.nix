{ callPackage }:
callPackage ../../lib/pake-webapp.nix { } {
  pname = "webapp-discord";
  dir = ./.;
  description = "Discord as a macOS app, wrapped with Pake";
}
