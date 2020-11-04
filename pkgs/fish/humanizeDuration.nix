{ stdenv, fetchFromGitHub }:
stdenv.mkDerivation rec {
  name = "fish-humanize-duration";
  version = "master";

  src = fetchFromGitHub {
    owner = "fishpkg";
    repo = name;
    rev = "${version}";
    sha256 = "09sbhawnidwq389nbpn1kjsxkgq19grab56r9vjx6cxwvsng7rqw";
  };

  installPhase = import ./installPhase.nix;

  meta = with stdenv.lib; {
    description = "A fish shell package to make a time interval human readable.";
    homepage = https://github.com/fishpkg/fish-humanize-duration;
    license = licenses.unlicense;
    platforms = platforms.linux;
  };
}
