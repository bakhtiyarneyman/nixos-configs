# Nix package for twaugh/journal-brief.
{
  fetchFromGitHub,
  buildPythonPackage,
  pytest,
  flexmock,
  pytest-mock,
  systemd-python,
  pyyaml,
  setuptools,
}:
buildPythonPackage rec {
  pname = "journal-brief";
  version = "1.1.8";
  pyproject = true;

  build-system = [ setuptools ];

  src = fetchFromGitHub {
    owner = "twaugh";
    repo = "journal-brief";
    rev = "v${version}";
    sha256 = "Q0ydbIwn0w5rnZ4o1k9/XZLHHczIxvYIJvUscBAR120=";
  };

  propagatedBuildInputs = [
    systemd-python
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
