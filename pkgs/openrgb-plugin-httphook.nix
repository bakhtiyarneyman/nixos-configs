{
  lib,
  stdenv,
  fetchFromGitLab,
  libsForQt5,
  openrgb,
  glib,
  openal,
  pkg-config,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "openrgb-plugin-httphook";
  version = "0.9";

  src = fetchFromGitLab {
    owner = "OpenRGBDevelopers";
    repo = "OpenRGBHttpHookPlugin";
    rev = "release_${finalAttrs.version}";
    hash = "sha256-UoSQ+g93OUcve1azY7yOGuMix9olNpij85SQHBbFZns=";
    fetchSubmodules = true;
  };

  postPatch = ''
    # Use the source of openrgb from nixpkgs instead of the submodule
    rm -r OpenRGB
    ln -s ${openrgb.src} OpenRGB
  '';

  nativeBuildInputs = with libsForQt5; [
    qmake
    pkg-config
    wrapQtAppsHook
  ];

  buildInputs = with libsForQt5; [
    qtbase
    glib
    openal
  ];

  installPhase = ''
    mkdir -p $out/lib
    # There will be many symlinks to the same file, but we need to copy just one, otherwise OpenRGB will recognize them as independent plugins.
    cp -v libOpenRGBHttpHookPlugin.so $out/lib/
  '';

  meta = with lib; {
    homepage = "https://gitlab.com/OpenRGBDevelopers/OpenRGBHttpHookPlugin";
    description = "Effects plugin for OpenRGB";
    license = licenses.gpl2Plus;
    maintainers = with maintainers; [fgaz];
    platforms = platforms.linux;
  };
})
