{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot = {
    initrd = {
      availableKernelModules = [ "ahci" "xhci_pci" "virtio_pci" "sr_mod" "virtio_blk" ];
      kernelModules = [ ];
    };
    extraModulePackages = [ ];
    loader.grub = {
      enable = true;
      device = "/dev/vda";
    };
    zfs = {
      extraPools = [ "backups" ];
      requestEncryptionCredentials = false;
    };
  };

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/3102206d-3e6a-4c88-9fb0-7ae5387c4e3e";
    fsType = "ext4";
  };

  swapDevices = [
    { device = "/dev/disk/by-uuid/d444f37c-7217-4fe9-a0de-a9135cc5d61a"; }
  ];

  networking = {
    # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
    # (the default) this is the recommended approach. When using systemd-networkd it's
    # still possible to use this option, but it's recommended to use it in conjunction
    # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
    useDHCP = lib.mkDefault true;
    # interfaces.enp1s0.useDHCP = lib.mkDefault true;

    hostId = "a4d09f93";
  };

  services = {
    fail2ban = {
      enable = true;
      bantime-increment = {
        enable = true;
        factor = "4";
        rndtime = "8m";
      };
      jails = {
        sshd = ''
          enabled = true
          port = 22
          mode = aggressive
        '';
      };
    };
    journal-brief.settings = {
      exclusions = [
        {
          SYSLOG_IDENTIFIER = [ "sshd" ];
          MESSAGE = [
            "/fatal: Timeout before authentication/"
            "/error: PAM: Authentication failure for illegal user/"
          ];
        }
      ];
    };
    zrepl.settings = {
      jobs = [
        {
          type = "sink";
          name = "backups";
          serve = {
            type = "stdinserver";
            client_identities = [ "iron" ];
          };
          root_fs = "backups";
          recv = {
            properties = {
              override = {
                copies = 2;
              };
            };
            placeholder = {
              encryption = "off";
            };
          };
        }
      ];
    };
  };
  system.stateVersion = "22.11";

  users.users.root.openssh.authorizedKeys.keys = [
    ''command="zrepl stdinserver iron",restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJEhmdQV/OLmYQFKIMCs17JssVqPlkaQCSTmwyhkhqVo''
  ];
  users.users.bakhtiyar.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGxoBwt5zviLpPomH5vHq0OQzN/G9dMKmyq+2y91xkRe github@1password"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDsGRMyBB18Gnhf5Igw/w5rbm6ks49TPZ2wY7iXKKh2L bakhtiyar@iron"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICT17FwJcNp9/YMx73tOakZutUtEbcjct4YPCywWsDL7 bakhtiyar@kevlar"
  ];
}
