{
  stdenvNoCC,
  lib,
  fetchurl,
  adw-gtk3,
}:
stdenvNoCC.mkDerivation {
  pname = "adwaita-one-dark";
  version = "0.48.0";

  src = fetchurl {
    url = "https://github.com/lonr/adwaita-one-dark/releases/download/v0.48.0/For-GNOME48.tar.xz";
    hash = "sha256-Mudb5G/aA0zeFcaNZ0HD0ijBXKuiIl+BOixoKFpQBco=";
  };

  sourceRoot = "Adwaita-One-Dark";
  patches = [./adwaita-one-dark.patch];
  propagatedUserEnvPkgs = [adw-gtk3];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/themes/Adwaita-One-Dark
    cp --recursive . $out/share/themes/Adwaita-One-Dark

    runHook postInstall
  '';

  meta = with lib; {
    description = "Adwaita (the default theme of GNOME) with the One Dark color scheme";
    homepage = "https://github.com/lonr/adwaita-one-dark";
    license = [licenses.agpl3Plus licenses.lgpl21Only];
    platforms = platforms.all;
  };
}
