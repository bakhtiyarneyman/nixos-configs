# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, ... }:

{
  imports = [
    ../mixins/intel.nix
  ];

  config = {
    boot = {
      kernelParams = [ ''acpi_osi="!Windows 2020"'' "nvme.noacpi=1" ];
      loader.systemd-boot.enable = true;
      initrd = {
        availableKernelModules = [ "xhci_pci" "thunderbolt" "nvme" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
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
    };

    hardware = {
      firmware = [ pkgs.unstable.firmwareLinuxNonfree ];
    };

    nix.settings = {
      substituters = [
        "http://iron-tailscale:5000"
      ];
    };

    programs.i3status-rust = {
      networkInterface = "wlp170s0";
    };

    services = {
      xserver = {
        videoDrivers = [ "modesetting" ];
        # DPI overrides this.
        monitorSection = ''
          DisplaySize 285 190 # mm.
        '';
        dpi = 150;
        displayManager.gdm.enable = true;
      };
      tlp.settings = {
        PCIE_ASPM_ON_BAT = "powersupersave";
        START_CHARGE_THRESH_BAT0 = 80;
        STOP_CHARGE_THRESH_BAT0 = 85;
      };
    };

    swapDevices = [{ label = "swap"; }];

    # This value determines the NixOS release with which your system is to be
    # compatible, in order to avoid breaking some software such as database
    # servers. You should change this only after NixOS release notes say you
    # should.
    system.stateVersion = "21.11";

  };

}
