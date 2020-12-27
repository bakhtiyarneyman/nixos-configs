{ stdenv, fetchFromGitHub }:
stdenv.mkDerivation rec {
  name = "humantime.fish";
  version = "main";

  src = fetchFromGitHub {
    owner = "jorgebucaran";
    repo = name;
    rev = "${version}";
    sha256 = "0avlk8hryd9h0cj1a97dcbh38031qf2005bf2f6hi8kmqmxw1apl";
  };

  installPhase = import ./installPhase.nix;

  meta = with stdenv.lib; {
    description = "A fish shell package to make a time interval human readable.";
    homepage = https://github.com/jorgebucaran/humantime.fish;
    license = licenses.unlicense;
    platforms = platforms.linux;
  };
}
