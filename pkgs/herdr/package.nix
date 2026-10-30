{
  lib,
  stdenv,
  fetchurl,
  undmg,
  autoPatchelfHook,
  makeDesktopItem,
  copyDesktopItems,
  runtimeShell,
  curl,
  jq,
  coreutils,
  findutils,
  libnotify,
  fontconfig,
  libglvnd,
  libxcb,
  libxkbcommon,
  wayland,
  vulkan-loader,
}:

let
  # Versions and hashes live in hashes.json so update.sh can rewrite them.
  sources = lib.importJSON ./hashes.json;
  inherit (sources) version hashes;
  inherit (stdenv.hostPlatform) system isDarwin;

  target =
    {
      aarch64-darwin = "macos-aarch64";
      x86_64-linux = "linux-x86_64";
      aarch64-linux = "linux-aarch64";
    }
    .${system} or (throw "herdr: unsupported system ${system}");

  # app/Herdr.dmg and app/latest.json always point at the latest release, so
  # pin the versioned copies next to them.
  app = fetchurl {
    url =
      if isDarwin then
        "https://releases.herdr.dev/app/${sources.app}/Herdr.dmg"
      else
        "https://releases.herdr.dev/app/${sources.app}/herdr-app-${target}.tar.gz";
    hash = hashes."app-${system}";
  };

  # herdr-core (`hc`) runs the terminals in the background; the app finds it on
  # PATH.
  core = fetchurl {
    url = "https://releases.herdr.dev/core/${sources.core}/herdr-core-${target}.tar.gz";
    hash = hashes."core-${system}";
  };

  # See herdr-app.sh.
  checkPath = lib.makeBinPath (
    [
      curl
      jq
      coreutils
      findutils
    ]
    ++ lib.optional (!isDarwin) libnotify
  );
in
stdenv.mkDerivation {
  pname = "herdr";
  inherit version;

  # Upstream's prebuilt binaries; nothing is compiled.
  srcs = [
    app
    core
  ];
  sourceRoot = ".";

  nativeBuildInputs =
    if isDarwin then
      [ undmg ]
    else
      [
        autoPatchelfHook
        copyDesktopItems
      ];
  buildInputs = lib.optionals (!isDarwin) [
    # Linked on aarch64 only.
    fontconfig.lib
    libxcb
    libxkbcommon
    stdenv.cc.cc.lib
  ];
  # dlopen()ed by the Linux app, so autoPatchelf can't see them.
  runtimeDependencies = lib.optionals (!isDarwin) [
    libglvnd
    libxkbcommon
    vulkan-loader
    wayland
  ];

  dontConfigure = true;
  dontBuild = true;
  # Stripping or patching would break the bundle's code signature. On Linux the
  # fixup phase is what runs autoPatchelf.
  dontFixup = isDarwin;

  desktopItems = lib.optionals (!isDarwin) [
    (makeDesktopItem {
      name = "herdr-app";
      desktopName = "Herdr";
      exec = "herdr-app";
      icon = "herdr-app";
      categories = [ "Development" ];
    })
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    install -m755 herdr-core "$out/bin/herdr-core"
    ln -s herdr-core "$out/bin/hc"
  ''
  + (
    if isDarwin then
      ''
        mkdir -p "$out/Applications"
        cp -R Herdr.app "$out/Applications/"
        # Exec by full path so the app finds its resources inside the bundle.
        exe="$out/Applications/Herdr.app/Contents/MacOS/Herdr"
      ''
    else
      ''
        install -Dm755 herdr-app/herdr-app "$out/libexec/herdr-app"
        install -Dm644 herdr-app/herdr-app.svg \
          "$out/share/icons/hicolor/scalable/apps/herdr-app.svg"
        exe="$out/libexec/herdr-app"
      ''
  )
  + ''
    # The pinned release manifests, served to the app by the wrapper.
    releases="$out/share/herdr/releases"
    install -Dm644 ${./app-latest.json} "$releases/app/latest.json"
    install -Dm644 ${./core-latest.json} "$releases/core/latest.json"
    install -Dm644 ${./core-latest.json} "$releases/core/${sources.core}/manifest.json"

    substitute ${./herdr-app.sh} "$out/bin/herdr-app" \
      --subst-var-by shell ${runtimeShell} \
      --subst-var-by releases "$releases" \
      --subst-var-by appPath "$out/bin:${lib.makeBinPath [ curl ]}" \
      --subst-var-by checkPath ${checkPath} \
      --subst-var-by appVersion ${sources.app} \
      --subst-var-by coreVersion ${sources.core} \
      --subst-var-by exe "$exe"
    chmod +x "$out/bin/herdr-app"
    runHook postInstall
  '';

  meta = {
    description = "Herdr desktop app with herdr-core (hc), which keeps its terminals and agents running";
    homepage = "https://herdr.dev/";
    license = lib.licenses.asl20;
    mainProgram = "herdr-app";
    # The dmg is arm64 only; Intel Macs get no app.
    platforms = [
      "aarch64-darwin"
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
