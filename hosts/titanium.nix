# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, ... }:

{
  imports =
    [ <nixpkgs/nixos/modules/installer/scan/not-detected.nix>
    ];

  networking.hostName = "titanium";
  programs.i3status-rust.networkInterface = "wlp0s20f3";

  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.blacklistedKernelModules = [ " snd_hda_intel" "snd_soc_skl" ]; # SOF audio should be used instead.
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/1d401dd1-0519-4d5f-b2e4-85d3610d676c";
      fsType = "btrfs";
    };

  boot.initrd.luks.devices."crypted".device = "/dev/disk/by-uuid/cf622407-adfc-4206-bf79-4386ca4d7f35";

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/6142-B96A";
      fsType = "vfat";
    };

  swapDevices = [ { label = "swap"; } ];

  nix.maxJobs = lib.mkDefault 8;
  powerManagement = {
    enable = true;
    cpuFreqGovernor = lib.mkDefault "powersave";
  };
}
