{pkgs, ...}: {
  config = {
    environment.systemPackages = with pkgs; [
      powertop
    ];

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
