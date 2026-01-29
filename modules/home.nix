{lib, ...}: let
  inherit (lib) mkOption types;
in {
  options.home.devices = mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        mac = mkOption {
          type = types.str;
          description = "MAC address of the device";
        };
        ip = mkOption {
          type = types.str;
          description = "Static IP address of the device";
        };
        wanBlocked = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to block WAN access for this device";
        };
      };
    });
    default = {};
    description = "List of devices with static network configuration";
  };
}
