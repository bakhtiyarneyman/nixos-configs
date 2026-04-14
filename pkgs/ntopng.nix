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
  version = "6.7-unstable";

  src = fetchFromGitHub {
    owner = "bakhtiyarneyman";
    repo = "ntopng";
    rev = "f5281f6780b08507bed7265d1d8c0d57e8dc0a5d";
    hash = "sha256-Te4r97nuxafNNoqxZvgYwHUVI7bddmwduGuPURPrsqU=";
    fetchSubmodules = true;
  };

  # Guard Pro-only functions that the open-source build doesn't have.
  postPatch = ''
    sed -i 's/interface.getFlowDevices()/(interface.getFlowDevices or function() return {} end)()/' \
      scripts/lua/inc/menu.lua
    sed -i 's/interface.getSFlowDevices()/(interface.getSFlowDevices or function() return {} end)()/' \
      scripts/lua/inc/menu.lua
  '';

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

  autoreconfPhase = ''
    sed -i '/^git submodule/d' autogen.sh
    bash autogen.sh
  '';

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
