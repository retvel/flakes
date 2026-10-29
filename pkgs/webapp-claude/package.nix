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
let
  # Pake's release tag, source hash and the hash of its vendored crates live in
  # hashes.json so update.sh can rewrite them.
  sources = lib.importJSON ./hashes.json;

  # What `pake https://claude.ai --name Claude --identifier com.pake.claude
  # --width 1280 --height 860 --hide-title-bar --enable-find --new-window`
  # writes into src-tauri/pake.json; see Pake's docs/cli-usage.md.
  window = {
    url = "https://claude.ai";
    width = 1280;
    height = 860;
    hide_title_bar = true;
    enable_find = true;
    new_window = true;
  };
in
rustPlatform.buildRustPackage {
  pname = "webapp-claude";
  inherit (sources) version;

  src = fetchFromGitHub {
    owner = "tw93";
    repo = "Pake";
    tag = "V${sources.version}";
    hash = sources.hash;
  };

  cargoHash = sources.cargoHash;
  cargoRoot = "src-tauri";
  buildAndTestSubdir = "src-tauri";

  # Pake's CLI only rewrites these files before `tauri build`; build the same
  # app shell directly instead of running the Node CLI, which needs the network.
  postPatch = ''
    cd src-tauri

    cargo tauri icon ${./icon.png} --output icons-claude
    icons='["icons-claude/32x32.png","icons-claude/128x128.png","icons-claude/128x128@2x.png","icons-claude/icon.icns","icons-claude/icon.ico"]'

    jq --argjson w '${builtins.toJSON window}' '
      .windows[0] += $w
      | .system_tray_path = ""
    ' pake.json > pake.json.new
    mv pake.json.new pake.json

    jq '
      .productName = "Claude"
      | .identifier = "com.pake.claude"
      | .app.trayIcon.iconPath = "icons-claude/128x128.png"
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
    description = "Claude (claude.ai) as a desktop app, wrapped with Pake";
    homepage = "https://github.com/tw93/Pake";
    changelog = "https://github.com/tw93/Pake/releases/tag/V${sources.version}";
    # Pake's license; claude.ai itself is Anthropic's service.
    license = lib.licenses.gpl3Plus;
    mainProgram = "pake";
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
}
