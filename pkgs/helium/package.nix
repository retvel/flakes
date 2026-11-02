{
  lib,
  python3,
  stdenvNoCC,
  fetchurl,
  undmg,
}:

let
  # Version and hashes live in hashes.json so update.sh can rewrite them.
  sources = lib.importJSON ./hashes.json;
  inherit (sources) version hashes;
  inherit (stdenvNoCC.hostPlatform) system;
in
stdenvNoCC.mkDerivation {
  pname = "helium";
  inherit version;

  # Upstream's signed, notarized Helium.app for Apple Silicon; nothing is
  # compiled.
  src = fetchurl {
    url = "https://github.com/imputnet/helium-macos/releases/download/${version}/helium_${version}_arm64-macos.dmg";
    hash = hashes.${system} or (throw "helium: unsupported system ${system}");
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
    cp -R Helium.app "$out/Applications/"
    # Exec by full path so Helium finds its framework inside the bundle.
    cat > "$out/bin/helium" <<SH
    #!/bin/sh
    exec "$out/Applications/Helium.app/Contents/MacOS/Helium" "\$@"
    SH
    chmod +x "$out/bin/helium"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    ${python3.interpreter} ${../../lib/check-app.py} "$out/Applications/Helium.app" "$version"
    runHook postInstallCheck
  '';

  meta = {
    description = "Helium web browser, Chromium-based and private by default (upstream Helium.app)";
    homepage = "https://helium.computer/";
    changelog = "https://github.com/imputnet/helium-macos/releases/tag/${version}";
    license = lib.licenses.gpl3Only;
    mainProgram = "helium";
    # macOS 13 or later.
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
