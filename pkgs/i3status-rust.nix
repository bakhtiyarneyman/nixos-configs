{ stdenv, rustPlatform, fetchFromGitHub, pkgconfig, dbus, libpulseaudio }:

rustPlatform.buildRustPackage rec {
  pname = "i3status-rust";
  version = "natural_scrolling";

  src = fetchFromGitHub {
    owner = "niobium0";
    repo = pname;
    rev = "${version}";
    sha256 = "1qjc4mxp9k9bw6vpafpzrrqidfnd4gfy43cv3p0i4mcn8yj2p8xf";
  };

  cargoSha256 = "1y75kc6p3z5ajvdbbkapnk872rnp0nlr16pn0fnr24zzygbnqhdw";

  nativeBuildInputs = [ pkgconfig ];

  buildInputs = [ dbus libpulseaudio ];

  # Currently no tests are implemented, so we avoid building the package twice
  doCheck = false;

  meta = with stdenv.lib; {
    description = "Very resource-friendly and feature-rich replacement for i3status";
    homepage = https://github.com/greshake/i3status-rust;
    license = licenses.gpl3;
    maintainers = with maintainers; [ backuitist globin ];
    platforms = platforms.linux;
  };
}
