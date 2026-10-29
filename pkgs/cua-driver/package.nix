{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  libx11,
  libxi,
  libxkbcommon,
}:

let
  # Not tracked on its own: the version, URL and hash come from Hermes'
  # pm/lock.json at the commit pkgs/hermes-agent pins, so this is always the
  # cua-driver that Tier 1 (`hermes pm install cua-driver`) installs for that
  # Hermes release, and it moves with each hermes-agent bump.
  pin = lib.importJSON ../hermes-agent/hashes.json;
  hermesSrc = builtins.fetchTree {
    type = "github";
    owner = "NousResearch";
    repo = "hermes-agent";
    inherit (pin) rev narHash;
  };
  locked = (lib.importJSON "${hermesSrc}/pm/lock.json").packages.cua-driver;

  targets = {
    "aarch64-linux" = "linux-arm64";
    "x86_64-linux" = "linux-x64";
  };
  system = stdenvNoCC.hostPlatform.system;
  artifact =
    locked.artifacts.${targets.${system} or (throw "cua-driver: no Linux build for ${system}")};
in
stdenvNoCC.mkDerivation {
  pname = "cua-driver";
  inherit (locked) version;

  src = fetchurl {
    inherit (artifact) url sha256;
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
  # for the npm package only.
  installPhase = ''
    runHook preInstall
    rm -f cua_driver_node_runtime.node
    mkdir -p $out/libexec/cua-driver $out/bin
    cp -r . $out/libexec/cua-driver
    ln -s $out/libexec/cua-driver/cua-driver $out/bin/cua-driver
    ln -s $out/libexec/cua-driver/cua-cursor-theme $out/bin/cua-cursor-theme
    runHook postInstall
  '';

  meta = {
    description = "Background desktop control driver for Hermes' computer_use tool, the build Hermes' pm lock pins";
    homepage = "https://github.com/trycua/cua";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "cua-driver";
    platforms = builtins.attrNames targets;
  };
}
