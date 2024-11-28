{
  fetchFromGitHub,
  stdenv,
  python3,
}:
stdenv.mkDerivation rec {
  name = "waydroid_script";

  buildInputs = [
    (python3.withPackages (ps: with ps; [tqdm requests inquirerpy]))
  ];

  src = fetchFromGitHub {
    owner = "casualsnek";
    repo = name;
    rev = "1a2d3ad643206ad5f040e0155bb7ab86c0430365";
    sha256 = "15f8qkwmz0jkr85cg1d5bdk1yvsnf4w5magia215rc1gczmlw9is";
  };

  postPatch = ''
    patchShebangs main.py
  '';

  installPhase = ''
    mkdir -p $out/libexec
    cp -r . $out/libexec/waydroid_script
    mkdir -p $out/bin
    ln -s $out/libexec/waydroid_script/main.py $out/bin/waydroid_script
  '';
}
