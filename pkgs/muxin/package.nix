{
  lib,
  stdenv,
  fetchurl,
  _7zz,
  autoPatchelfHook,
  makeDesktopItem,
  copyDesktopItems,
  libxcb,
  libxkbcommon,
  vulkan-loader,
  wayland,
}:

let
  # Version and hashes live in hashes.json so update.sh can rewrite them.
  sources = lib.importJSON ./hashes.json;
  inherit (sources) version hashes;
  inherit (stdenv.hostPlatform) system isDarwin;

  asset =
    {
      aarch64-darwin = "macos.dmg";
      x86_64-linux = "linux-x86_64.tar.gz";
      aarch64-linux = "linux-aarch64.tar.gz";
    }
    .${system} or (throw "muxin: unsupported system ${system}");
in
stdenv.mkDerivation {
  pname = "muxin";
  inherit version;

  # Upstream's prebuilt release: on macOS the signed, universal Muxin.app; on
  # Linux the tarball its install.sh copies. Nothing is compiled.
  src = fetchurl {
    url = "https://github.com/LumaryLabsLLC/muxin/releases/download/v${version}/Muxin-${version}-${asset}";
    hash = hashes.${system};
  };

  # The dmg is HFS+, which 7zz reads.
  nativeBuildInputs =
    if isDarwin then
      [ _7zz ]
    else
      [
        autoPatchelfHook
        copyDesktopItems
      ];
  sourceRoot = ".";

  buildInputs = lib.optionals (!isDarwin) [
    libxcb
    libxkbcommon
    stdenv.cc.cc.libgcc
  ];
  # dlopen()ed by the app (GPU and Wayland), so autoPatchelf can't see them.
  runtimeDependencies = lib.optionals (!isDarwin) [
    vulkan-loader
    wayland
  ];

  dontConfigure = true;
  dontBuild = true;
  # Stripping or patching would break the macOS bundle's signature. On Linux
  # the fixup phase is what runs autoPatchelf; the agents are static and
  # skipped by it.
  dontFixup = isDarwin;
  # The agents are copied as they are to the machines Muxin manages: never
  # strip or patch them.
  dontStrip = true;

  desktopItems = lib.optionals (!isDarwin) [
    (makeDesktopItem {
      name = "muxin";
      desktopName = "Muxin";
      comment = "All your machines, one app";
      exec = "muxin";
      icon = "muxin";
      categories = [ "Development" ];
    })
  ];

  # Muxin finds the agent builds it installs on each machine next to its real
  # path (agents/, or ../Resources/agents in the bundle), so keep upstream's
  # layout and link the command to it. `muxen` is its name from before, which
  # upstream's packages install too.
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
  ''
  + (
    if isDarwin then
      ''
        mkdir -p "$out/Applications"
        cp -R "$(find . -maxdepth 2 -type d -name Muxin.app | head -n1)" "$out/Applications/"
        ln -s "$out/Applications/Muxin.app/Contents/MacOS/muxin" "$out/bin/muxin"
      ''
    else
      ''
        mkdir -p "$out/libexec/muxin"
        cp -R Muxin/muxin Muxin/agents "$out/libexec/muxin/"
        ln -s "$out/libexec/muxin/muxin" "$out/bin/muxin"
        install -Dm644 Muxin/muxin.png "$out/share/icons/hicolor/512x512/apps/muxin.png"
      ''
  )
  + ''
    ln -s muxin "$out/bin/muxen"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test "$(HOME="$TMPDIR" "$out/bin/muxin" --version)" = "muxin $version"
    runHook postInstallCheck
  '';

  meta = {
    description = "One app for all your machines and the AI agents on them: sessions, desktops, logs, files and servers over ssh";
    homepage = "https://muxin.dev";
    changelog = "https://github.com/LumaryLabsLLC/muxin/releases/tag/v${version}";
    license = lib.licenses.asl20;
    mainProgram = "muxin";
    platforms = builtins.attrNames hashes;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
