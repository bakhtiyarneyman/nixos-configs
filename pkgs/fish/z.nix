{ stdenv, fetchFromGitHub }:
stdenv.mkDerivation rec {
  name = "z";
  version = "master";

  src = fetchFromGitHub {
    owner = "jethrokuan";
    repo = name;
    rev = "${version}";
    sha256 = "0c5i7sdrsp0q3vbziqzdyqn4fmp235ax4mn4zslrswvn8g3fvdyh";
  };

  installPhase = import ./installPhase.nix;

  meta = with stdenv.lib; {
    description = "z tracks the directories you visit.";
    homepage = https://github.com/jethrokuan/fzf;
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
