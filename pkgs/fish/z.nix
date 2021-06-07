{ stdenv, lib, fetchFromGitHub }:
stdenv.mkDerivation rec {
  name = "z";
  version = "master";

  src = fetchFromGitHub {
    owner = "jethrokuan";
    repo = name;
    rev = "${version}";
    sha256 = "05z6lnkmzbl212cbfp291p63qfzzqp73nkfizsgbmm0fbiqbi74p";
  };

  installPhase = import ./installPhase.nix;

  meta = with lib; {
    description = "z tracks the directories you visit.";
    homepage = https://github.com/jethrokuan/z;
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
