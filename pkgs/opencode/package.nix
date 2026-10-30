{
  lib,
  stdenv,
  fetchurl,
  installShellFiles,
  makeWrapper,
  patchelf,
  ripgrep,
}:

let
  # Version and hashes live in hashes.json so update.sh can rewrite them.
  sources = lib.importJSON ./hashes.json;
  inherit (sources) version hashes;
  inherit (stdenv.hostPlatform) system isLinux;

  # npm's per-platform package of OpenCode 2 (@opencode/cli-<platform>).
  npm =
    {
      aarch64-darwin = "darwin-arm64";
      x86_64-linux = "linux-x64";
      aarch64-linux = "linux-arm64";
    }
    .${system} or (throw "opencode: unsupported system ${system}");
in
stdenv.mkDerivation {
  pname = "opencode";
  inherit version;

  # Upstream's prebuilt release as published to npm (what opencode.ai/v2/install
  # installs): one Bun-compiled binary. Nothing is compiled.
  src = fetchurl {
    url = "https://registry.npmjs.org/@opencode/cli-${npm}/-/cli-${npm}-${version}.tgz";
    hash = hashes.${system};
  };

  nativeBuildInputs = [
    installShellFiles
    makeWrapper
  ]
  ++ lib.optional isLinux patchelf;

  dontConfigure = true;
  dontBuild = true;
  # Ship upstream's binary as it is: signed on macOS, and stripping would cut
  # off the program Bun appends to it.
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 bin/opencode "$out/libexec/opencode"
  ''
  + lib.optionalString isLinux ''
    # Linked against glibc only; point it at Nix's loader.
    patchelf --set-interpreter ${stdenv.cc.bintools.dynamicLinker} "$out/libexec/opencode"
  ''
  + ''
    # Updates come through this flake: no update check, and no `opencode
    # upgrade` (or its alias `update`), which would install a second copy
    # into ~/.opencode/bin.
    # OpenCode downloads ripgrep into ~/.cache/opencode/bin unless one is on
    # PATH; appended, so the user's own still comes first.
    makeWrapper "$out/libexec/opencode" "$out/bin/opencode" \
      --set OPENCODE_DISABLE_AUTOUPDATE 1 \
      --suffix PATH : ${lib.makeBinPath [ ripgrep ]} \
      --run ${lib.escapeShellArg ''
        if [ "''${1-}" = upgrade ] || [ "''${1-}" = update ]; then
          echo "opencode: installed through Nix; update the flake input that provides it instead" >&2
          exit 1
        fi
      ''}

    export HOME="$TMPDIR"
    installShellCompletion --cmd opencode \
      --bash <("$out/bin/opencode" --completions bash) \
      --fish <("$out/bin/opencode" --completions fish) \
      --zsh <("$out/bin/opencode" --completions zsh)
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME="$TMPDIR"
    test "$("$out/bin/opencode" --version)" = "opencode v$version"
    runHook postInstallCheck
  '';

  meta = {
    description = "OpenCode, an open-source AI coding agent for the terminal (upstream's prebuilt release)";
    homepage = "https://opencode.ai";
    license = lib.licenses.mit;
    mainProgram = "opencode";
    platforms = [
      "aarch64-darwin"
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
