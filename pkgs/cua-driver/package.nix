{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  runtimeShell,
  gnugrep,
  libx11,
  libxi,
  libxkbcommon,
}:

let
  # Version and per-system hashes live in hashes.json so update.sh can rewrite
  # them; it follows trycua/cua's cua-driver-rs-v<version> releases.
  versionData = lib.importJSON ./hashes.json;
  inherit (versionData) version hashes;

  arch = {
    "aarch64-linux" = "arm64";
    "x86_64-linux" = "x86_64";
  };
  system = stdenvNoCC.hostPlatform.system;
in
stdenvNoCC.mkDerivation {
  pname = "cua-driver";
  inherit version;

  src = fetchurl {
    url = "https://github.com/trycua/cua/releases/download/cua-driver-rs-v${version}/cua-driver-rs-${version}-linux-${
      arch.${system} or (throw "cua-driver: no Linux build for ${system}")
    }-binary.tar.gz";
    hash = hashes.${system};
  };

  sourceRoot = ".";

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [
    libx11
    libxi
    libxkbcommon
    stdenv.cc.cc.lib # libgcc_s
  ];

  # The release keeps its tools side by side; cua-driver finds
  # cua-cursor-theme and the wayland-helper next to itself. The Node addon is
  # for the npm package only. bin/cua-driver is a wrapper (see README.md):
  # telemetry and the update check default to off, `update --apply` (the
  # upstream installer) is refused.
  installPhase = ''
    runHook preInstall
    rm -f cua_driver_node_runtime.node
    mkdir -p $out/libexec/cua-driver $out/bin
    cp -r . $out/libexec/cua-driver
    substitute ${./wrapper.sh} $out/bin/cua-driver \
      --subst-var-by shell ${runtimeShell} \
      --subst-var-by grep ${lib.getExe gnugrep} \
      --subst-var-by driver $out/libexec/cua-driver/cua-driver
    chmod +x $out/bin/cua-driver
    ln -s $out/libexec/cua-driver/cua-cursor-theme $out/bin/cua-cursor-theme
    runHook postInstall
  '';

  # Every library it links resolves (autoPatchelf; ld.so lists them without
  # running cua-cursor-theme, which needs a desktop), and the wrapper starts
  # the pinned version.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    for exe in cua-driver cua-cursor-theme; do
      if LD_TRACE_LOADED_OBJECTS=1 "$out/libexec/cua-driver/$exe" | grep "not found"; then
        exit 1
      fi
    done
    HOME="$TMPDIR" "$out/bin/cua-driver" --version | grep -qx "cua-driver ${version}"
    runHook postInstallCheck
  '';

  meta = {
    description = "Background desktop control driver, used by Hermes' computer_use tool";
    homepage = "https://github.com/trycua/cua";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "cua-driver";
    platforms = builtins.attrNames hashes;
  };
}
