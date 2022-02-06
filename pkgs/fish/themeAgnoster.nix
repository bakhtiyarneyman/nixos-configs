{ stdenv, lib, fetchFromGitHub }:
stdenv.mkDerivation rec {
  name = "theme-agnoster";

  src = fetchFromGitHub {
    owner = "bakhtiyarneyman";
    repo = name;
    rev = "5fa01f12329cc45a15364af33a7f11ac0aab843a";
    sha256 = "1n282fahrixaz2zl7nvv9ag41asm8gldnzxhg0pbx2lf9a2grqn5";
  };

  installPhase = import ./installPhase.nix;

  meta = with lib; {
    description = "A fish theme";
    homepage = https://github.com/oh-my-fish/theme-agnoster;
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
