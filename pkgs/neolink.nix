{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  protobuf,
  gst_all_1,
  openssl,
}:
rustPlatform.buildRustPackage {
  pname = "neolink";
  version = "0.6.3-rc.2";

  src = fetchFromGitHub {
    owner = "QuantumEntangledAndy";
    repo = "neolink";
    rev = "v0.6.3.rc.2";
    hash = "sha256-voen4qVSSCOhc4f+kzmSecQsuwEIbHiW2x9kxQOvuRk=";
  };

  useFetchCargoVendor = true;
  cargoHash = "sha256-M7bz3blmbfZ8jU7NjOA/+HTJ+axqByvlROQ5E1N3xs4=";

  nativeBuildInputs = [
    pkg-config
    protobuf
    gst_all_1.gstreamer
  ];

  buildInputs = [
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-rtsp-server
    openssl
  ];

  meta = with lib; {
    description = "An RTSP bridge to Reolink IP cameras";
    homepage = "https://github.com/QuantumEntangledAndy/neolink";
    license = licenses.agpl3Only;
    mainProgram = "neolink";
  };
}
