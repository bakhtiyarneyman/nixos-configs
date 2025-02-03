{
  config,
  pkgs,
  dimSeconds ? 10,
  dimStepSeconds ? 0.25,
  minBrightnessPercents ? 1,
}:
pkgs.stdenv.mkDerivation {
  name = "dim-screen";
  src = ./dim-screen.py;
  nativeBuildInputs = [pkgs.makeWrapper];

  buildCommand = ''
    mkdir -p $out/bin
    cp $src $out/bin/dim-screen
    chmod +x $out/bin/dim-screen
    wrapProgram $out/bin/dim-screen \
      --prefix PATH : ${pkgs.light}/bin:${pkgs.libnotify}/bin:${pkgs.upower}/bin \
      --add-flags "\
      --dim-seconds ${builtins.toString dimSeconds} \
      --dim-step-seconds ${builtins.toString dimStepSeconds} \
      --min-brightness-percents ${builtins.toString minBrightnessPercents} \
    ${
      if builtins.elem "nohibernate" config.boot.kernelParams
      then ""
      else "--hibernate"
    }
      "
  '';

  checkPhase = ''
    ${pkgs.python3}/bin/python3 -m py_compile $src
  '';
}
