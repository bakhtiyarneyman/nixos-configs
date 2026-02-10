{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}: let
  qbittorrent = pkgs.qbittorrent.override {guiSupport = false;};
  sataDiskIds = [
    "ata-SanDisk_Ultra_II_960GB_160401800948"
    "nvme-WD_BLACK_SN770_2TB_24471W800024"
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
    ../mixins/home-assistant.nix
    ../mixins/frigate.nix
    ../mixins/mullvad.nix
    ../mixins/on-battery.nix
    ../mixins/untrusted.nix
    ../mixins/zfs.nix
    ../mixins/router.nix
  ];

  home.devices = {
    camera_living_room = {
      mac = "0c:79:55:ac:ea:67";
      ip = "192.168.10.15";
      wanBlocked = true;
    };
  };

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
      jellyfin-ffmpeg
      openvino
      qbittorrent
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
    "/etc" = {
      device = "slow/crypt/etc";
      fsType = "zfs";
      options = ["zfsutil"];
    };
    "/var/lib" = {
      device = "slow/crypt/var/lib";
      fsType = "zfs";
      options = ["zfsutil"];
    };
    "/var/log" = {
      device = "slow/crypt/var/log";
      fsType = "zfs";
      options = ["zfsutil"];
    };
    "/var/cache/jellyfin/transcodes" = {
      device = "none";
      fsType = "tmpfs";
      options = ["size=20G"];
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
    wireguard.interfaces.mullvad = {
      fwMark = "51820";
      ips = ["10.67.21.121/32" "fc00:bbbb:bbbb:bb01::4:1578/128"];
    };
  };

  nix = {
    buildMachines = [
      {
        hostName = "iron";
        system = "x86_64-linux";
        protocol = "ssh-ng";
        sshUser = "nix-remote-builder";
        sshKey = "/etc/ssh/ssh_host_ed25519_key";
        maxJobs = 32;
        speedFactor = 10;
        supportedFeatures = [
          "nixos-test"
          "benchmark"
          "big-parallel"
          "kvm"
        ];
        mandatoryFeatures = [];
      }
    ];
    distributedBuilds = true;
    extraOptions = ''
      builders-use-substitutes = true
    '';
  };

  nixpkgs.hostPlatform = "x86_64-linux";

  services = {
    influxdb2 = {
      enable = true;
      provision = {
        enable = true;
        initialSetup = {
          bucket = "default";
          organization = "default";
          passwordFile = "/etc/nixos/secrets/influxdb2.password";
          tokenFile = "/etc/nixos/secrets/influxdb2.token";
        };
        organizations.default = {
          buckets.ntopng = {};
          auths.ntopng = {
            tokenFile = "/etc/nixos/secrets/ntopng_influxdb2.token";
            readBuckets = ["ntopng"];
            writeBuckets = ["ntopng"];
          };
        };
        users.ntopng.passwordFile = "/etc/nixos/secrets/ntopng_influxdb2.password";
      };
    };
    immich = {
      enable = true;
      environment = {
        IMMICH_LOG_LEVEL = "debug";
      };
      machine-learning = {
        environment = {
          IMMICH_LOG_LEVEL = "debug"; # Doesn't seem to work.
          MPLCONFIGDIR = "/var/lib/immich/mplconfig";
          LD_LIBRARY_PATH = let
            onnxruntime-openvino = pkgs.python312Packages.callPackage ../pkgs/onnxruntime-openvino.nix {};
          in
            builtins.concatStringsSep ":"
            [
              "${pkgs.python312Packages.openvino}/lib"
              "${pkgs.python312Packages.openvino}/lib/python3.12/site-packages/openvino"
              # Need to verify if openvino works.
              "${onnxruntime-openvino}/lib"
              "${onnxruntime-openvino}/lib/python3.12/site-packages/onnxruntime/capi"
            ];
        };
      };
    };
    jellyfin.enable = true;
    jellyseerr.enable = true;
    logind.settings.Login = {
      HandlePowerKey = lib.mkForce "reboot";
    };
    monero = {
      enable = true;
      extraConfig = ''
        rpc-ssl=enabled
        rpc-ssl-private-key=/etc/nixos/secrets/tin.orkhon-mohs.ts.net.key
        rpc-ssl-certificate=/etc/nixos/secrets/tin.orkhon-mohs.ts.net.crt

        confirm-external-bind=true

        prune-blockchain=1

        out-peers=16
        in-peers=16
      '';
      limits = {
        upload = 15; # KB/s
        download = 15000; # KB/s
      };
      rpc.address = "0.0.0.0";
    };
    nfs.server.boundExports = {
      memories = "/home/bakhtiyar/memories";
    };
    ntopng = {
      enable = true;
      httpPort = 4256;
      interfaces = [
        "mullvad"
        "tailscale0"
        "eth-lan"
        "eth-wan"
        "wlp0s13f0u2"
        "view:eth-lan,wlp0s13f0u2,mullvad,tailscale0"
      ];
      extraConfig = ''
        --local-networks=192.168.10.1/24
      '';
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
              "slow/crypt${config.services.immich.mediaLocation}" = true;
            };
            send = {
              bandwidth_limit.max = "3 MiB";
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
              "slow/crypt/var/lib<" = true;
              "slow/crypt/var/lib/hass<" = false;
              "slow/crypt/var/lib/monero<" = false;
              "slow/crypt/var/lib/systemd/coredump" = false;
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

  swapDevices = [
    {device = "/dev/disk/by-id/nvme-WD_BLACK_SN770_2TB_24471W800024-part3";}
  ];

  users = {
    users = {
      immich.extraGroups = ["video" "render"];
      prowlarr = {
        isSystemUser = true;
        group = "prowlarr";
      };
      qbittorrent = {
        isSystemUser = true;
        home = "/var/lib/qbittorrent";
        group = "qbittorrent";
        createHome = true;
      };
    };
    groups = let
      userOf = service: config.services."${service}".user;
    in {
      prowlarr = {};
      qbittorrent = {};
      server.members =
        [
          "hass"
          "monero"
          "prowlarr"
          "qbittorrent"
        ]
        ++ map userOf [
          "immich"
          "jellyfin"
          "radarr"
          "sonarr"
          "nginx"
        ];
      entertainment.members =
        [config.users.users.bakhtiyar.name "qbittorrent"]
        ++ map userOf [
          "jellyfin"
          "radarr"
          "sonarr"
        ];
    };
  };

  system = {
    stateVersion = "24.11";
  };

  systemd.services = let
    # Only necessary for 24.11.
    renderingServiceConfig = {
      PrivateDevices = lib.mkForce false;
      DeviceAllow = ["/dev/dri/renderD128"];
    };
    OMP_NUM_THREADS = "4";
  in {
    wyoming-faster-whisper-listener.environment = {
      inherit OMP_NUM_THREADS; # Doesn't seem to work.
    };
    wyoming-piper-speaker.environment = {
      inherit OMP_NUM_THREADS; # Doesn't seem to work.
    };
    immich-server = {
      serviceConfig = renderingServiceConfig // {ProtectHome = lib.mkForce false;};
    };
    immich-machine-learning = {
      serviceConfig = renderingServiceConfig;
    };
    prowlarr.serviceConfig = {
      User = "prowlarr";
      Group = "prowlarr";
    };
    qbittorrent = {
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
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
    tailscale-funnel-immich = {
      enable = true;
      after = ["network.target"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        ExecStart = "${pkgs.tailscale}/bin/tailscale funnel http://localhost:${toString config.services.immich.port}";
        Restart = "always";
        RestartSec = "5";
      };
    };
    influxdb2-ntopng-v1-auth = {
      description = "Set up InfluxDB2 v1 compatibility for ntopng";
      after = ["influxdb2.service"];
      requires = ["influxdb2.service"];
      wantedBy = ["multi-user.target"];
      path = [pkgs.influxdb2-cli pkgs.jq pkgs.fish];
      script = ''${pkgs.fish}/bin/fish --no-config ${../fix_ntong_auth_with_influxdb2.fish}'';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
  };
}
