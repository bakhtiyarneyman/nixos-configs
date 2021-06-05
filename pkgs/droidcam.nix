{ stdenv, fetchzip, pkgconfig, ffmpeg, gtk3-x11, libjpeg, libusbmuxd, alsaLib, speex, libappindicator }:

stdenv.mkDerivation rec {
  pname = "droidcam";
  version = "0";

  src = fetchzip {
    url = "https://github.com/dev47apps/droidcam/archive/refs/tags/v1.7.3.zip";
    sha256 = "1rgi3if3v0hksvh6kpyqmwl8f4gk6sa09pwcinq6gklj0wkhakrs";
  };

  sourceRoot = "source";

  buildInputs = [ pkgconfig ];
  nativeBuildInputs = [ ffmpeg gtk3-x11 libusbmuxd alsaLib libjpeg speex libappindicator ];

  postPatch = ''
    sed -i -e 's:/opt/libjpeg-turbo:${libjpeg.out}:' Makefile
    sed -i -e 's:$(JPEG_DIR)/lib`getconf LONG_BIT`:${libjpeg.out}/lib:' Makefile
    sed -i -e 's:libturbojpeg.a:libturbojpeg.so:' Makefile

  '';

  installPhase = ''
    mkdir -p $out/bin
    cp droidcam droidcam-cli $out/bin/
  '';

  meta = with stdenv.lib; {
    description = "DroidCam Linux client";
    homepage = https://github.com/aramg/droidcam;
  };
}