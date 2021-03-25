{ stdenv, fetchFromGitHub }:
stdenv.mkDerivation rec {
  name = "z";
  version = "master";

  src = fetchFromGitHub {
    owner = "jethrokuan";
    repo = name;
    rev = "${version}";
    sha256 = "12ksq3f32h7ng4l6zv4ykj9yhhhvxpkyd1nnir3ab8kyp9hdwrr3";
  };

  installPhase = import ./installPhase.nix;

  meta = with stdenv.lib; {
    description = "z tracks the directories you visit.";
    homepage = https://github.com/jethrokuan/z;
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
