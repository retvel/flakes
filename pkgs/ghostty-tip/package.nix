{
  lib,
  stdenvNoCC,
  fetchurl,
  _7zz,
}:

let
  # Version and hash live in hashes.json so update.sh can rewrite them.
  sources = lib.importJSON ./hashes.json;
  inherit (sources) version hashes;
in
stdenvNoCC.mkDerivation {
  pname = "ghostty-tip";
  inherit version;

  # Upstream's signed, notarized universal Ghostty.app from the rolling `tip`
  # release; nothing is compiled. The URL is reused by every tip build, so a
  # pin only downloads until the next one.
  src = fetchurl {
    url = "https://github.com/ghostty-org/ghostty/releases/download/tip/Ghostty.dmg";
    hash = hashes."Ghostty.dmg";
  };

  # The dmg is APFS, which undmg can't read.
  nativeBuildInputs = [ _7zz ];
  sourceRoot = ".";

  # Same outputs as nixpkgs' ghostty-bin, so it can stand in for it (e.g. as
  # Home Manager's programs.ghostty.package).
  outputs = [
    "out"
    "man"
    "shell_integration"
    "terminfo"
    "vim"
  ];

  dontConfigure = true;
  dontBuild = true;
  # Stripping or patching would break the bundle's code signature.
  dontFixup = true;

  # Ghostty finds its resources relative to the bundle, so the app stays whole
  # and the extra outputs are copies, not moves.
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications" "$out/bin" "$man/share" "$terminfo/share"
    cp -R Ghostty.app "$out/Applications/"
    res="$out/Applications/Ghostty.app/Contents/Resources"
    # Exec by full path so Ghostty sees itself inside the bundle.
    cat > "$out/bin/ghostty" <<SH
    #!/bin/sh
    exec "$out/Applications/Ghostty.app/Contents/MacOS/ghostty" "\$@"
    SH
    chmod +x "$out/bin/ghostty"
    cp -R "$res/man" "$man/share/man"
    cp -R "$res/terminfo" "$terminfo/share/terminfo"
    cp -R "$res/ghostty/shell-integration" "$shell_integration"
    cp -R "$res/vim/vimfiles" "$vim"
    runHook postInstall
  '';

  meta = {
    description = "Ghostty terminal emulator, rolling tip build from main (upstream Ghostty.app)";
    homepage = "https://ghostty.org/";
    downloadPage = "https://github.com/ghostty-org/ghostty/releases/tag/tip";
    license = lib.licenses.mit;
    mainProgram = "ghostty";
    outputsToInstall = [
      "out"
      "man"
      "shell_integration"
      "terminfo"
    ];
    # Universal binary. Linux tip is source-only; use upstream's flake there.
    platforms = lib.platforms.darwin;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
