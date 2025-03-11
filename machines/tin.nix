{
  lib,
  modulesPath,
  pkgs,
  ...
}: let
  qbittorrent = pkgs.qbittorrent.override {guiSupport = false;};
in {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ../mixins/always-on.nix
    ../mixins/bare-metal.nix
    ../mixins/intel.nix
    ../mixins/on-battery.nix
    ../mixins/untrusted.nix
    ../mixins/zfs.nix
  ];

  boot = {
    initrd = {
      autoUnlock = {
        enable = true;
        keys = {
          pool = "system";
          partition = "/dev/disk/by-id/nvme-WD_BLACK_SN770_2TB_24471W800024-part2";
          blockDevice = "/dev/zvol/system/secrets";
          files = {"system/root" = "zfs.key";};
        };
      };

      availableKernelModules = [
        "xhci_pci"
        "ahci"
        "nvme"
        "usb_storage"
        "usbhid"
        "sd_mod"
        "sdhci_pci"
        "igc"
      ];

      network.access = {
        enable = true;
        tailscaleState = "/var/lib/tailscale/tailscaled.state";
      };
    };

    lanzaboote = {
      configurationLimit = 10;
      settings = {
        console-mode = "max";
      };
    };
  };

  environment.systemPackages = [
    qbittorrent
  ];

  fileSystems = {
    "/boot" = {
      device = "/dev/disk/by-label/boot";
      fsType = "vfat";
    };
    "/" = {
      device = "system/root";
      fsType = "zfs";
    };
  };

  hardware = {
    graphics = {
      enable = true;
    };
  };
  networking = {
    hostId = "3b777fc4";
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  services = {
    openvpn.servers.mullvad = {
      config = "config ${../mullvad/mullvad_us_sjc.conf}";
      updateResolvConf = true;
    };

    tailscale.enable = true;
    vscode-server = {
      enable = true;
    };
    zrepl = {
      settings = {
        jobs = [
          {
            type = "snap";
            name = "snap";
            filesystems = {
              "system/root/var/lib" = true;
            };
            snapshotting = {
              type = "periodic";
              interval = "1m";
              prefix = "zrepl_";
              timestamp_format = "iso-8601";
            };
            pruning = {
              keep = [
                {
                  type = "grid";
                  grid = "1x1h(keep=all) | 23x1h | 6x1d | 3x1w | 12x4w | 4x365d";
                  regex = "^zrepl_.*";
                }
                {
                  type = "regex";
                  negate = true;
                  regex = "^zrepl_.*";
                }
              ];
            };
          }
        ];
      };
    };
  };

  system.stateVersion = "24.11";
}
