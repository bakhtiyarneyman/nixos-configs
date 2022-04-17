{ stdenv, lib, fetchFromGitHub }:
stdenv.mkDerivation rec {
  name = "z";
  version = "master";

  src = fetchFromGitHub {
    owner = "jethrokuan";
    repo = name;
    rev = "${version}";
    sha256 = "1kaa0k9d535jnvy8vnyxd869jgs0ky6yg55ac1mxcxm8n0rh2mgq";
  };

  installPhase = import ./installPhase.nix;

  meta = with lib; {
    description = "z tracks the directories you visit.";
    homepage = https://github.com/jethrokuan/z;
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
