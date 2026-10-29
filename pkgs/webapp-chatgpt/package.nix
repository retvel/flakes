{ callPackage }:
callPackage ../../lib/pake-webapp.nix { } {
  pname = "webapp-chatgpt";
  dir = ./.;
  description = "ChatGPT as a macOS app, wrapped with Pake";
}
