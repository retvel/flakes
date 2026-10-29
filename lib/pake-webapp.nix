# A website as a macOS app, built with Pake (https://github.com/tw93/Pake) by
# .github/workflows/webapp.yml and published in this repo's "Pake (X.Y.Z)"
# release. Nothing is compiled here: this unpacks that release's dmg. Used by
# pkgs/webapp-*/package.nix through `callPackage`.
{
  lib,
  stdenvNoCC,
  fetchurl,
  _7zz,
}:
{
  pname,
  # The webapp's directory: pake.json (Pake's --config) and hashes.json
  # ({ version, tag, config, hashes }, written by the workflow once the dmg is
  # published).
  dir,
  description,
}:
let
  config = lib.importJSON (dir + "/pake.json");
  sources = lib.importJSON (dir + "/hashes.json");
  system = stdenvNoCC.hostPlatform.system;
in
stdenvNoCC.mkDerivation {
  inherit pname;
  inherit (sources) version;

  src = fetchurl {
    url = "https://github.com/retvel/flakes/releases/download/${sources.tag}/${config.name}-aarch64.dmg";
    hash = sources.hashes.${system};
  };

  # Pake's dmg may be APFS, which undmg can't read.
  nativeBuildInputs = [ _7zz ];
  sourceRoot = ".";

  dontConfigure = true;
  dontBuild = true;
  # Stripping or patching would break the bundle's ad-hoc code signature.
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    # An HFS+ dmg unpacks into a folder named after its volume, an APFS one
    # into the current directory.
    app="$(find . -maxdepth 2 -type d -name ${lib.escapeShellArg "${config.name}.app"} | head -n1)"
    [ -n "$app" ] || { echo "no ${config.name}.app in the dmg" >&2; exit 1; }
    mkdir -p "$out/Applications"
    cp -R "$app" "$out/Applications/"
    runHook postInstall
  '';

  meta = {
    inherit description;
    homepage = config.url;
    downloadPage = "https://github.com/retvel/flakes/releases/tag/${sources.tag}";
    # Pake's license; the website itself is its owner's service.
    license = lib.licenses.gpl3Plus;
    # Empty until the workflow has published the first release.
    platforms = builtins.attrNames sources.hashes;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
