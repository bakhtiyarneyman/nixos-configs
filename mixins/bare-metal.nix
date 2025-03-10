{
  config,
  pkgs,
  ...
}: {
  config = {
    boot = {
      initrd.systemd = {
        enable = true;
        emergencyAccess = config.users.users.root.hashedPassword;
        network.enable = true;
      };
      loader.systemd-boot.memtest86.enable = true;
    };

    environment.systemPackages = with pkgs; [
      powertop
      sbctl
      smartmontools
    ];

    hardware = {
      enableRedistributableFirmware = true;
      logitech.wireless.enable = true;
    };

    services = {
      fwupd.enable = true;

      logind = {
        powerKey =
          if builtins.elem "nohibernate" config.boot.kernelParams
          then "suspend"
          else "suspend-then-hibernate";
        powerKeyLongPress = "poweroff";
      };

      smartd = {
        enable = true;
        extraOptions = [
          "-A /var/log/smartd/"
          "--interval=3600"
        ];
      };
    };
  };
}
