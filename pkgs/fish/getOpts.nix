{ stdenv, lib, fetchFromGitHub }:
stdenv.mkDerivation rec {
  name = "fish-getopts";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "jorgebucaran";
    repo = name;
    rev = "${version}";
    sha256 = "0h5r8as4s5pn608f22r2az6slnplkgyb24b6n8pn7hahv4a7jpak";
  };

  installPhase = import ./installPhase.nix;

  meta = with lib; {
    description = "Parse CLI options in fish";
    homepage = https://github.com/jorgebucaran/fish-getopts;
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
