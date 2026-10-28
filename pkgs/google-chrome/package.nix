{
  lib,
  stdenvNoCC,
  fetchurl,
  undmg,
}:

let
  # Version, URL and hash live in hashes.json so update.sh can rewrite them.
  # The URL carries an id from Google's update server that can't be derived
  # from the version, so it is pinned too.
  sources = lib.importJSON ./hashes.json;
  inherit (sources) version url hashes;
in
stdenvNoCC.mkDerivation {
  pname = "google-chrome";
  inherit version;

  # Google's signed, notarized universal Google Chrome.app; nothing is compiled.
  src = fetchurl {
    inherit url;
    hash = hashes."GoogleChrome.dmg";
  };

  nativeBuildInputs = [ undmg ];
  sourceRoot = ".";

  dontConfigure = true;
  dontBuild = true;
  # Stripping or patching would break the bundle's code signature.
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications" "$out/bin"
    cp -R "Google Chrome.app" "$out/Applications/"
    # Exec by full path so Chrome finds its framework inside the bundle.
    cat > "$out/bin/google-chrome" <<SH
    #!/bin/sh
    exec "$out/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" "\$@"
    SH
    chmod +x "$out/bin/google-chrome"
    runHook postInstall
  '';

  meta = {
    description = "Google Chrome web browser, latest Stable channel release (upstream Google Chrome.app)";
    homepage = "https://www.google.com/chrome/";
    changelog = "https://chromereleases.googleblog.com/";
    license = lib.licenses.unfree;
    mainProgram = "google-chrome";
    # Universal binary. On Linux use nixpkgs' google-chrome.
    platforms = lib.platforms.darwin;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
