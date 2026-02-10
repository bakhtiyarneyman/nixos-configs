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
  version = "5.0";

  src = fetchFromGitHub {
    owner = "ntop";
    repo = "nDPI";
    rev = version;
    hash = "sha256-Elnj6qDuT8UWDxmasiHOt5DxC7GcH5zgrp3J3LYcl0c=";
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

  enableParallelBuilding = true;
}
