# Builds a website as a desktop app with Pake (Tauri + the system WebView).
# Used by pkgs/webapp-*/package.nix through `callPackage`.
#
# Pake's CLI (`pake <url> ...`) needs the network at build time, so this skips
# it: it takes Pake's release source, makes the same edits the CLI would make to
# src-tauri/pake.json and the tauri*.conf.json files, then runs `cargo tauri
# build`.
{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  cargo-tauri,
  jq,
  pkg-config,
  wrapGAppsHook3,
  glib-networking,
  libayatana-appindicator,
  openssl,
  webkitgtk_4_1,
}:
{
  # Package name; also the program in bin/ and the Linux icon name, so two
  # webapps don't collide in one profile.
  pname,
  # The webapp's hashes.json: Pake's release `version`, its source `hash`, and
  # `cargoHash` for the vendored crates. Written by lib/pake-webapp-update.sh.
  sources,
  # App name shown in the menu bar, dock and launcher.
  productName,
  identifier,
  # Square PNG; `cargo tauri icon` makes the platform icons from it.
  icon,
  # Merged into the first window of Pake's src-tauri/pake.json, so it takes
  # that file's field names: url, width, height, hide_title_bar, enable_find, ...
  window,
  description,
  homepage,
}:
rustPlatform.buildRustPackage {
  inherit pname;
  inherit (sources) version;

  src = fetchFromGitHub {
    owner = "tw93";
    repo = "Pake";
    tag = "V${sources.version}";
    hash = sources.hash;
  };

  inherit (sources) cargoHash;
  cargoRoot = "src-tauri";
  buildAndTestSubdir = "src-tauri";

  postPatch = ''
    cd src-tauri

    cargo tauri icon ${icon} --output icons-webapp
    icons='["icons-webapp/32x32.png","icons-webapp/128x128.png","icons-webapp/128x128@2x.png","icons-webapp/icon.icns","icons-webapp/icon.ico"]'

    # The tray falls back to the window icon when system_tray_path is empty.
    jq --argjson w ${lib.escapeShellArg (builtins.toJSON window)} '
      .windows[0] += $w
      | .system_tray_path = ""
    ' pake.json > pake.json.new
    mv pake.json.new pake.json

    jq --arg name ${lib.escapeShellArg productName} \
      --arg id ${lib.escapeShellArg identifier} \
      --arg bin ${lib.escapeShellArg pname} \
      --arg desc ${lib.escapeShellArg description} '
      .productName = $name
      | .identifier = $id
      | .mainBinaryName = $bin
      | .app.trayIcon.iconPath = "icons-webapp/128x128.png"
      | .bundle.shortDescription = $desc
      | .bundle.category = "Network"
    ' tauri.conf.json > tauri.conf.json.new
    mv tauri.conf.json.new tauri.conf.json

    # Platform files point at the template's Weekly icons, and macOS's at an
    # ad-hoc codesign the build sandbox can't run; the linker signs the binary.
    for f in tauri.linux.conf.json tauri.macos.conf.json; do
      jq --argjson icons "$icons" '
        .bundle.icon = $icons
        | del(.bundle.macOS.signingIdentity, .bundle.macOS.hardenedRuntime)
      ' "$f" > "$f.new"
      mv "$f.new" "$f"
    done

    cd ..
  ''
  # The tray loads libayatana-appindicator with dlopen.
  + lib.optionalString stdenv.hostPlatform.isLinux ''
    substituteInPlace $cargoDepsCopy/*/libappindicator-sys-*/src/lib.rs \
      --replace-fail "libayatana-appindicator3.so.1" "${libayatana-appindicator}/lib/libayatana-appindicator3.so.1"
  '';

  nativeBuildInputs = [
    cargo-tauri.hook
    jq
    pkg-config
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ wrapGAppsHook3 ];

  buildInputs = [
    openssl
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    glib-networking
    libayatana-appindicator
    webkitgtk_4_1
  ];

  # Pake's unit tests cover the template, not this configuration.
  doCheck = false;

  meta = {
    inherit description homepage;
    changelog = "https://github.com/tw93/Pake/releases/tag/V${sources.version}";
    # Pake's license; the website itself is its owner's service.
    license = lib.licenses.gpl3Plus;
    mainProgram = pname;
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
}
