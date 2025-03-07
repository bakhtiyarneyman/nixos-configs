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
      smartd = {
        enable = true;
        extraOptions = [
          "-A /var/log/smartd/"
          "--interval=3600"
        ];
      };

      fwupd.enable = true;
    };
  };
}
