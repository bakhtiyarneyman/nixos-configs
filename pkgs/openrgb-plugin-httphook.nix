{
  lib,
  stdenv,
  fetchFromGitLab,
  libsForQt5,
  openrgb,
  glib,
  hidapi,
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

    substituteInPlace OpenRGBHttpHookPlugin.pro \
      --replace-fail "OpenRGB/dependencies/json" "OpenRGB/dependencies/json \\
    OpenRGB/dependencies/json/nlohmann \\
    OpenRGB/SPDAccessor \\
    ${lib.getDev hidapi}/include/hidapi"

    substituteInPlace OpenRGBHttpHookPlugin.h \
      --replace-fail "Load(bool dark_theme, ResourceManager* resource_manager_ptr)" "Load(ResourceManagerInterface* resource_manager_ptr)" \
      --replace-fail "static ResourceManager* RMPointer" "static ResourceManagerInterface* RMPointer"

    substituteInPlace OpenRGBHttpHookPlugin.cpp \
      --replace-fail "ResourceManager* OpenRGBHttpHookPlugin::RMPointer = nullptr" "ResourceManagerInterface* OpenRGBHttpHookPlugin::RMPointer = nullptr" \
      --replace-fail "void OpenRGBHttpHookPlugin::Load(bool dark_theme, ResourceManager* resource_manager_ptr)" "void OpenRGBHttpHookPlugin::Load(ResourceManagerInterface* resource_manager_ptr)" \
      --replace-fail "    DarkTheme                = dark_theme;" ""

    substituteInPlace HttpHook.cpp \
      --replace-fail '#include "HookActions.h"' '#include "HookActions.h"
#include "ProfileManager.h"
#include "RGBController.h"'

    substituteInPlace EditHookAction.cpp \
      --replace-fail '#include "OpenRGBHttpHookPlugin.h"' '#include "OpenRGBHttpHookPlugin.h"
#include "ProfileManager.h"'
  '';

  nativeBuildInputs = with libsForQt5; [
    qmake
    pkg-config
    wrapQtAppsHook
  ];

  buildInputs = with libsForQt5; [
    qtbase
    glib
    hidapi
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
