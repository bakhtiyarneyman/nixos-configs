# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, boot, ... }:

{
  imports =
    [ <nixpkgs/nixos/modules/installer/scan/not-detected.nix>
     ../modules/i3status-rust.nix
    ];

  networking.hostName = "iron";
  programs.i3status-rust.networkInterface = "eno1";

  boot.initrd.availableKernelModules = [ "xhci_pci" "ehci_pci" "ahci" "usb_storage" "usbhid" "sd_mod" ];
  boot.kernelPackages = pkgs.linuxPackages;
  boot.initrd.luks.devices."crypted".device = "/dev/disk/by-uuid/8dcc8ac6-cb24-4d17-a412-c6ca32c02f9b";

  fileSystems = {
    "/" = { device = "/dev/mapper/crypted";
      fsType = "btrfs";
    };
    "/boot" = {
      device = "/dev/disk/by-label/boot";
      fsType = "vfat";
    };
    "/mnt/storage" = {
      device = "/dev/disk/by-uuid/d838985e-9b04-4d7f-84c7-de7b73186858";
      fsType = "btrfs";
    };
  };

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "19.03";
  hardware.nvidia = {
    modesetting.enable = true;
    prime = {
      sync.enable = true;
      # Bus ids can be found using lspci.
      nvidiaBusId = "PCI:1:0:0";
      intelBusId = "PCI:0:2:0";
    };
  };
  services.xserver = {
    videoDrivers = [ "nvidia" ];
    xrandrHeads = [
      { output = "DP-4"; primary = true; }
      { output = "DP-2"; }
    ];
    dpi = 175;
    displayManager.lightdm.enable = true;
  };

  virtualisation.docker = {
    enable = true;
    enableNvidia = true;
  };

  users.users.bakhtiyar.extraGroups = [ "docker" ];
}
