{pkgs, ...}: {
  imports = [
    ../mixins/bare-metal.nix
    ../mixins/gui.nix
    ../mixins/intel.nix
    ../mixins/on-battery.nix
    ../mixins/trusted.nix
    ../mixins/virtualization.nix
  ];

  config = {
    boot = {
      kernelParams = [''acpi_osi="!Windows 2020"'' "nvme.noacpi=1"];
      loader.systemd-boot.enable = true;
      initrd = {
        availableKernelModules = ["xhci_pci" "thunderbolt" "nvme" "usb_storage" "sd_mod" "rtsx_pci_sdmmc"];
        luks.devices."crypted" = {
          allowDiscards = true;
          bypassWorkqueues = true;
          device = "/dev/disk/by-uuid/74cf5bcb-f6a5-4410-8247-4a04ffe30826";
        };
      };
      supportedFilesystems = ["nfs"];
    };

    fileSystems = {
      "/" = {
        device = "/dev/mapper/crypted";
        fsType = "btrfs";
      };

      "/boot" = {
        device = "/dev/disk/by-label/BOOT";
        fsType = "vfat";
      };
    };

    networking.networkmanager.enable = true;

    nix.settings = {
      substituters = [
        # "http://iron-tailscale:5000"
      ];
    };

    programs.i3status-rust.temperature = {};

    services = {
      rpcbind.enable = true;
      xserver = {
        videoDrivers = ["modesetting"];
        # DPI overrides this.
        monitorSection = ''
          DisplaySize 285 190 # mm.
        '';
        dpi = 150;
      };
      tlp.settings = {
        CPU_SCALING_GOVERNOR_ON_AC = "powersave";
        CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
        PLATFORM_PROFILE_ON_AC = "performance";
        PCIE_ASPM_ON_BAT = "powersupersave";
        START_CHARGE_THRESH_BAT0 = 90;
        STOP_CHARGE_THRESH_BAT0 = 95;
      };
    };

    swapDevices = [{label = "swap";}];

    systemd = {
      automounts = [
        {
          wantedBy = ["multi-user.target"];
          automountConfig = {
            TimeoutIdleSec = "600";
          };
          where = "/imports/iron/home";
        }
      ];

      mounts = [
        {
          type = "nfs";
          mountConfig = {
            Options = "noatime";
          };
          what = "iron:/exports/home";
          where = "/imports/iron/home";
        }
      ];

      sleep.extraConfig = ''
        HibernateDelaySec=120min
      '';
    };

    # This value determines the NixOS release with which your system is to be
    # compatible, in order to avoid breaking some software such as database
    # servers. You should change this only after NixOS release notes say you
    # should.
    system.stateVersion = "21.11";
  };
}
