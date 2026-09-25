{ mkPackagesFor }:
# Builds pkgs/ against the consumer's nixpkgs and puts it under `pkgs.xr3t`.
# The flake's own `packages` use this repo's pinned nixpkgs instead.
final: _prev: {
  xr3t = mkPackagesFor final;
}
