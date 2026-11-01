{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  patchelf,
}:

let
  # Version and per-system hashes live in hashes.json so update.sh can rewrite
  # them without touching Nix code.
  versionData = lib.importJSON ./hashes.json;
  inherit (versionData) version hashes;

  assets = {
    "aarch64-darwin" = "darwin-arm64";
    "aarch64-linux" = "linux-arm64";
    "x86_64-linux" = "linux-x64";
  };

  system = stdenvNoCC.hostPlatform.system;
  isLinux = stdenvNoCC.hostPlatform.isLinux;
  asset = assets.${system} or (throw "1MCP has no prebuilt release for ${system}");
in
stdenvNoCC.mkDerivation {
  pname = "1mcp";
  inherit version;

  # Upstream's release is a Node.js single executable application (SEA): the
  # app is embedded in the node ELF/Mach-O, so never strip it.
  src = fetchurl {
    url = "https://github.com/1mcp-app/agent/releases/download/v${version}/1mcp-${asset}.tar.gz";
    hash = hashes.${system};
  };

  sourceRoot = ".";
  dontStrip = true;
  dontFixup = !isLinux;

  # Node's ELF keeps its text 2 MiB-aligned (it remaps it to huge pages).
  # patchelf 0.19 breaks that when it sets the interpreter before the rpath,
  # which autoPatchelfHook does, and the binary segfaults on start; the other
  # order works with old and new patchelf alike. So patch by hand: rpath,
  # then interpreter. The install check catches a binary that won't start.
  nativeBuildInputs = lib.optional isLinux patchelf;

  installPhase = ''
    runHook preInstall
    install -Dm755 "1mcp-${asset}" "$out/bin/1mcp"
  ''
  + lib.optionalString isLinux ''
    patchelf --set-rpath ${
      lib.makeLibraryPath [
        stdenv.cc.cc.lib
        stdenv.cc.cc.libgcc
      ]
    } "$out/bin/1mcp"
    patchelf --set-interpreter ${stdenv.cc.bintools.dynamicLinker} "$out/bin/1mcp"
  ''
  + ''
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test "$(HOME="$TMPDIR" "$out/bin/1mcp" --version)" = "$version"
    runHook postInstallCheck
  '';

  meta = {
    description = "Unified MCP runtime that aggregates MCP servers behind one endpoint";
    homepage = "https://docs.1mcp.app";
    license = lib.licenses.asl20;
    mainProgram = "1mcp";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = builtins.attrNames hashes;
  };
}
