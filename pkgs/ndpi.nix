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
  version = "5.0-dev";

  src = fetchFromGitHub {
    owner = "ntop";
    repo = "nDPI";
    rev = "411b3ad202b15e6780a11d18c44cc3008104ad6f";
    hash = "sha256-mAXAO+Yg69yXdoJ/NuwVlIZbFG5zaj2GdOuQ6LyyWII=";
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
