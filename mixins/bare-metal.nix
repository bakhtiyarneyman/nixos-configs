{
  config,
  pkgs,
  ...
}: {
  config = {
    environment.systemPackages = with pkgs; [
      powertop
      smartmontools
    ];

    boot = {
      initrd.systemd = {
        enable = true;
        emergencyAccess = config.users.users.root.hashedPassword;
      };
      loader.grub.memtest86.enable = true;
    };

    hardware = {
      enableRedistributableFirmware = true;
      logitech.wireless.enable = true;
    };

    programs.corectrl.enable = true;

    services = {
      smartd = {
        enable = true;
        extraOptions = [
          "-A /var/log/smartd/"
          "--interval=3600"
        ];
      };

      fwupd.enable = true;

      # For battery conservation. Powertop disables wired mice.
      tlp = {
        enable = true;
      };
    };
  };
}
