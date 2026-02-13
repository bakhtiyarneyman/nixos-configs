{
  lib,
  stdenv,
  autoreconfHook,
  curl,
  expat,
  fetchFromGitHub,
  git,
  json_c,
  libcap,
  libmaxminddb,
  libmysqlclient,
  libpcap,
  libsodium,
  ndpi,
  net-snmp,
  openssl,
  pkg-config,
  rdkafka,
  gtest,
  rrdtool,
  hiredis,
  sqlite,
  which,
  zeromq,
  cmake,
  pkgs,
}: let
  ndpi = pkgs.callPackage ./ndpi.nix {};
in
stdenv.mkDerivation (finalAttrs: {
  pname = "ntopng";
  version = "6.6-top_application_influx_fix";

  src = fetchFromGitHub {
    owner = "bakhtiyarneyman";
    repo = "ntopng";
    rev = "1d0e44d37de691a348f6179ee6bf2a642bfeb577";
    hash = "sha256-sRgo6nWGTDR4JbIUVruDJWfhEB19HBRoeZsUUhhdzK0=";
    fetchSubmodules = true;
  };

  preConfigure = ''
    substituteInPlace Makefile.in \
      --replace "/bin/rm" "rm"
  '';

  nativeBuildInputs = [
    autoreconfHook
    git
    pkg-config
    which
    cmake
  ];

  buildInputs = [
    curl
    expat
    json_c
    libcap
    libmaxminddb
    libmysqlclient
    libpcap
    gtest
    hiredis
    libsodium
    net-snmp
    openssl
    rdkafka
    rrdtool
    sqlite
    zeromq
  ];

  autoreconfPhase = "bash autogen.sh";

  configureFlags = [
    "--with-ndpi-includes=${ndpi}/include/ndpi"
    "--with-ndpi-static-lib=${ndpi}/lib/"
  ];

  preBuild = ''
    sed -e "s|\(#define CONST_BIN_DIR \).*|\1\"$out/bin\"|g" \
        -e "s|\(#define CONST_SHARE_DIR \).*|\1\"$out/share\"|g" \
        -i include/ntop_defines.h
  '';

  # Upstream build system makes
  # $out/share/ntopng/httpdocs/geoip/README.geolocation.md a dangling symlink
  # to ../../doc/README.geolocation.md. Copying the whole doc/ tree adds over
  # 70 MiB to the output size, so only copy the files we need for now.
  # (Ref. noBrokenSymlinks.)
  postInstall = ''
    mkdir -p "$out/share/ntopng/doc"
    cp -r doc/README.geolocation.md "$out/share/ntopng/doc/"
  '';

  enableParallelBuilding = true;
  dontUseCmakeConfigure = true;

  meta = {
    description = "High-speed web-based traffic analysis and flow collection tool";
    homepage = "https://www.ntop.org/products/traffic-analysis/ntop/";
    changelog = "https://github.com/ntop/ntopng/blob/${finalAttrs.version}/CHANGELOG.md";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    maintainers = with lib.maintainers; [bjornfor];
    mainProgram = "ntopng";
  };
})
