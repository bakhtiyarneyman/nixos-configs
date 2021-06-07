{ stdenv, lib, fetchFromGitHub }:
stdenv.mkDerivation rec {
  name = "theme-agnoster";
  version = "master";

  src = fetchFromGitHub {
    owner = "niobium0";
    repo = name;
    rev = "${version}";
    sha256 = "1i0zmq9j8fhl16w90r0lwrzf6k441xpkdyg7cwygh7vavm2wndzs";
  };

  installPhase = import ./installPhase.nix;

  meta = with lib; {
    description = "A fish theme";
    homepage = https://github.com/oh-my-fish/theme-agnoster;
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
