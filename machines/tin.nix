{
  config,
  modulesPath,
  pkgs,
  ...
}: let
  qbittorrent = pkgs.qbittorrent.override {guiSupport = false;};
  sataDiskIds = [
    "ata-SanDisk_Ultra_II_960GB_160401800296"
    "ata-SanDisk_Ultra_II_960GB_160401800948"
  ];
  toDevice = id: "/dev/disk/by-id/${id}";
  toPartitionId = diskId: partition: "${diskId}-part${toString partition}";
  bootPartition = 1;
in {
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
      autoUnlock = {
        enable = true;
        keys = {
          pool = "slow";
          blockDevice = "/dev/zvol/slow/auto-unlock-keys";
        };
      };

      availableKernelModules = [
        "xhci_pci"
        "ahci"
        "nvme"
        "usb_storage"
        "usbhid"
        "sd_mod"
        "sdhci_pci"
        "igc"
      ];

      network.access = {
        enable = true;
        tailscaleState = "/var/lib/tailscale/tailscaled.state";
      };
    };
    # For i915 on N150.
    kernelPackages = pkgs.linuxKernel.packages.linux_6_12;
    kernelParams = [
      "i915.enable_guc=3"
    ];

    lanzaboote = {
      configurationLimit = 10;
      settings = {
        console-mode = "max";
      };
    };
  };

  environment = {
    systemPackages = with pkgs; [
      qbittorrent
      jellyfin-ffmpeg
    ];
    variables = {
      LIBVA_DRIVER_NAME = "iHD";
    };
  };

  fileSystems = {
    "/boot" = {
      device = toDevice (toPartitionId (builtins.head sataDiskIds) bootPartition);
      fsType = "vfat";
    };
    "/" = {
      device = "slow/crypt";
      fsType = "zfs";
      options = ["zfsutil"];
    };
    # The following are not strictly needed for booting, but that's currently the only way to ensure that the pool is imported and unlocked in the initrd, which is necessary because that's the only time auto-unlock may happen. The implication is that if this data pool dies or gets removed, the system will go to rescue mode. Bad.
    #
    # Ideally upstream would expose something like `boot.initrd.zfs.unlockedPools` which is like `neededForBoot` but only for importing and unlocking.
    "/entertainment" = {
      device = "fast/crypt/entertainment";
      fsType = "zfs";
      options = ["zfsutil"];
      neededForBoot = true;
    };
    "/scratchpad" = {
      device = "fast/crypt/scratchpad";
      fsType = "zfs";
      options = ["zfsutil"];
      neededForBoot = true;
    };
  };

  hardware.graphics = {
    enable = true;
  };
  networking = {
    hostId = "3b777fc4";
  };

  networking.firewall.allowedTCPPorts = [52285];
  nixpkgs.hostPlatform = "x86_64-linux";

  services = {
    jellyfin = {
      enable = true;
      package = pkgs.unstable.jellyfin;
    };
    jellyseerr.enable = true;
    monero = {
      enable = true;
      extraConfig = ''
        rpc-ssl=enabled
        rpc-ssl-private-key=/etc/nixos/secrets/tin.orkhon-mohs.ts.net.key
        rpc-ssl-certificate=/etc/nixos/secrets/tin.orkhon-mohs.ts.net.crt

        confirm-external-bind=true

        prune-blockchain=1

        out-peers=64
        in-peers=1024
      '';
      limits = {
        upload = 15; # KB/s
      };
      rpc.address = "0.0.0.0";
    };
    openvpn.servers.mullvad = {
      config = "config ${../mullvad/mullvad_us_sjc.conf}";
      updateResolvConf = true;
    };
    prowlarr.enable = true;
    radarr.enable = true;
    sonarr.enable = true;
    tailscale.enable = true;
    vscode-server.enable = true;
    xserver.videoDrivers = ["intel"];
    zrepl = {
      settings = {
        jobs = let
          makeGrid = grid: [
            {
              type = "grid";
              inherit grid;
              regex = "^zrepl_.*";
            }
            {
              type = "regex";
              negate = true;
              regex = "^zrepl_.*";
            }
          ];
          snapshotting = {
            type = "periodic";
            interval = "10m";
            prefix = "zrepl_";
            timestamp_format = "iso-8601";
          };
        in [
          {
            type = "push";
            name = "push";
            connect = {
              type = "ssh+stdinserver";
              host = "bakhtiyar.zfs.rent";
              user = "root";
              port = 22;
              identity_file = "/etc/nixos/secrets/zrepl";
              options = ["IdentitiesOnly=yes"];
            };
            filesystems = {
              "slow/crypt/etc/nixos/secrets<" = true;
              "slow/crypt/home/bakhtiyar<" = true;
              "slow/crypt/entertainment<" = true;
              "slow/crypt/entertainment/video<" = false;
              "slow/crypt/var/lib/hass<" = true;
              "slow/crypt/var/lib/hass/tts" = false;
            };
            send = {
              bandwidth_limit.max = "500 KiB";
              encrypted = true;
            };
            inherit snapshotting;
            pruning = let
              keptLong = makeGrid "1x1h(keep=all) | 23x1h | 6x1d | 3x1w | 12x4w | 4x365d";
            in {
              keep_sender = [{type = "not_replicated";}] ++ keptLong;
              keep_receiver = keptLong;
            };
          }
          {
            type = "snap";
            name = "snap";
            filesystems = {
              "slow/crypt/var/lib" = true;
            };
            snapshotting = {
              type = "periodic";
              interval = "1m";
              prefix = "zrepl_";
              timestamp_format = "iso-8601";
            };
            pruning.keep = [
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
          }
        ];
      };
    };
  };

  users = {
    users = {
      qbittorrent = {
        isSystemUser = true;
        home = "/var/lib/qbittorrent";
        group = "qbittorrent";
        createHome = true;
      };
    };
    groups = {
      qbittorrent = {};
      entertainment.members =
        [config.users.users.bakhtiyar.name "qbittorrent"]
        ++ map (service: config.services."${service}".user) [
          "jellyfin"
          "radarr"
          "sonarr"
        ];
    };
  };

  system = {
    stateVersion = "24.11";
    autoUpgrade.flags = [
      "--option"
      "extra-binary-caches"
      "http://iron:5000"
    ];
  };

  systemd.services.qbittorrent = {
    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];
    serviceConfig = {
      ExecStart = "${qbittorrent}/bin/qbittorrent-nox";
      Restart = "always";
      RestartSec = "5";
      User = "qbittorrent";
      UMask = "0002";
      Group = "qbittorrent";
    };
  };
}
