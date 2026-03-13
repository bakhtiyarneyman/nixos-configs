{
  lib,
  stdenv,
  fetchFromGitHub,
  testers,
  wrapGAppsHook3,
  bash-completion,
  blueprint-compiler,
  dbus,
  dbus-glib,
  fish,
  gdk-pixbuf,
  glib,
  gobject-introspection,
  gtk4-layer-shell,
  gtk4,
  gvfs,
  json-glib,
  libadwaita,
  libgee,
  libnotify,
  libpulseaudio,
  librsvg,
  meson,
  ninja,
  pkg-config,
  python3,
  scdoc,
  vala,
  wayland-scanner,
  xvfb-run,
  sassc,
  pantheon,
  nix-update-script,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "SwayNotificationCenter";
  version = "0-unstable-2025-06-28";

  src = fetchFromGitHub {
    owner = "bakhtiyarneyman";
    repo = "SwayNotificationCenter";
    rev = "3dbb70c4b4a267ec48ed76dba4735f64f92b81cf";
    hash = "sha256-DtzlqOxF3VSFNzQmZX+Rfr5YH9oi9UJRyIs2PEGSZKc=";
  };

  # build pkg-config is required to locate the native `scdoc` input
  depsBuildBuild = [pkg-config];

  nativeBuildInputs = [
    bash-completion
    blueprint-compiler
    # cmake # currently conflicts with meson
    fish
    glib
    gobject-introspection
    meson
    ninja
    pkg-config
    python3
    sassc
    scdoc
    vala
    wayland-scanner
    wrapGAppsHook3
  ];

  buildInputs = [
    dbus
    dbus-glib
    gdk-pixbuf
    glib
    gtk4-layer-shell
    gtk4
    gvfs
    json-glib
    libadwaita
    libgee
    libnotify
    libpulseaudio
    librsvg
    pantheon.granite7
    # systemd # ends with broken permission
  ];

  postPatch = ''
    chmod +x build-aux/meson/postinstall.py
    patchShebangs build-aux/meson/postinstall.py
    substituteInPlace src/functions.vala --replace "/usr/local/etc/xdg/swaync" "$out/etc/xdg/swaync"
  '';

  strictDeps = true;

  passthru.tests.version = testers.testVersion {
    package = finalAttrs.finalPackage;
    command = "${xvfb-run}/bin/xvfb-run swaync --version";
  };
  passthru.updateScript = nix-update-script {};

  meta = {
    description = "Simple notification daemon with a GUI built for Sway";
    homepage = "https://github.com/ErikReider/SwayNotificationCenter";
    changelog = "https://github.com/ErikReider/SwayNotificationCenter/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.gpl3;
    platforms = lib.platforms.linux;
    mainProgram = "swaync";
    maintainers = with lib.maintainers; [
      berbiche
      pedrohlc
    ];
  };
})
