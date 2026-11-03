{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  asar,
  wrapGAppsHook3,
  makeWrapper,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  gdk-pixbuf,
  glib,
  gtk3,
  libgbm,
  libGL,
  libnotify,
  libpulseaudio,
  libsecret,
  libusb1,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  nspr,
  nss,
  openssl,
  pango,
  pipewire,
  systemd,
  tpm2-tss,
  xdg-utils,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "chatgpt-desktop";
  version = "26.1027.51404";

  src = fetchurl {
    url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_${finalAttrs.version}_amd64.deb";
    hash = "sha256-RvHiLQKGmP6e2u/VhHrs4HxFCaMNNwnhBCIHGdjBKCI=";
  };

  nativeBuildInputs = [dpkg autoPatchelfHook asar wrapGAppsHook3 makeWrapper];
  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    gdk-pixbuf
    glib
    gtk3
    libgbm
    libusb1
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    nspr
    nss
    openssl
    pango
    stdenv.cc.cc.lib
    systemd
    tpm2-tss
  ];

  # Chromium and native modules load these libraries with dlopen.
  runtimeDependencies = map lib.getLib [libGL libnotify libpulseaudio libsecret pipewire];

  dontBuild = true;
  dontStrip = true;
  dontWrapGApps = true;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" .
    runHook postUnpack
  '';

  postPatch = ''
    # patchelf relocates PT_INTERP beyond detect-libc's 2048-byte read, and
    # NixOS has no /usr/bin/ldd. Its process.report fallback crashes this
    # Electron utility process (SIGILL), restarting the Git worker forever.
    # This package is glibc-only, so select its bundled watcher explicitly.
    asar extract usr/lib/chatgpt/resources/app.asar app
    substituteInPlace app/node_modules/@parcel/watcher/index.js \
      --replace-fail "const { MUSL, familySync } = require('detect-libc');" "const MUSL = 'musl';" \
      --replace-fail 'const family = familySync();' "const family = 'glibc';"
    asar pack app usr/lib/chatgpt/resources/app.asar --unpack '*.node'
    rm -r app
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -a usr/lib usr/share "$out/"
    rm -r "$out/share/lintian"
    # Use Chromium's GTK integration; these optional shims require incompatible
    # Qt major versions in the same build environment.
    rm "$out/lib/chatgpt/libqt5_shim.so" "$out/lib/chatgpt/libqt6_shim.so"

    # These optional prebuilds target Android, ARM or musl, not this glibc host.
    # Keep dependency checking strict for every native module that can be loaded.
    find "$out/lib/chatgpt/resources/app.asar.unpacked" -type f \
      \( -path '*/prebuilds/*android*/*' -o -path '*/prebuilds/*linux-arm*/*' \
         -o -path '*/prebuilds/*musl*/*' -o -name '*musl.node' \) -delete

    mkdir -p "$out/bin" "$out/share/icons/hicolor/512x512/apps"
    cp "$out/share/pixmaps/chatgpt.png" "$out/share/icons/hicolor/512x512/apps/chatgpt.png"
    substituteInPlace "$out/share/applications/chatgpt.desktop" \
      --replace-fail 'Exec=chatgpt %U' "Exec=$out/bin/chatgpt %U"
    runHook postInstall
  '';

  preFixup = ''
    addAutoPatchelfSearchPath "$out/lib/chatgpt"
    makeWrapper "$out/lib/chatgpt/ChatGPT" "$out/bin/chatgpt" \
      "''${gappsWrapperArgs[@]}" \
      --suffix PATH : ${lib.makeBinPath [xdg-utils]} \
      --add-flags "\''${WAYLAND_DISPLAY:+--ozone-platform=wayland}"
  '';

  meta = {
    description = "Official ChatGPT desktop app with Codex";
    homepage = "https://learn.chatgpt.com/docs/linux/linux-app";
    license = lib.licenses.unfree;
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    platforms = ["x86_64-linux"];
    mainProgram = "chatgpt";
  };
})
