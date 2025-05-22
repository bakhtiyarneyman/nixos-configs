{
  config,
  nix-colors,
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

    console = {
      packages = with pkgs; [
        powerline-fonts
      ];
      font = "ter-powerline-v32n";
      colors = with config.palette; [
        background
        red
        green
        yellow
        blue
        magenta
        cyan
        foreground
        black
        "ff0000"
        "00ff00"
        "ffff00"
        "0000ff"
        "ff00ff"
        "00ffff"
        white
      ];
    };

    environment.systemPackages = with pkgs; [
      iw
      powertop
      sbctl
      smartmontools
      stress
    ];

    hardware = {
      enableRedistributableFirmware = true;
      logitech.wireless.enable = true;
    };

    services = {
      fwupd.enable = true;

      kmscon = {
        enable = true;
        extraConfig = let
          toColor = name: hex: "palette-${name}=${nix-colors.lib.conversions.hexToRGBString ", " hex}";
          colors = builtins.concatStringsSep "\n" (
            builtins.attrValues (builtins.mapAttrs toColor config.palette)
          );
        in ''
          font-size=32
          palette=custom
          ${colors}
        '';
        fonts = [
          {
            name = "Fira Mono for Powerline";
            package = pkgs.fira;
          }
          {
            name = "Font Awesome 6 Free";
            package = pkgs.font-awesome_6;
          }
        ];
      };

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
