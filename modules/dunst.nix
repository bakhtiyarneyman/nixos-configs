# This file was stolen from https://gitlab.com/xaverdh/my-nixos-config/
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.dunst;
  reservedSections = [
    "global"
    "experimental"
    "frame"
    "shortcuts"
    "urgency_low"
    "urgency_normal"
    "urgency_critical"
  ];
in {
  options.services.dunst = {
    enable = mkEnableOption "the dunst notifications daemon";

    extraArgs = mkOption {
      type = with types; listOf str;
      default = [];
      description = ''
        Extra command line options for dunst
      '';
    };

    globalConfig = mkOption {
      type = with types; attrsOf str;
      default = {};
      description = ''
        The global configuration section for dunst.
      '';
    };

    experimentalConfig = mkOption {
      type = with types; attrsOf str;
      default = {};
      description = ''
        The experimental configuration section for dunst.
      '';
    };

    shortcutsConfig = mkOption {
      type = with types; attrsOf str;
      default = {};
      description = ''
        The shortcut configuration for dunst.
      '';
    };

    urgencyConfig = {
      low = mkOption {
        type = with types; attrsOf str;
        default = {};
        description = ''
          The low urgency section of the dunst configuration.
        '';
      };
      normal = mkOption {
        type = with types; attrsOf str;
        default = {};
        description = ''
          The normal urgency section of the dunst configuration.
        '';
      };
      critical = mkOption {
        type = with types; attrsOf str;
        default = {};
        description = ''
          The critical urgency section of the dunst configuration.
        '';
      };
    };

    rules = mkOption {
      type = with types; attrsOf (attrsOf str);
      default = {};
      description = ''
        These rules allow the conditional modification of notifications.

        Note that rule names may not be one of the following
        keywords already used internally:
          ${concatStringsSep ", " reservedSections}
        There are 2 parts in configuring a rule: Defining when a rule
        matches and should apply (called filtering in the man page)
        and then the actions that should be taken when the rule is
        matched (called modifying in the man page).
      '';
      example = literalExample ''
        signed_off = {
          appname = "Pidgin";
          summary = "*signed off*";
          urgency = "low";
          script = "pidgin-signed-off.sh";
        };
      '';
    };
  };

  config = let
    dunstConfig = lib.generators.toINI {} allOptions;
    allOptions =
      {
        global = cfg.globalConfig;
        shortcuts = cfg.shortcutsConfig;
        urgency_normal = cfg.urgencyConfig.normal;
        urgency_low = cfg.urgencyConfig.low;
        urgency_critical = cfg.urgencyConfig.critical;
      }
      // cfg.rules;

    dunst-args =
      [
        "-config"
        (pkgs.writeText "dunstrc" dunstConfig)
      ]
      ++ cfg.extraArgs;
  in
    mkIf cfg.enable {
      assertions = flip mapAttrsToList cfg.rules (name: conf: {
        assertion = ! elem name reservedSections;
        message = ''
          dunst config: ${name} is a reserved keyword. Please choose
          a different name for the rule.
        '';
      });

      systemd.user.services.dunst = {
        wantedBy = ["graphical-session.target"];
        partOf = ["graphical-session.target"];
        serviceConfig.ExecStart = [
          # This is needed to overwrite the ExecStart directive from the upstream service file.
          ""
          "${pkgs.dunst}/bin/dunst ${escapeShellArgs dunst-args}"
        ];
      };
      systemd.packages = [pkgs.dunst];
      services.dbus.packages = [pkgs.dunst];
      environment.systemPackages = [pkgs.dunst];
    };
}
