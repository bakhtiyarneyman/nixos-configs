{pkgs}:
pkgs.writeTextFile {
  name = "journst";
  executable = true;
  destination = "/bin/journst";
  text = ''
    #!${pkgs.fish}/bin/fish
    ${pkgs.systemd}/bin/journalctl $argv --priority=err --output json-pretty |\
    stdbuf --output=0 ${pkgs.jq}/bin/jq --raw-output --join-output '"\(.SYSLOG_IDENTIFIER)\u0000\(.MESSAGE)\u0000"' |\
    while IFS= read --null appname; and read --null message;
      ${pkgs.dunst}/bin/dunstify --urgency=critical --appname=$appname Error $message;
    end
  '';
}
