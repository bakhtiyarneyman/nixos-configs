{
  stdenv,
  lib,
  fetchFromGitHub,
}:
stdenv.mkDerivation rec {
  name = "fzf";
  version = "0.16.6";

  src = fetchFromGitHub {
    owner = "jethrokuan";
    repo = name;
    rev = "${version}";
    sha256 = "1zfn4ii6vq444h5rghsd7biip1x3zkh9nyvzd1l8ma8ja9y6q77x";
  };

  installPhase = import ./installPhase.nix;

  meta = with lib; {
    description = "Ef-fish-ient fish keybindings for fzf";
    homepage = "https://github.com/jethrokuan/fzf";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
