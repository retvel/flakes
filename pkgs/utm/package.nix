{
  lib,
  stdenvNoCC,
  fetchurl,
  undmg,
}:

let
  # Version and hash live in hashes.json so update.sh can rewrite them.
  sources = lib.importJSON ./hashes.json;
  inherit (sources) version hashes;
in
stdenvNoCC.mkDerivation {
  pname = "utm";
  inherit version;

  # Upstream's signed, notarized universal UTM.app; nothing is compiled.
  src = fetchurl {
    url = "https://github.com/utmapp/UTM/releases/download/v${version}/UTM.dmg";
    hash = hashes."UTM.dmg";
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
    cp -R UTM.app "$out/Applications/"
    # Exec by full path: a symlink in bin/ makes UTM look for its resources in
    # the wrong place.
    for prog in UTM utmctl; do
      cat > "$out/bin/$prog" <<SH
    #!/bin/sh
    exec "$out/Applications/UTM.app/Contents/MacOS/$prog" "\$@"
    SH
      chmod +x "$out/bin/$prog"
    done
    runHook postInstall
  '';

  meta = {
    description = "Virtual machine host for macOS based on QEMU and Virtualization.framework (upstream UTM.app)";
    homepage = "https://mac.getutm.app/";
    changelog = "https://github.com/utmapp/UTM/releases/tag/v${version}";
    license = lib.licenses.asl20;
    mainProgram = "utmctl";
    # Universal binary; macOS 12 or later.
    platforms = lib.platforms.darwin;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
