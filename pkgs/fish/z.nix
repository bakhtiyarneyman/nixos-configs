{ stdenv, fetchFromGitHub }:
stdenv.mkDerivation rec {
  name = "z";
  version = "master";

  src = fetchFromGitHub {
    owner = "jethrokuan";
    repo = name;
    rev = "${version}";
    sha256 = "0z7l7fgd9khcq1fi9ymjjrxj58pw5xdzg8k6mxqmqw1345hkpr4f";
  };

  installPhase = import ./installPhase.nix;

  meta = with stdenv.lib; {
    description = "z tracks the directories you visit.";
    homepage = https://github.com/jethrokuan/z;
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
