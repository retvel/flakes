{ lib, callPackage }:
# Same as `pake https://claude.ai --name Claude --identifier com.pake.claude
# --width 1280 --height 860 --hide-title-bar --enable-find --new-window`.
callPackage ../../lib/pake-webapp.nix { } {
  pname = "webapp-claude";
  sources = lib.importJSON ./hashes.json;
  productName = "Claude";
  identifier = "com.pake.claude";
  # claude.ai's apple-touch-icon.png.
  icon = ./icon.png;
  window = {
    url = "https://claude.ai";
    width = 1280;
    height = 860;
    hide_title_bar = true;
    enable_find = true;
    new_window = true;
  };
  description = "Claude (claude.ai) as a desktop app, wrapped with Pake";
  homepage = "https://claude.ai";
}
