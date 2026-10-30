{
  config,
  lib,
  pkgs,
  ...
}: {
  options.services.journal-brief = with lib;
  with types; {
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
        description = "Baseline priority level to report, in addition to explicit inclusions.";
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
        default = [];
        description = "List of exclusion rules.";
      };
      inclusions = mkOption {
        type = listOf (attrsOf (listOf str));
        default = [];
        description = "Rules for entries to report in addition to those at `priority`. Values match literally: journal-brief supports regexes only in exclusions.";
      };
    };
  };

  # If enabled run the script every day at 6:00AM via systemd.
  config = lib.mkIf config.services.journal-brief.enable {
    systemd = {
      network.wait-online.enable = true;
      services.journal-brief = {
        description = "Sends emails with journalctl logs";
        wantedBy = ["multi-user.target"];
        requires = ["network-online.target"];
        after = ["network-online.target"];
        serviceConfig = {
          Type = "oneshot";
          ExecStartPre =
            if config.networking.networkmanager.enable
            then "${pkgs.networkmanager}/bin/nm-online --quiet --timeout=30"
            else if config.networking.useNetworkd
            then "${pkgs.systemd}/lib/systemd/systemd-networkd-wait-online --timeout=30"
            else "${pkgs.coreutils-full}/bin/true"; # fall-back: do not block"
          ExecStart = let
            settings = config.services.journal-brief.settings;
            # journal-brief ANDs `priority` into every inclusion and reports only
            # entries matching some inclusion. Passing the priority as its own
            # inclusion instead makes the configured inclusions additive.
            yamlConfig = lib.generators.toYAML {} (removeAttrs settings ["priority"]
              // {
                inclusions = [{PRIORITY = settings.priority;}] ++ settings.inclusions;
              });
            configFile = pkgs.writeText "journal-brief-config.yaml" yamlConfig;
          in [
            "${pkgs.journal-brief}/bin/journal-brief --conf=${configFile}"
          ];
        };
      };
      timers.journal-brief = {
        description = "Sends emails with journalctl logs";
        wantedBy = ["timers.target"];
        after = ["network.target"];
        timerConfig = {
          OnCalendar = "*-*-* 06:00:00";
          Persistent = true;
        };
      };
    };
  };
}
