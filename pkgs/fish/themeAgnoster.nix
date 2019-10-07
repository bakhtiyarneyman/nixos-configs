{ stdenv, fetchFromGitHub }:
stdenv.mkDerivation rec {
  name = "theme-agnoster";
  version = "nix-shell";

  src = fetchFromGitHub {
    owner = "niobium0";
    repo = name;
    rev = "${version}";
    sha256 = "1r30byr8k39v6afxwq0vkagl93f9psidchpdn4yi4cpb9k6ca6cp";
  };

  installPhase = import ./installPhase.nix;

  meta = with stdenv.lib; {
    description = "A fish theme";
    homepage = https://github.com/oh-my-fish/theme-agnoster;
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
