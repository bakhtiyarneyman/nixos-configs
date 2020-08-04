{ stdenv, fetchFromGitHub }:
stdenv.mkDerivation rec {
  name = "z";
  version = "master";

  src = fetchFromGitHub {
    owner = "jethrokuan";
    repo = name;
    rev = "${version}";
    sha256 = "0kykhan9rdzy8anif5jp1iv3djrakhwk2arll3k93vaxm3np0gfm";
  };

  installPhase = import ./installPhase.nix;

  meta = with stdenv.lib; {
    description = "z tracks the directories you visit.";
    homepage = https://github.com/jethrokuan/z;
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
