{
  lib,
  stdenvNoCC,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:

let
  versionData = lib.importJSON ./hashes.json;
  npmSrc = fetchurl {
    url = "https://registry.npmjs.org/npm/-/npm-${versionData.npm.version}.tgz";
    hash = versionData.npm.hash;
  };
  target =
    {
      aarch64-darwin = "darwin-arm64";
      aarch64-linux = "linux-arm64";
      x86_64-linux = "linux-x64";
    }
    .${stdenv.hostPlatform.system};
in
stdenvNoCC.mkDerivation {
  pname = "nodejs-24-lts";
  inherit (versionData) version;
  src = fetchurl {
    url = "https://nodejs.org/dist/v${versionData.version}/node-v${versionData.version}-${target}.tar.xz";
    hash = versionData.hashes.${stdenv.hostPlatform.system};
  };

  nativeBuildInputs = lib.optional stdenv.hostPlatform.isLinux autoPatchelfHook;
  buildInputs = lib.optional stdenv.hostPlatform.isLinux stdenv.cc.cc.lib;
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -R . "$out/"
    # Replace bundled npm with the independently pinned official npm release.
    # npm's tarball includes its dependencies; no npm install/scripts are needed.
    rm -rf "$out/lib/node_modules/npm"
    mkdir -p "$out/lib/node_modules/npm"
    tar -xzf ${npmSrc} --strip-components=1 -C "$out/lib/node_modules/npm"
    # npm/npx use upstream's env-node shebang. Pin those JS launchers to this
    # runtime without modifying the signed Mach-O Node executable on macOS.
    for script in "$out/lib/node_modules/npm/bin/npm-cli.js" "$out/lib/node_modules/npm/bin/npx-cli.js"; do
      substituteInPlace "$script" \
        --replace-fail '#!/usr/bin/env node' "#!$out/bin/node"
    done
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test "$("$out/bin/node" --version)" = "v$version"
    test "$("$out/bin/npm" --version)" = "${versionData.npm.version}"
    test "$("$out/bin/npx" --version)" = "${versionData.npm.version}"
    runHook postInstallCheck
  '';

  meta = {
    description = "Official prebuilt Node.js 24 LTS with independently pinned latest compatible npm";
    homepage = "https://nodejs.org";
    license = lib.licenses.mit;
    mainProgram = "node";
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
