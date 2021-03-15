{ stdenv, fetchFromGitHub }:
stdenv.mkDerivation rec {
  name = "z";
  version = "master";

  src = fetchFromGitHub {
    owner = "jethrokuan";
    repo = name;
    rev = "${version}";
    sha256 = "1797n91ka5smj1h2qq7kdhs22qjyrpd0gk18lhk0s3izl36r31sl";
  };

  installPhase = import ./installPhase.nix;

  meta = with stdenv.lib; {
    description = "z tracks the directories you visit.";
    homepage = https://github.com/jethrokuan/z;
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
