{ stdenv, fetchFromGitHub }:
stdenv.mkDerivation rec {
  name = "fish-fzy";
  version = "master";

  src = fetchFromGitHub {
    owner = "gyakovlev";
    repo = name;
    rev = "1d5f9221b5a5a096e9282da1a3f1aac5bef01824";
    sha256 = "0xx1np6f975v6ird9znplsnj4n0dnfw4ykha2848a6mglh4w40dm";
  };

  installPhase = import ./installPhase.nix;

  meta = with stdenv.lib; {
    description = "Ef-fish-ient fish keybindings for fzy";
    homepage = https://github.com/gyakovlev/fzy;
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
