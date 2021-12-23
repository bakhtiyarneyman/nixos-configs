{ stdenv, lib, fetchFromGitHub }:
stdenv.mkDerivation rec {
  name = "done";
  version = "1.16.5";

  src = fetchFromGitHub {
    owner = "franciscolourenco";
    repo = name;
    rev = "${version}";
    sha256 = "1m11nsdmd82x0l3i8zqw8z3ba77nxanrycv93z25rmghw1wjyk0k";
  };

  installPhase = import ./installPhase.nix;

  meta = with lib; {
    description = "A fish-shell package to automatically receive notifications when long processes finish.";
    homepage = https://github.com/franciscolourenco/done;
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
