{ stdenv, lib, fetchzip, kernel }:

stdenv.mkDerivation rec {
  pname = "v4l2loopback-dc";
  version = "0";

  src = fetchzip {
    url = "https://github.com/dev47apps/droidcam/archive/refs/tags/v1.7.3.zip";
    sha256 = "1rgi3if3v0hksvh6kpyqmwl8f4gk6sa09pwcinq6gklj0wkhakrs";
  };

  sourceRoot = "source/v4l2loopback";

  KVER = "${kernel.modDirVersion}";
  KBUILD_DIR = "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build";

  nativeBuildInputs = kernel.moduleBuildDependencies;

  postPatch = ''
    sed -i -e 's:/lib/modules/$(KERNELRELEASE)/build:${KBUILD_DIR}:g' Makefile
  '';

  installPhase = ''
    mkdir -p $out/lib/modules/${KVER}/kernels/media/video
    cp v4l2loopback-dc.ko $out/lib/modules/${KVER}/kernels/media/video/
  '';

  meta = with lib; {
    description = "DroidCam kernel module v4l2loopback-dc";
    homepage = https://github.com/aramg/droidcam;
  };
}