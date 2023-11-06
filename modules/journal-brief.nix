{ config, lib, pkgs, ... }:
{
  options.services.journal-brief = with lib; with types; {
    enable = mkEnableOption "Sends emails with journalctl logs";
    settings = {
      priority = mkOption {
        type = enum [
          "emerg"
          "alert"
          "crit"
          "err"
          "warning"
          "notice"
          "info"
          "debug"
        ];
        default = "err";
        description = "Priority level to match.";
      };
      email = {
        from = mkOption {
          type = str;
          description = "Email address to send from";
        };
        to = mkOption {
          type = str;
          description = "Email address to send to";
        };
        command = mkOption {
          type = str;
          default = "sendmail -i -t";
          description = "Command to send email with";
        };
      };
      exclusions = mkOption {
        type = listOf (attrsOf (listOf str));
        default = [ ];
        description = "List of exclusion rules.";
      };
      inclusions = mkOption {
        type = listOf (attrsOf (listOf str));
        default = [ ];
        description = "List of inclusion rules.";
      };
    };
  };

  # If enabled run the script every day at 4:00AM via systemd.
  config = lib.mkIf config.services.journal-brief.enable {
    systemd.services.journal-brief = {
      description = "Sends emails with journalctl logs";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart =
          let
            yamlConfig = lib.generators.toYAML { } config.services.journal-brief.settings;
            configFile = pkgs.writeText "journal-brief-config.yaml" yamlConfig;
          in
          [
            "${pkgs.journal-brief}/bin/journal-brief --conf=${configFile}"
          ];
      };
    };
    systemd.timers.journal-brief = {
      description = "Sends emails with journalctl logs";
      wantedBy = [ "timers.target" ];
      after = [ "network.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 06:00:00";
        Persistent = true;
      };
    };
  };
}
