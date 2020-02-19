{ pkgs }:
with pkgs;
symlinkJoin {
  name = "vscode";
  paths = [ vscode ];
  buildInputs = [ makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/code \
      --add-flags "--user-data-dir=/etc/nixos/vscode"
  '';
}