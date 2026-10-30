{
  lib,
  stdenv,
  fetchurl,
  installShellFiles,
  patchelf,
}:

let
  # Version and hashes live in hashes.json so update.sh can rewrite them.
  sources = lib.importJSON ./hashes.json;
  inherit (sources) version hashes;
  inherit (stdenv.hostPlatform) system isLinux;

  # npm's per-platform package of @openai/codex, and the target it ships.
  target =
    {
      aarch64-darwin = {
        npm = "darwin-arm64";
        triple = "aarch64-apple-darwin";
      };
      x86_64-linux = {
        npm = "linux-x64";
        triple = "x86_64-unknown-linux-musl";
      };
      aarch64-linux = {
        npm = "linux-arm64";
        triple = "aarch64-unknown-linux-musl";
      };
    }
    .${system} or (throw "codex: unsupported system ${system}");
in
stdenv.mkDerivation {
  pname = "codex";
  inherit version;

  # Upstream's prebuilt release, as published to npm (what `npm install -g
  # @openai/codex` runs); nothing is compiled. The tarball is upstream's whole
  # package layout: bin/, codex-resources/, codex-path/, codex-package.json.
  src = fetchurl {
    url = "https://registry.npmjs.org/@openai/codex/-/codex-${version}-${target.npm}.tgz";
    hash = hashes.${system};
  };
  sourceRoot = "package/vendor/${target.triple}";

  nativeBuildInputs = [ installShellFiles ] ++ lib.optional isLinux patchelf;

  dontConfigure = true;
  dontBuild = true;
  # Ship upstream's binaries as they are: the macOS ones are signed, the Linux
  # ones are static (musl).
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    # Codex finds its resources, rg and code-mode host next to its real path,
    # so keep the layout and link the entry point.
    mkdir -p "$out/libexec" "$out/bin"
    cp -R . "$out/libexec/codex"
    ln -s ../libexec/codex/bin/codex "$out/bin/codex"
  ''
  + lib.optionalString isLinux ''
    # The voice host (and its bundled GStreamer) is the one glibc program;
    # it needs only glibc, so point it at Nix's loader. Its libraries are
    # found through its own $ORIGIN/../lib.
    patchelf --set-interpreter ${stdenv.cc.bintools.dynamicLinker} \
      "$out/libexec/codex/codex-resources/voice/bin/codex-voice-host"
  ''
  + ''
    export HOME="$TMPDIR"
    installShellCompletion --cmd codex \
      --bash <("$out/bin/codex" completion bash) \
      --fish <("$out/bin/codex" completion fish) \
      --zsh <("$out/bin/codex" completion zsh)
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test "$("$out/bin/codex" --version)" = "codex-cli $version"
    runHook postInstallCheck
  '';

  meta = {
    description = "OpenAI Codex CLI, a coding agent that runs locally (upstream's prebuilt release)";
    homepage = "https://github.com/openai/codex";
    changelog = "https://github.com/openai/codex/releases/tag/rust-v${version}";
    license = lib.licenses.asl20;
    mainProgram = "codex";
    platforms = [
      "aarch64-darwin"
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
