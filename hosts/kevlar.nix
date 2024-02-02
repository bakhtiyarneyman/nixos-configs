{pkgs, ...}: {
  imports = [
    ../mixins/intel.nix
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
    };
    environment = {
      variables = {
        LIBVA_DRIVER_NAME = "iHD";
      };
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

      "/tailnet/iron/home" = {
        device = "iron:/tailnet/export/home";
        fsType = "nfs";
      };
    };

    hardware = {
      firmware = [pkgs.unstable.firmwareLinuxNonfree];
    };

    nix.settings = {
      substituters = [
        # "http://iron-tailscale:5000"
      ];
    };

    programs.i3status-rust = {
      networkInterface = "wlp170s0";
    };

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
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

        CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

        CPU_MAX_PERF_ON_AC = 100;
        CPU_MAX_PERF_ON_BAT = 20;
        CPU_MIN_PERF_ON_AC = 0;
        CPU_MIN_PERF_ON_BAT = 0;

        PCIE_ASPM_ON_BAT = "powersupersave";
        START_CHARGE_THRESH_BAT0 = 80;
        STOP_CHARGE_THRESH_BAT0 = 85;
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
          where = "/tailnet/iron/home";
        }
      ];

      mounts = [
        {
          type = "nfs";
          mountConfig = {
            Options = "noatime";
          };
          what = "iron:/tailnet/export/home";
          where = "/tailnet/iron/home";
        }
      ];
    };

    # This value determines the NixOS release with which your system is to be
    # compatible, in order to avoid breaking some software such as database
    # servers. You should change this only after NixOS release notes say you
    # should.
    system.stateVersion = "21.11";
  };
}
