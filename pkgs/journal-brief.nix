# Nix package for twaugh/journal-brief.
{
  fetchFromGitHub,
  buildPythonPackage,
  pytest,
  flexmock,
  pytest-mock,
  systemd,
  pyyaml
}:
buildPythonPackage rec {
  pname = "journal-brief";
  version = "1.1.8";
  src = fetchFromGitHub {
    owner = "twaugh";
    repo = "journal-brief";
    rev = "v${version}";
    sha256 = "Q0ydbIwn0w5rnZ4o1k9/XZLHHczIxvYIJvUscBAR120=";
  };

  propagatedBuildInputs = [
    systemd
    pyyaml
  ];

  nativeCheckInputs = [
    pytest
    flexmock
    pytest-mock
  ];

  checkPhase = ''
    pytest -k 'not test_login and not test_systemd'
  '';
}
