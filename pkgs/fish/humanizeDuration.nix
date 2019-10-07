{ stdenv, fetchFromGitHub }:
stdenv.mkDerivation rec {
  name = "fish-humanize-duration";
  version = "master";

  src = fetchFromGitHub {
    owner = "fishpkg";
    repo = name;
    rev = "${version}";
    sha256 = "078wzrppw62dz297860n2qdljnnpmhpaj60gw5cl4dbfcij24335";
  };

  installPhase = import ./installPhase.nix;

  meta = with stdenv.lib; {
    description = "A fish shell package to make a time interval human readable.";
    homepage = https://github.com/fishpkg/fish-humanize-duration;
    license = licenses.unlicense;
    platforms = platforms.linux;
  };
}
