{ callPackage }:
callPackage ../../lib/pake-webapp.nix { } {
  pname = "webapp-claude";
  dir = ./.;
  description = "Claude as a macOS app, wrapped with Pake";
}
