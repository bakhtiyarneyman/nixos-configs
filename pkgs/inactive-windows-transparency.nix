{
  sway-unwrapped,
  fetchFromGitHub,
  buildPythonApplication,
  i3ipc
}:
buildPythonApplication rec {
  # long name is long
  lname = "inactive-windows-transparency";
  pname = "sway-${lname}";
  version = sway-unwrapped.version;

  src = fetchFromGitHub {
    owner = "gibbz00";
    repo = "sway";
    rev = "32bcfa5b9a33aff25795cd95faed2a9d7ff6efa3";
    sha256 = "05sks288cpvmgz719mpyf6fnfgs5lzdhi68b5d3bf3hwaxrcz7hs";
  };

  format = "other";
  dontBuild = true;
  dontConfigure = true;

  propagatedBuildInputs = [i3ipc];

  installPhase = ''
    install -Dm 0755 $src/contrib/${lname}.py $out/bin/${lname}.py
  '';

  meta =
    sway-unwrapped.meta
    // {
      description = "It makes inactive sway windows transparent";
      homepage = "https://github.com/swaywm/sway/tree/${sway-unwrapped.version}/contrib";
    };
}
