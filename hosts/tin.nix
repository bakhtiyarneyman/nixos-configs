{
  config,
  lib,
  pkgs,
  modulesPath,
  utils,
  ...
}: {
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
      kernelModules = ["tpm_crb"];
      availableKernelModules = ["xhci_pci" "ahci" "nvme" "usb_storage" "usbhid" "sd_mod" "sdhci_pci" "ext4" "igb"];
      luks.devices.secrets = {
        device = "/dev/zvol/system/secrets";
        crypttabExtraOpts = [
          "tpm2-device=auto"
          "tpm2-measure-pcr=yes"
        ];
      };
      systemd = {
        enable = true;
        contents = {
          "/etc/fstab".text = ''
            /dev/mapper/secrets /secrets ext4 defaults,nofail,x-systemd.device-timeout=0,ro 0 2
          '';
        };
      };
    };
    loader = {
      systemd-boot = {
        enable = true;
        consoleMode = "max";
      };
    };
  };

  environment.systemPackages = [
    pkgs.sbctl
  ];

  fileSystems = {
    "/mnt/secrets" = {
      device = "/dev/mapper/secrets";
      fsType = "ext4";
      neededForBoot = true;
    };
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

  boot.initrd.systemd.services = {
    zfs-import-system.enable = false;
    import-system-pool = let
      partition = "${utils.escapeSystemdPath "/dev/disk/by-id/nvme-WD_BLACK_SN770_2TB_24471W800024-part2"}.device";
    in {
      requiredBy = ["load-system-key.service"];
      after = [partition];
      bindsTo = [partition];
      unitConfig.DefaultDependencies = false;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${config.boot.zfs.package}/bin/zpool import -f -N -d /dev/disk/by-id system";
        RemainAfterExit = true;
      };
    };

    load-system-key = {
      wantedBy = ["sysroot.mount"];
      before = ["sysroot.mount"];
      unitConfig = {
        RequiresMountsFor = ["/secrets"];
        DefaultDependencies = false;
      };
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${config.boot.zfs.package}/bin/zfs load-key -L file:///secrets/zfs.key system/root";
        RemainAfterExit = true;
      };
    };
  };
}
