{
  lib,
  stdenv,
  fetchFromGitLab,
  qt6Packages,
  openrgb,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "openrgb-plugin-httphook";
  version = "1.0";

  src = fetchFromGitLab {
    owner = "OpenRGBDevelopers";
    repo = "OpenRGBHttpHookPlugin";
    rev = "release_${finalAttrs.version}";
    hash = "sha256-izjQdZr1nXMAJV8EdcO0OT23OeujItfF1PJ9LelBXkw=";
    fetchSubmodules = true;
  };

  postPatch = ''
    # Compile against the same plugin API as the host application.
    rm -r OpenRGB
    ln -s ${openrgb.src} OpenRGB
  '';

  nativeBuildInputs = with qt6Packages; [
    qmake
    wrapQtAppsHook
  ];

  buildInputs = [qt6Packages.qtbase];

  meta = with lib; {
    homepage = "https://gitlab.com/OpenRGBDevelopers/OpenRGBHttpHookPlugin";
    description = "HTTP hooks for controlling OpenRGB lighting";
    license = licenses.gpl2Plus;
    maintainers = with maintainers; [fgaz];
    platforms = platforms.linux;
  };
})
