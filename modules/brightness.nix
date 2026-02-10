{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.hardware.brightness;
in {
  options.hardware.brightness = {
    enable = mkEnableOption "brightness controls";

    upCommand = mkOption {
      type = types.str;
      default = "${pkgs.light}/bin/light -T 1.414";
      description = "Command to increase brightness";
    };

    downCommand = mkOption {
      type = types.str;
      default = "${pkgs.light}/bin/light -T 0.707";
      description = "Command to decrease brightness";
    };
  };

  config = mkIf cfg.enable {
    services.actkbd = {
      enable = true;
      bindings = [
        {
          keys = [224];
          events = ["key" "rep"];
          command = cfg.downCommand;
        }
        {
          keys = [225];
          events = ["key" "rep"];
          command = cfg.upCommand;
        }
      ];
    };
  };
}
