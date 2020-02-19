{ stdenv, fetchFromGitHub }:
stdenv.mkDerivation rec {
  name = "plugin-peco";
  version = "master";

  src = fetchFromGitHub {
    owner = "oh-my-fish";
    repo = name;
    rev = "0a3282c9522c4e0102aaaa36f89645d17db78657";
    sha256 = "005r6yar254hkx6cpd2g590na812mq9z9a17ghjl6sbyyxq24jhi";
  };

  installPhase = import ./installPhase.nix;

  meta = with stdenv.lib; {
    description = "Browse your fish history with peco";
    homepage = https://github.com/oh-my-fish/plugin-peco;
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
