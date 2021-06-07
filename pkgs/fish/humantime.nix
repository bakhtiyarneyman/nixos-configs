{ stdenv, lib, fetchFromGitHub }:
stdenv.mkDerivation rec {
  name = "humantime.fish";
  version = "main";

  src = fetchFromGitHub {
    owner = "jorgebucaran";
    repo = name;
    rev = "${version}";
    sha256 = "079fb8lsd7w2zq5y0z14zdk527qyvfj9y87zf0c34n7nqwzappgg";
  };

  installPhase = import ./installPhase.nix;

  meta = with lib; {
    description = "A fish shell package to make a time interval human readable.";
    homepage = https://github.com/jorgebucaran/humantime.fish;
    license = licenses.unlicense;
    platforms = platforms.linux;
  };
}
