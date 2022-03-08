{ stdenv, lib, fetchFromGitHub }:
stdenv.mkDerivation rec {
  name = "adwaita-one-dark";

  src = fetchFromGitHub {
    owner = "lonr";
    repo = name;
    rev = "2fd61fdace4a37b3d8c37239cb80ec972dcb03a8";
    sha256 = "13jxlp8wilig66w54p0yir1q4q9xdis8i20djai8zvgqsbaqc6rs";
  };

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/themes
    cp --recursive Adwaita-One-Dark $out/share/themes
    patch $out/share/themes/Adwaita-One-Dark/gtk-3.0/gtk-dark.css ${./adwaita-one-dark.patch}

    runHook postInstall
  '';

  meta = with lib; {
    description = "Adwaita (the default theme of GNOME) with the One Dark color scheme";
    homepage = https://github.com/lonr/adwaita-one-dark;
    license = licenses.gpl3Only;
    platforms = platforms.all;
  };
}
