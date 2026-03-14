{
  haskellPackages,
  lib,
}:
haskellPackages.mkDerivation {
  pname = "claude-permission-hook";
  version = "0.1.0.0";
  src = ../tools/claude-permission-hook;
  isExecutable = true;
  executableHaskellDepends = with haskellPackages; [
    protolude
    attoparsec
    pcre-light
    process
    raw-strings-qq
    containers
  ];
  license = lib.licenses.mit;
  description = "Claude Code PreToolUse permission hook";
}
