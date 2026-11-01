{
  lib,
  stdenvNoCC,
  stdenv,
  nodejs-24-lts,
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
  nodejs = nodejs-24-lts;
  versionData = lib.importJSON ./hashes.json;
  # Dependencies raised above upstream's lock for security fixes (see
  # overrides.json and update.py); install-lock already resolves to them.
  overrides = versionData.overrides or { };
  npmRoot = ./install-lock;
  packageJson = lib.importJSON (npmRoot + "/package.json");
  nativeTarget =
    {
      aarch64-darwin = "darwin-arm64";
      aarch64-linux = "linux-arm64";
      x86_64-linux = "linux-x64";
    }
    .${stdenv.hostPlatform.system} or (throw "pi: unsupported system ${stdenv.hostPlatform.system}");
  nativePlatform = if stdenv.hostPlatform.isDarwin then "darwin" else "linux";
  nativeFile = "${nativePlatform}-platform${lib.optionalString stdenv.hostPlatform.isLinux "-x11"}.node";
in
assert packageJson.dependencies."@earendil-works/pi-coding-agent" == versionData.version;
assert lib.all (name: packageJson.overrides.${name} or null == overrides.${name}) (
  builtins.attrNames overrides
);
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
    # Only retain native helpers for the host. In particular, foreign ELF
    # helpers should not enter Darwin's output or its RPATH audit.
    native="$out/lib/pi/node_modules/@earendil-works/pi-tui/native"
    for platform in darwin linux win32; do
      if [ "$platform" != "${nativePlatform}" ]; then
        rm -rf "$native/$platform/prebuilds"
      else
        find "$native/$platform/prebuilds" -mindepth 1 -maxdepth 1 \
          ! -name '${nativeTarget}' -exec rm -rf -- {} +
      fi
    done
    # dist/cli.js, not the bin's dist/bundle/cli.js: the bundle carries its
    # own copies of its dependencies (undici, minimatch, ...), so overrides
    # would not reach it. Upstream supports both ("unbundled" in its
    # config.js); the setup they run is the same.
    makeWrapper ${nodejs}/bin/node "$out/bin/pi" \
      --set PI_PACKAGE_DIR "$out/lib/pi/node_modules/@earendil-works/pi-coding-agent" \
      --set-default PI_SKIP_VERSION_CHECK 1 \
      --set-default PI_TELEMETRY 0 \
      --add-flags "$out/lib/pi/node_modules/@earendil-works/pi-coding-agent/dist/cli.js" \
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
    # Each override is what is installed, and still offers what Pi uses.
    cd "$out/lib/pi"
    ${lib.concatStrings (
      lib.mapAttrsToList (name: version: ''
        test "$(${nodejs}/bin/node -p "require('./node_modules/${name}/package.json').version")" = ${version}
      '') overrides
    )}
    ${nodejs}/bin/node --input-type=module -e "
      import { minimatch } from 'minimatch';
      import * as undici from 'undici';
      if (!minimatch('anthropic/claude-x', 'anthropic/*', { nocase: true })) throw 'minimatch';
      if (!minimatch('skills/a/SKILL.md', '**/SKILL.md')) throw 'minimatch globstar';
      for (const k of ['Client', 'Pool', 'EnvHttpProxyAgent', 'install', 'setGlobalDispatcher'])
        if (!undici[k]) throw 'undici.' + k;
      undici.setGlobalDispatcher(new undici.EnvHttpProxyAgent());
    "
    cd - >/dev/null
    HOME="$TMPDIR" "$out/bin/pi" --help >/dev/null
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
