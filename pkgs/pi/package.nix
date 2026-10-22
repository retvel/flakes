{
  lib,
  stdenvNoCC,
  stdenv,
  nodejs_24,
  importNpmLock,
  makeWrapper,
  autoPatchelfHook,
  libxcb,
  fd,
  ripgrep,
  wl-clipboard,
  xclip,
}:

let
  nodejs = nodejs_24;
  versionData = lib.importJSON ./hashes.json;
  npmRoot = ./install-lock;
  packageJson = lib.importJSON (npmRoot + "/package.json");
  nativeTarget =
    {
      aarch64-darwin = "darwin-arm64";
      aarch64-linux = "linux-arm64";
      x86_64-linux = "linux-x64";
    }
    .${stdenv.hostPlatform.system};
  nativePlatform = if stdenv.hostPlatform.isDarwin then "darwin" else "linux";
  nativeFile = "${nativePlatform}-platform${lib.optionalString stdenv.hostPlatform.isLinux "-x11"}.node";
in
assert packageJson.dependencies."@earendil-works/pi-coding-agent" == versionData.version;
stdenvNoCC.mkDerivation {
  pname = "pi";
  inherit (versionData) version;
  src = npmRoot;

  npmDeps = importNpmLock { inherit npmRoot; };
  # Published npm packages contain built JS, WASM and native helpers. Never run
  # dependency lifecycle scripts or upstream's TypeScript/Bun/native builds.
  npmRebuildFlags = [ "--ignore-scripts" ];
  nativeBuildInputs = [
    nodejs
    importNpmLock.npmConfigHook
    makeWrapper
  ]
  ++ lib.optional stdenv.hostPlatform.isLinux autoPatchelfHook;
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.cc.lib
    libxcb
  ];
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/pi" "$out/bin"
    cp -R . "$out/lib/pi"
    makeWrapper ${nodejs}/bin/node "$out/bin/pi" \
      --set PI_PACKAGE_DIR "$out/lib/pi/node_modules/@earendil-works/pi-coding-agent" \
      --add-flags "$out/lib/pi/node_modules/@earendil-works/pi-coding-agent/dist/bundle/cli.js" \
      --suffix PATH : ${lib.makeBinPath [ nodejs ]} \
      --prefix PATH : ${
        lib.makeBinPath (
          [
            fd
            ripgrep
          ]
          ++ lib.optionals stdenv.hostPlatform.isLinux [
            wl-clipboard
            xclip
          ]
        )
      }
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test "$("$out/bin/pi" --version)" = "$version"
    ${nodejs}/bin/node -e \
      "require('$out/lib/pi/node_modules/@earendil-works/pi-tui/native/${nativePlatform}/prebuilds/${nativeTarget}/${nativeFile}')"
    ${nodejs}/bin/node -e \
      "require('$out/lib/pi/node_modules/@silvia-odwyer/photon-node')"
    runHook postInstallCheck
  '';

  meta = {
    description = "Pi coding agent, assembled from upstream npm releases with Node.js 24 LTS";
    homepage = "https://pi.dev";
    license = lib.licenses.mit;
    mainProgram = "pi";
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
    sourceProvenance = with lib.sourceTypes; [
      binaryBytecode
      binaryNativeCode
    ];
  };
}
