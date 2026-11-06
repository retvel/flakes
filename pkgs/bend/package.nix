{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  patchelf,
  clang,
}:

let
  # Version and hashes live in hashes.json so update.sh can rewrite them.
  sources = lib.importJSON ./hashes.json;
  inherit (sources) version hashes;
  inherit (stdenv.hostPlatform) system isLinux;

  platform =
    {
      aarch64-darwin = "darwin-arm64";
      x86_64-linux = "linux-x64";
      aarch64-linux = "linux-arm64";
    }
    .${system} or (throw "bend: unsupported system ${system}");
in
stdenv.mkDerivation {
  pname = "bend";
  inherit version;

  # Upstream's prebuilt release, the archive bend-lang.com/install.sh installs:
  # one Bun-compiled binary, Base and the effects (bend2/) and the guide.
  # Nothing is compiled.
  src = fetchurl {
    url = "https://github.com/bendlang/bend/releases/download/v${version}/bend-${version}-${platform}.tar.gz";
    hash = hashes.${system};
  };

  sourceRoot = "bend";

  nativeBuildInputs = [ makeWrapper ] ++ lib.optional isLinux patchelf;

  dontConfigure = true;
  dontBuild = true;
  # Ship upstream's binary as it is: signed on macOS, and stripping would cut
  # off the program Bun appends to it.
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    # The layout install.sh makes under ~/.bend: bend finds bend2/ and guide/
    # beside the directory its binary is in.
    mkdir -p "$out/libexec/bend"
    cp -r bend2 guide "$out/libexec/bend/"
    install -Dm755 bin/bend "$out/libexec/bend/bin/bend"
  ''
  + lib.optionalString isLinux ''
    # Linked against glibc only; point it at Nix's loader.
    patchelf --set-interpreter ${stdenv.cc.bintools.dynamicLinker} "$out/libexec/bend/bin/bend"
  ''
  + ''
    # Updates come through this flake: no daily update check unless the user
    # sets BEND_NO_TELEMETRY themselves, and no `bend update`, which would
    # install a second copy into ~/.bend.
    makeWrapper "$out/libexec/bend/bin/bend" "$out/bin/bend" \
      --set-default BEND_NO_TELEMETRY 1 \
      ${lib.optionalString isLinux ''
        --suffix PATH : ${lib.makeBinPath [ clang ]} \
      ''} --run ${lib.escapeShellArg ''
        if [ "$#" -eq 1 ] && [ "$1" = update ]; then
          echo "bend: installed through Nix; update the flake input that provides it instead" >&2
          exit 1
        fi
      ''}
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME="$TMPDIR"
    test "$("$out/bin/bend" version)" = "bend $version"
    "$out/bin/bend" guide | grep -q 'Hello, World!'
  ''
  + lib.optionalString isLinux ''
    # Running an IO program builds it with clang first.
    cat > "$TMPDIR/hello.bend" <<'BEND'
    import Base

    def main() -> IO(Unit):
      do IO<Unit>:
        IO.print("Hello, world!")
    BEND
    test "$(cd "$TMPDIR" && "$out/bin/bend" hello.bend)" = "Hello, world!"
  ''
  + ''
    runHook postInstallCheck
  '';

  meta = {
    description = "Bend, a parallel functional language that runs on CPUs and GPUs (upstream's prebuilt release)";
    homepage = "https://bend-lang.com";
    license = lib.licenses.asl20;
    mainProgram = "bend";
    platforms = [
      "aarch64-darwin"
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
