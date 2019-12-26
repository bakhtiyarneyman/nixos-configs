{ stdenv, rustPlatform, fetchFromGitHub, pkgconfig, dbus, libpulseaudio }:

rustPlatform.buildRustPackage rec {
  pname = "i3status-rust";
  version = "natural_scrolling";

  src = fetchFromGitHub {
    owner = "niobium0";
    repo = pname;
    rev = "${version}";
    sha256 = "1fzmpywlvbqjgm8h742vfzycajvg5wzxgaz135p2gkzz00vx5skh";
  };

  cargoSha256 = "1cf3zf48ivxqjlal6m3jq3s5yc6lwkqjzjmfbxmw40c6ia77g9ry";

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
