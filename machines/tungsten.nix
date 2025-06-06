{
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ../mixins/always-on.nix
    ../mixins/untrusted.nix
    ../mixins/zfs.nix
  ];

  boot = {
    initrd = {
      availableKernelModules = ["ahci" "xhci_pci" "virtio_pci" "sr_mod" "virtio_blk"];
    };
    extraModulePackages = [];
    loader.grub = {
      enable = true;
      device = "/dev/vda";
    };
    zfs = {
      extraPools = ["backups"];
      requestEncryptionCredentials = false;
    };
  };

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/3102206d-3e6a-4c88-9fb0-7ae5387c4e3e";
    fsType = "ext4";
  };

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
        sshd.settings = {
          port = 22;
          mode = "aggressive";
        };
      };
    };
    journal-brief.settings = {
      exclusions = [
        {
          SYSLOG_IDENTIFIER = ["sshd"];
          MESSAGE = [
            "/fatal: Timeout before authentication/"
            "/error: PAM: Authentication failure for illegal user/"
            "/error: PAM: Authentication failure for root/"
            "/error: kex_exchange_identification: Connection closed by remote host/"
            "/error: kex_exchange_identification: banner line contains invalid characters/"
            "/error: kex_exchange_identification: read: Connection reset by peer/"
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
            client_identities = ["iron" "tin"];
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

  swapDevices = [
    {device = "/dev/disk/by-uuid/d444f37c-7217-4fe9-a0de-a9135cc5d61a";}
  ];

  system.stateVersion = "22.11";
  systemd.network = {
    enable = true;
    networks."10-wan" = {
      matchConfig.Name = "enp1s0";
      networkConfig = {
        DHCP = "ipv4";
        IPv6AcceptRA = true;
      };
      linkConfig.RequiredForOnline = "routable";
    };
  };

  users.users.root.openssh.authorizedKeys.keys = [
    ''command="zrepl stdinserver iron",restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJEhmdQV/OLmYQFKIMCs17JssVqPlkaQCSTmwyhkhqVo''
    ''command="zrepl stdinserver tin",restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGsCjGJ3jpYghhtc8u4Rjj+ZNufbpGlJi5C5cEp1wavs''
  ];
}
