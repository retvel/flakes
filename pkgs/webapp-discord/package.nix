{ lib, callPackage }:
# Same as `pake https://discord.com/app --name Discord --identifier
# com.pake.discord --width 1280 --height 860 --hide-title-bar --enable-find
# --new-window`.
callPackage ../../lib/pake-webapp.nix { } {
  pname = "webapp-discord";
  sources = lib.importJSON ./hashes.json;
  productName = "Discord";
  identifier = "com.pake.discord";
  # Discord's white Symbol.svg from discord.com/branding on Blurple (#5865F2),
  # 512x512.
  icon = ./icon.png;
  window = {
    url = "https://discord.com/app";
    width = 1280;
    height = 860;
    hide_title_bar = true;
    enable_find = true;
    new_window = true;
  };
  description = "Discord (discord.com) as a desktop app, wrapped with Pake";
  homepage = "https://discord.com";
}
