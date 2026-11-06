{
  lib,
  python3,
  stdenv,
  stdenvNoCC,
  fetchurl,
  undmg,
  makeWrapper,
  patchelf,
  addDriverRunpath,
  adwaita-icon-theme,
  gsettings-desktop-schemas,
  gtk3,
  gtk4,
  xdg-utils,
  # The libraries Chromium loads, as nixpkgs' google-chrome lists them.
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  bzip2,
  cairo,
  coreutils,
  cups,
  curl,
  dbus,
  expat,
  flac,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  harfbuzz,
  icu,
  libcap,
  libdrm,
  liberation_ttf,
  libexif,
  libglvnd,
  libkrb5,
  libpng,
  libpulseaudio,
  libva,
  libx11,
  libxcb,
  libxcomposite,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxkbcommon,
  libxrandr,
  libxrender,
  libxscrnsaver,
  libxshmfence,
  libxtst,
  libgbm,
  nspr,
  nss,
  libopus,
  pango,
  pciutils,
  pipewire,
  snappy,
  speechd-minimal,
  systemdLibs,
  util-linux,
  vulkan-loader,
  wayland,
  wget,
}:

let
  # Version and hashes live in hashes.json so update.sh can rewrite them.
  sources = lib.importJSON ./hashes.json;
  inherit (sources) version hashes;
  inherit (stdenvNoCC.hostPlatform) system;
  hash = hashes.${system} or (throw "helium: unsupported system ${system}");

  meta = {
    description = "Helium web browser, Chromium-based and private by default (upstream's prebuilt release)";
    homepage = "https://helium.computer/";
    license = lib.licenses.gpl3Only;
    mainProgram = "helium";
    # macOS 13 or later.
    platforms = [
      "aarch64-darwin"
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };

  # Upstream's signed, notarized Helium.app for Apple Silicon; nothing is
  # compiled.
  darwin = stdenvNoCC.mkDerivation {
    pname = "helium";
    inherit version;

    src = fetchurl {
      url = "https://github.com/imputnet/helium-macos/releases/download/${version}/helium_${version}_arm64-macos.dmg";
      inherit hash;
    };

    nativeBuildInputs = [ undmg ];
    sourceRoot = ".";

    dontConfigure = true;
    dontBuild = true;
    # Stripping or patching would break the bundle's code signature.
    dontFixup = true;

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/Applications" "$out/bin"
      cp -R Helium.app "$out/Applications/"
      # Exec by full path so Helium finds its framework inside the bundle.
      cat > "$out/bin/helium" <<SH
      #!/bin/sh
      exec "$out/Applications/Helium.app/Contents/MacOS/Helium" "\$@"
      SH
      chmod +x "$out/bin/helium"
      runHook postInstall
    '';

    doInstallCheck = true;
    installCheckPhase = ''
      runHook preInstallCheck
      ${python3.interpreter} ${../../lib/check-app.py} "$out/Applications/Helium.app" "$version"
      runHook postInstallCheck
    '';

    meta = meta // {
      changelog = "https://github.com/imputnet/helium-macos/releases/tag/${version}";
    };
  };

  # Upstream's binary tarball, its ELF files pointed at the store's loader and
  # libraries, run through a wrapper in the way nixpkgs runs Google Chrome.
  opusWithCustomModes = libopus.override { withCustomModes = true; };
  deps = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    bzip2
    cairo
    coreutils
    cups
    curl
    dbus
    expat
    flac
    fontconfig
    freetype
    stdenv.cc.cc.lib
    gdk-pixbuf
    glib
    gtk3
    gtk4
    harfbuzz
    icu
    libcap
    libdrm
    liberation_ttf
    libexif
    libglvnd
    libkrb5
    libpng
    libpulseaudio
    libva
    libx11
    libxcb
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxkbcommon
    libxrandr
    libxrender
    libxscrnsaver
    libxshmfence
    libxtst
    libgbm
    nspr
    nss
    opusWithCustomModes
    pango
    pciutils
    pipewire
    snappy
    speechd-minimal
    systemdLibs
    util-linux
    vulkan-loader
    wayland
    wget
  ];

  linux = stdenvNoCC.mkDerivation {
    pname = "helium";
    inherit version;

    src = fetchurl {
      url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-${
        {
          x86_64-linux = "x86_64";
          aarch64-linux = "arm64";
        }
        .${system}
      }_linux.tar.xz";
      inherit hash;
    };

    nativeBuildInputs = [
      makeWrapper
      patchelf
    ];
    # For XDG_ICON_DIRS and GSETTINGS_SCHEMAS_PATH in the wrapper.
    buildInputs = [
      adwaita-icon-theme
      glib
      gtk3
      gtk4
      gsettings-desktop-schemas
    ];

    dontConfigure = true;
    dontBuild = true;
    # The binaries are patched by hand below; stripping them is not ours to do.
    dontStrip = true;

    installPhase = ''
      runHook preInstall

      dir=$out/libexec/helium
      mkdir -p $dir $out/bin
      cp -a . $dir
      # Upstream's own launcher: the wrapper below takes its place.
      rm $dir/helium-wrapper

      # nixpkgs' Vulkan loader, which finds the system's drivers, for the
      # bundled one.
      rm $dir/libvulkan.so.1
      ln -s ${lib.getLib vulkan-loader}/lib/libvulkan.so.1 $dir/libvulkan.so.1

      rpath="${lib.makeLibraryPath deps}:${lib.makeSearchPathOutput "lib" "lib64" deps}:$dir"
      for elf in $dir/{helium,chromedriver,helium_crashpad_handler}; do
        patchelf --set-interpreter "$(cat ${stdenv.cc}/nix-support/dynamic-linker)" --set-rpath "$rpath" $elf
      done

      makeWrapper $dir/helium $out/bin/helium \
        --prefix LD_LIBRARY_PATH : "$rpath" \
        --prefix PATH : ${lib.makeBinPath deps} \
        --suffix PATH : ${lib.makeBinPath [ xdg-utils ]} \
        --prefix XDG_DATA_DIRS : "$XDG_ICON_DIRS:$GSETTINGS_SCHEMAS_PATH:${addDriverRunpath.driverLink}/share" \
        --set CHROME_WRAPPER $out/bin/helium \
        --set CHROME_VERSION_EXTRA nix \
        --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"
      ln -s $dir/chromedriver $out/bin/helium-chromedriver

      install -Dm644 $dir/product_logo_256.png $out/share/icons/hicolor/256x256/apps/helium.png
      install -Dm644 $dir/helium.desktop $out/share/applications/helium.desktop
      substituteInPlace $out/share/applications/helium.desktop \
        --replace-quiet 'Exec=helium' "Exec=$out/bin/helium"

      runHook postInstall
    '';

    doInstallCheck = true;
    installCheckPhase = ''
      runHook preInstallCheck
      $out/bin/helium --version | grep -F "${version}"
      runHook postInstallCheck
    '';

    meta = meta // {
      changelog = "https://github.com/imputnet/helium-linux/releases/tag/${version}";
    };
  };
in
if stdenvNoCC.hostPlatform.isDarwin then darwin else linux
