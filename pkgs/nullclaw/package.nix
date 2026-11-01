{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  # Version and per-system hashes live in hashes.json so update.sh can rewrite
  # them without touching Nix code.
  sources = lib.importJSON ./hashes.json;
  inherit (sources) version hashes;

  targets = {
    "aarch64-darwin" = "macos-aarch64";
    "aarch64-linux" = "linux-aarch64";
    "x86_64-linux" = "linux-x86_64";
  };

  system = stdenvNoCC.hostPlatform.system;
  target = targets.${system} or (throw "NullClaw has no prebuilt release for ${system}");
in
stdenvNoCC.mkDerivation {
  pname = "nullclaw";
  inherit version;

  src = fetchurl {
    url = "https://github.com/nullclaw/nullclaw/releases/download/v${version}/nullclaw-${target}.bin";
    hash = hashes.${system};
  };

  # Upstream ships stripped binaries: static musl on Linux, signed on macOS.
  dontUnpack = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/nullclaw"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test "$(HOME="$TMPDIR" "$out/bin/nullclaw" --version)" = "nullclaw $version"
    runHook postInstallCheck
  '';

  meta = {
    description = "Small, fully autonomous AI assistant infrastructure written in Zig";
    homepage = "https://github.com/nullclaw/nullclaw";
    license = lib.licenses.mit;
    mainProgram = "nullclaw";
    platforms = builtins.attrNames hashes;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
