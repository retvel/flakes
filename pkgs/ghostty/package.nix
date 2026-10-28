{
  lib,
  stdenvNoCC,
  fetchurl,
  _7zz,
  tip ? false, # true: upstream's rolling `tip` build from main
}:

let
  # Version and hash live in hashes.json so update.sh can rewrite them. The tip
  # has its own, bumped daily.
  sources = lib.importJSON (if tip then ../ghostty-tip/hashes.json else ./hashes.json);
  inherit (sources) version hashes;
in
stdenvNoCC.mkDerivation {
  pname = if tip then "ghostty-tip" else "ghostty";
  inherit version;

  # Upstream's signed, notarized universal Ghostty.app; nothing is compiled.
  # Tagged releases live on upstream's file host, not as GitHub release assets.
  # The tip URL is reused by every tip build, so a tip pin only downloads until
  # the next one.
  src = fetchurl {
    url =
      if tip then
        "https://github.com/ghostty-org/ghostty/releases/download/tip/Ghostty.dmg"
      else
        "https://release.files.ghostty.org/${version}/Ghostty.dmg";
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
    description =
      if tip then
        "Ghostty terminal emulator, rolling tip build from main (upstream Ghostty.app)"
      else
        "Ghostty terminal emulator (upstream Ghostty.app)";
    homepage = "https://ghostty.org/";
    downloadPage =
      if tip then
        "https://github.com/ghostty-org/ghostty/releases/tag/tip"
      else
        "https://ghostty.org/download";
    changelog =
      lib.optionalString (!tip)
        "https://ghostty.org/docs/install/release-notes/${lib.replaceStrings [ "." ] [ "-" ] version}";
    license = lib.licenses.mit;
    mainProgram = "ghostty";
    outputsToInstall = [
      "out"
      "man"
      "shell_integration"
      "terminfo"
    ];
    # Universal binary. On Linux upstream ships source only; use nixpkgs'
    # ghostty or upstream's flake there.
    platforms = lib.platforms.darwin;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
