{
  config,
  lib,
  pkgs,
  yubikeys,
  ...
}: {
  imports = [
    ../modules/initrd-tailscale.nix
    ../modules/wifi-interface.nix
  ];

  config = {
    boot = {
      initrd = lib.mkMerge [
        {
          network = {
            enable = true;
            ssh = {
              enable = true;
              port = 22;
              hostKeys = ["/etc/ssh/initrd_ssh_host_ed25519_key"];
              # Password-based login is disabled in the initrd.
              authorizedKeys = let
                harden = key: ''command="echo 'Password to decrypt the disks?' && systemd-tty-ask-password-agent",restrict ${key}'';
              in
                map harden yubikeys;
            };
          };
          systemd = {
            enable = true;
            emergencyAccess = config.users.users.root.hashedPassword;
            network.enable = true;
          };
        }
        (lib.mkIf (config.networking.wifiInterface != null) (let
          interface = config.networking.wifiInterface;
        in {
          availableKernelModules = ["ctr" "ccm"] ++ config.networking.kernelModules;

          secrets = {
            "/etc/wpa_supplicant/wpa_supplicant-${interface}.conf" =
              /root/wpa_supplicant.conf;
          };
          systemd = {
            packages = [pkgs.wpa_supplicant];
            initrdBin = [
              pkgs.wpa_supplicant
              pkgs.unixtools.ping
              pkgs.unixtools.nettools
            ];

            targets.initrd.wants = ["wpa_supplicant@${interface}.service"];
            services."wpa_supplicant@".unitConfig.DefaultDependencies = false;

            network.enable = true;
            network.networks."10-wlan" = {
              matchConfig.Name = interface;
              networkConfig.DHCP = "yes";
            };
          };
        }))
      ];
      loader.grub.memtest86.enable = true;
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
