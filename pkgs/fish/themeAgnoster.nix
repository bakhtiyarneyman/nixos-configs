{
  stdenv,
  lib,
  fetchFromGitHub,
}:
stdenv.mkDerivation rec {
  name = "theme-agnoster";

  src = fetchFromGitHub {
    owner = "oh-my-fish";
    repo = name;
    rev = "4c5518c89ebcef393ef154c9f576a52651400d27";
    sha256 = "1i8l44277sq4cfyds2k0ijkn7p4izpp8z8j66dbshzi7xfwi4l9q";
  };

  installPhase = import ./installPhase.nix;

  meta = with lib; {
    description = "A fish theme";
    homepage = "https://github.com/oh-my-fish/theme-agnoster";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
