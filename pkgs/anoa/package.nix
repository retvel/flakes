{
  lib,
  stdenvNoCC,
  fetchurl,
  buildFHSEnv,
}:

let
  # Version and per-system hashes live in hashes.json so update.sh can rewrite
  # them without touching Nix code.
  versionData = lib.importJSON ./hashes.json;
  inherit (versionData) version hashes;

  assets = {
    "aarch64-linux" = "linux-aarch64";
    "x86_64-linux" = "linux-x86_64";
  };

  system = stdenvNoCC.hostPlatform.system;
  asset = assets.${system} or (throw "anoa has no prebuilt Linux release for ${system}");

  meta = {
    description = "Headless browser with full CDP support and a command per action for agents, from the upstream Linux bundle";
    homepage = "https://github.com/porcupine-md/anoa-browser";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "anoa";
    platforms = builtins.attrNames hashes;
  };

  # The portable bundle as released: one binary with Qt 6 and QtWebEngine
  # (Chromium) in lib/, and anoa.sh, which sets Qt's paths and puts its own
  # GL, X11, libstdc++ and NSS copies (lib/hostfirst) on the library path for
  # whichever of them the host lacks. Left as released and run in an FHS
  # environment below, so anoa.sh's host-library logic works unchanged.
  bundle = stdenvNoCC.mkDerivation {
    pname = "anoa-bundle";
    inherit version meta;

    src = fetchurl {
      url = "https://github.com/porcupine-md/anoa-browser/releases/download/v${version}/anoa-${asset}.tar.gz";
      hash = hashes.${system};
    };

    sourceRoot = "anoa";
    dontConfigure = true;
    dontBuild = true;
    dontFixup = true;

    installPhase = ''
      runHook preInstall
      cp -r . $out
      runHook postInstall
    '';
  };
in
# A glibc FHS environment for the unpatched binaries, like the Ubuntu
# upstream builds on.
buildFHSEnv {
  pname = "anoa";
  inherit version meta;

  # Libraries the bundle expects from the host and does not ship: Chromium
  # aborts at startup (SIGTRAP) without libudev, and Qt's TLS backend
  # dlopen()s libssl.so.3. NSS too: anoa.sh only takes its own copy when
  # ldconfig does not list the host's, and that copy then fails to load
  # libsoftokn3, so every HTTPS page aborts the browser.
  targetPkgs = pkgs: [
    pkgs.udev
    pkgs.openssl
    pkgs.nss
    pkgs.nspr
  ];

  runScript = "${bundle}/anoa.sh";
}
