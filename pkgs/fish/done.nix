{ stdenv, fetchFromGitHub }:
stdenv.mkDerivation rec {
  name = "done";
  version = "1.8.1";

  src = fetchFromGitHub {
    owner = "franciscolourenco";
    repo = name;
    rev = "${version}";
    sha256 = "0as2hk9zjl3yiz956xdhz6n8aq4drr7s592681cdb7sa1gv2p69y";
  };

  installPhase = import ./installPhase.nix;

  meta = with stdenv.lib; {
    description = "A fish-shell package to automatically receive notifications when long processes finish.";
    homepage = https://github.com/franciscolourenco/done;
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
