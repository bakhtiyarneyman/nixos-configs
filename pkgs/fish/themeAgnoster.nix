{ stdenv, fetchFromGitHub }:
stdenv.mkDerivation rec {
  name = "theme-agnoster";
  version = "master";

  src = fetchFromGitHub {
    owner = "oh-my-fish";
    repo = name;
    rev = "${version}";
    sha256 = "1qc6srdg8ar9k7p97yg2q0naqdd260wxkljf0r91gh2hidw583xa";
  };

  installPhase = ./installPhase.sh;

  meta = with stdenv.lib; {
    description = "A fish theme";
    homepage = https://github.com/oh-my-fish/theme-agnoster;
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
