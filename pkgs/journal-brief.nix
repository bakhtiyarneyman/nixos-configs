# Nix package for twaugh/journal-brief.
{ lib
, stdenv
, fetchFromGitHub
, python3Packages
}: python3Packages.buildPythonPackage rec {

  pname = "journal-brief";
  version = "1.1.8";
  src = fetchFromGitHub {
    owner = "twaugh";
    repo = "journal-brief";
    rev = "v${version}";
    sha256 = "Q0ydbIwn0w5rnZ4o1k9/XZLHHczIxvYIJvUscBAR120=";
  };

  propagatedBuildInputs = with python3Packages; [
    systemd
    pyyaml
  ];

  nativeCheckInputs = with python3Packages; [
    pytest
    flexmock
    pytest-mock
  ];

  checkPhase = ''
    pytest -k 'not test_login and not test_systemd'
  '';
}
