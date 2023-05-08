# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, boot, trivial, ... }:
let
  coreDiskIds = [
    "nvme-WD_BLACK_SN770_1TB_23085A802755"
    "nvme-WD_BLACK_SN770_1TB_23100L801126"
  ];
  backupDiskIds = [
    "wwn-0x5001b448b444e0e4"
    "wwn-0x5001b448b444e295"
  ];

  toPartitionId = diskId: partition: "${diskId}-part${toString partition}";
  toDevice = id: "/dev/disk/by-id/${id}";

  inherit (builtins) head toString map tail foldl';
  inherit (lib.trivial) flip;
in
{
  programs.i3status-rust = {
    networkInterface = "eno1";
    batteries = [
      {
        device = "battery_hidpp_battery_0";
        name = "";
      }
      {
        device = "battery_hidpp_battery_1";
        name = "";
      }
      {
        device = "ups_hiddev1";
        name = "";
      }
    ];
  };

  boot = {
    extraModulePackages = [ config.boot.kernelPackages.rtl88x2bu ];
    initrd = {
      availableKernelModules = [ "xhci_pci" "ehci_pci" "nvme" "ahci" "usb_storage" "usbhid" "sd_mod" ];
      luks.devices =
        let
          insertDevice = devices: id: devices // {
            ${"decrypted-${id}"} = {
              allowDiscards = true;
              bypassWorkqueues = true;
              device = toDevice id;
            };
          };
        in
        foldl' insertDevice { } (map (flip toPartitionId 3) coreDiskIds ++ backupDiskIds);
    };
    kernelModules = [ "zfs" ];
    kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;
    loader = {
      efi.efiSysMountPoint = "/boot/efis/${toPartitionId (head coreDiskIds) 1}";
      grub = {
        enable = true;
        version = 2;
        devices = map toDevice coreDiskIds;
        efiSupport = true;
        extraInstallCommands = (toString (map
          (diskId: ''
            set -x
            ${pkgs.coreutils-full}/bin/cp -r \
              ${config.boot.loader.efi.efiSysMountPoint}/EFI \
              /boot/efis/${toPartitionId diskId 1}
            set +x
          '')
          (tail coreDiskIds)));
        zfsSupport = true;
      };
    };
    supportedFilesystems = [ "zfs" ];
    zfs = {
      extraPools = [ "backups" ];
      forceImportRoot = false; # zfs_force=1 in kernel command line.
    };
  };

  swapDevices =
    let
      toSwapDevice = diskId:
        let
          partitionId = toPartitionId diskId 4;
          device = toDevice partitionId;
        in
        {
          device = "/dev/mapper/decrypted-${partitionId}";
          encrypted = {
            blkDev = device;
            enable = true;
            # Created with `dd count=1 bs=512 if=/dev/urandom of=/etc/swap.key`.
            keyFile = "/mnt-root/etc/swap.key";
            label = "decrypted-${partitionId}";
          };
        };
    in
    map toSwapDevice coreDiskIds;

  fileSystems =
    let
      fss =
        {
          "/boot" = {
            device = "boot/nixos/root";
            fsType = "zfs";
          };
          "/" = {
            device = "main/nixos/root";
            fsType = "zfs";
          };
          "/var" = {
            device = "main/nixos/var";
            fsType = "zfs";
          };
          "/var/lib" = {
            device = "main/nixos/var/lib";
            fsType = "zfs";
          };
          "/var/log" = {
            device = "main/nixos/var/log";
            fsType = "zfs";
          };
          "/home" = {
            device = "main/nixos/home";
            fsType = "zfs";
          };
          "/home/bakhtiyar/dev" = {
            device = "main/nixos/home/dev";
            fsType = "zfs";
          };
          "/home/bakhtiyar/.builds" = {
            device = "main/nixos/home/.builds";
            fsType = "zfs";
          };
        };
      insertBootFilesystem = fss: diskId:
        let
          partitionId = toPartitionId diskId 1;
        in
        fss // {
          "/boot/efis/${partitionId}" = {
            device = toDevice partitionId;
            fsType = "vfat";
            options = [
              "x-systemd.idle-timeout=1min"
              "x-systemd.automount"
              "noauto"
              "nofail"
              "noatime"
              "X-mount.mkdir"
            ];
          };
        };
    in
    foldl' insertBootFilesystem fss coreDiskIds;

  networking.hostId = "a7a93500";
  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "22.11";
  services = {
    zfs = {
      autoScrub.enable = true;
      trim.enable = true;
      zed.settings = {
        ZED_DEBUG_LOG = "/tmp/zed.debug.log";
        ZED_EMAIL_ADDR = let at = "@"; in "bakhtiyarneyman+iron${at}gmail.com";
        ZED_EMAIL_PROG = "${pkgs.msmtp}/bin/msmtp";
        ZED_EMAIL_OPTS = "@ADDRESS@";
        ZED_LOCKDIR = "/var/lock";

        ZED_NOTIFY_INTERVAL_SECS = 3600;
        ZED_NOTIFY_VERBOSE = false;

        ZED_USE_ENCLOSURE_LEDS = true;
        ZED_SCRUB_AFTER_RESILVER = true;
      };
    };
    zrepl = {
      enable = true;
      settings = {
        jobs = [
          {
            name = "backups";
            type = "sink";
            serve = {
              type = "local";
              listener_name = "backups";
            };
            root_fs = "backups";
            recv = {
              placeholder = {
                encryption = "off";
              };
            };
          }
          {
            name = "backup_home";
            type = "push";
            connect = {
              type = "local";
              listener_name = "backups";
              client_identity = "iron";
            };
            filesystems = {
              "main/nixos/home<" = true;
              "main/nixos/home/.builds" = false;
            };
            snapshotting = {
              type = "periodic";
              interval = "10m";
              prefix = "zrepl_";
              timestamp_format = "iso-8601";
            };
            pruning = {
              keep_sender = [
                { type = "not_replicated"; }
                {
                  type = "grid";
                  grid = "1x1h(keep=all) | 23x1h";
                  regex = "^zrepl_.*";
                }
                {
                  type = "regex";
                  negate = true;
                  regex = "^zrepl_.*";
                }
              ];
              keep_receiver = [
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

    xserver = {
      videoDrivers = [ "amdgpu" ];
      xrandrHeads = [
        { output = "DP-1"; primary = true; }
        { output = "DP-3"; }
      ];
      dpi = 175;
      displayManager = {
        gdm.enable = true;
        setupCommands = ''
          ${pkgs.xorg.xrandr}/bin/xrandr --setprovideroutputsource "modesetting" NVIDIA-0
          ${pkgs.xorg.xrandr}/bin/xrandr --output DP-1 --auto --primary --output DP-3 --auto --right-of DP-1
        '';
      };
    };

    jellyfin = {
      enable = true;
      openFirewall = true;
    };

    nix-serve = {
      enable = true;
      openFirewall = true;
      secretKeyFile = "/etc/secrets/cache-priv-key.pem";
    };
  };

  programs.sway = {
    extraOptions = [ "--unsupported-gpu" ];
    extraSessionCommands = ''
      export WLR_NO_HARDWARE_CURSORS=1
    '';
  };
  virtualisation.docker.enableNvidia = true;
}
