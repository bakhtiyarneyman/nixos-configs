{ stdenv, fetchFromGitHub }:
stdenv.mkDerivation rec {
  name = "done";
  version = "1.14.10";

  src = fetchFromGitHub {
    owner = "franciscolourenco";
    repo = name;
    rev = "${version}";
    sha256 = "1fn4q2clm0n9agb9f2vx1zj3g785kfjyyfdr2w3zzmsjaa8kcxqr";
  };

  installPhase = import ./installPhase.nix;

  meta = with stdenv.lib; {
    description = "A fish-shell package to automatically receive notifications when long processes finish.";
    homepage = https://github.com/franciscolourenco/done;
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
