{
  lib,
  stdenv,
  fetchFromGitHub,
  autoconf,
  automake,
  libtool,
  pkg-config,
  libpcap,
  which,
}:
stdenv.mkDerivation rec {
  pname = "ndpi";
  version = "5.1.0-unstable";

  src = fetchFromGitHub {
    owner = "ntop";
    repo = "nDPI";
    rev = "9eb914d587336d16116f4149965701f3cfbb74fe";
    hash = "sha256-YZJIX4kQNuQ1PkFlX49wk3R1hkm2N19KA/Sapih6VyE=";
  };

  nativeBuildInputs = [
    autoconf
    automake
    libtool
    pkg-config
    which
  ];
  buildInputs = [libpcap];

  preConfigure = ''
    patchShebangs autogen.sh
    ./autogen.sh
  '';

  configureFlags = ["--enable-static"];

  enableParallelBuilding = true;
}
