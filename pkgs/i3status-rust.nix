{ stdenv, rustPlatform, fetchFromGitHub, pkgconfig, dbus, libpulseaudio }:

rustPlatform.buildRustPackage rec {
  pname = "i3status-rust";
  version = "natural_scrolling";

  src = fetchFromGitHub {
    owner = "niobium0";
    repo = pname;
    rev = "${version}";
    sha256 = "1zkjdcq4q2785nn7qq4jfx0adcqfy8xy6dj1d7h0rjibx2dyc4fa";
  };

  cargoSha256 = "1vl58617wbc4s0qlpzw7mh3qm4gmfsa8wc6ns6d68yl3rwz2pkhk";

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
