# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, ... }:

{
  imports =
    [ <nixpkgs/nixos/modules/installer/scan/not-detected.nix>
    ];

  networking.hostName = "silk";
  programs.i3status-rust = {
    networkInterface = "wlp0s20f3";
    extraConfig = ''
      [[block]]
      block = "bluetooth"
      mac = "9B:5F:02:59:DB:63"
      label = " ARI"
    '';
  };

  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [ "i8042.dumbkbd" ];
  boot.extraModprobeConfig = ''
    options snd-intel-dspcfg dsp_driver=1
  '';
  boot.initrd.luks.devices."crypted".device = "/dev/disk/by-uuid/92e89be8-e335-4f26-b7fc-d824692ec5b1";

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/9300d74d-1638-411a-b269-5dc1814fb27e";
      fsType = "btrfs";
    };
    "/boot" = {
      device = "/dev/disk/by-uuid/C962-8DCE";
      fsType = "vfat";
    };
  };

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "20.09";
  hardware.firmware = [(import <unstable> {}).firmwareLinuxNonfree];
  services.xserver = {
    videoDrivers = [ "modesetting" ];
    # DPI overrides this.
    monitorSection = ''
      DisplaySize 310 174 # mm.
    '';
    dpi = 220;
  };
  environment.etc."libinput/local-overrides.quirks" = {
    text = ''
     [Lenovo Yoga Slim 9 Pressurepad]
     MatchBus=i2c
     MatchVendor=0x27C6
     MatchProduct=0x01E8
     AttrEventCodeDisable=ABS_MT_PRESSURE;ABS_PRESSURE;
   '';
  };
}
