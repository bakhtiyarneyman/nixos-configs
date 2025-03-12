{
  lib,
  pkgs,
  ...
}: let
  coreDiskIds = [
    "nvme-WD_BLACK_SN770_1TB_23051T800986"
    "nvme-WD_BLACK_SN770_1TB_22307Y440407"
  ];

  toPartitionId = diskId: partition: "${diskId}-part${toString partition}";
  toDevice = id: "/dev/disk/by-id/${id}";

  inherit (builtins) toString map foldl';
in {
  imports = [
    ../mixins/always-on.nix
    ../mixins/amd.nix
    ../mixins/bare-metal.nix
    ../mixins/ecc.nix
    ../mixins/gui.nix
    ../mixins/home_assistant.nix
    ../mixins/neurasium.nix
    ../mixins/on-battery.nix
    ../mixins/trusted.nix
    ../mixins/zfs.nix
  ];

  config = {
    boot = {
      initrd = {
        availableKernelModules = [
          "ahci"
          "edac_mce_amd" # Not sure if it's needed. Added in attempt to fix rasdaemon.
          "ehci_pci"
          "nvme"
          "sd_mod"
          "usb_storage"
          "usbhid"
          "xhci_pci"
        ];
        network.access = {
          enable = true;
          tailscaleState = "/var/lib/tailscale/tailscaled.state";
        };
      };
      kernel.sysctl = {
        "vm.swappiness" = 1;
      };
      kernelParams = ["zfs.zfs_arc_max=17179869184"];
      loader.grub = {
        enable = true;
        efiSupport = true;
        mirroredBoots = let
          toBoot = diskId: {
            devices = [(toDevice diskId)];
            efiBootloaderId = "NixOS-${diskId}";
            efiSysMountPoint = "/boot/efis/${toPartitionId diskId 1}";
            path = "/boot";
          };
        in
          map toBoot coreDiskIds;
      };
    };

    environment = {
      systemPackages = with pkgs; [
        liquidctl
        amdgpu_top
        # Build a package for `tin` to pickup from cache.
        jellyfin-ffmpeg
      ];
      variables = {
        LIBVA_DRIVER_NAME = "radeonsi";
      };
    };

    fileSystems = let
      fss = {
        "/boot" = {
          device = "boot/nixos/root";
          fsType = "zfs";
        };
        "/" = {
          device = "fast/nixos/root";
          fsType = "zfs";
        };
        "/etc/nixos" = {
          device = "fast/nixos/etc-nixos";
          fsType = "zfs";
          neededForBoot = true;
        };
        "/tailnet/export/home" = {
          device = "/home/bakhtiyar";
          options = ["bind"];
        };
      };
      insertBootFilesystem = fss: diskId: let
        partitionId = toPartitionId diskId 1;
      in
        fss
        // {
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

    hardware.graphics.extraPackages = [
      pkgs.rocmPackages.clr
    ];

    networking = {
      hostId = "a7a93500";
      wifiInterface = "wlp12s0";
      kernelModules = ["mt7921e"];
    };

    programs = {
      i3status-rust = {
        batteries = [
          {
            model = "Wireless Mouse MX Master 3";
            icon = "";
          }
          {
            model = "CP1500AVRLCDa";
            icon = "";
          }
        ];
        extraBlocks = [
          {
            block = "amd_gpu";
            device = "card0";
            format = " $icon ^icon_cpu $utilization.eng(width:3) ";
            format_alt = " $icon ^icon_memory_mem $vram_used_percents.eng(width:3) ";
            interval = 1;
          }
        ];

        temperatureChip = "k10temp-*";
      };
      sway = {
        extraSessionCommands = ''
          export WLR_NO_HARDWARE_CURSORS=1
        '';
      };
    };

    services = {
      hardware.openrgb = {
        enable = true;
        package = with pkgs;
          openrgb.withPlugins [
            openrgb-plugin-effects
            openrgb-plugin-hardwaresync
            (pkgs.callPackage ../pkgs/openrgb-plugin-httphook.nix {})
          ];
      };

      ollama = {
        enable = true;
        acceleration = "rocm";
        rocmOverrideGfx = "10.3.2";
      };
      nextjs-ollama-llm-ui = {
        hostname = "0.0.0.0";
        enable = true;
      };
      monero = {
        enable = false;
        dataDir = "/var/lib/monero";
        extraConfig = ''
          rpc-restricted-bind-ip=100.65.77.115 # iron-tailscale
          rpc-restricted-bind-port=18081
          rpc-ssl=enabled
          rpc-ssl-private-key=/etc/nixos/secrets/iron.monero.private-key.pem
          rpc-ssl-certificate=${../certificates/iron.monero.cert.pem}

          prune-blockchain=1
          out-peers=64
          in-peers=1024
        '';
        limits = {
          upload = 10; # KB/s
        };
        # rpc.address = "100.0.0.0";
      };

      nfs.server = {
        enable = true;
        exports = ''
          /tailnet/export/home mercury-tailscale(rw,fsid=0,no_subtree_check)
        '';
        statdPort = 4000;
        lockdPort = 4001;
        mountdPort = 4002;
      };

      nix-serve = {
        enable = true;
        openFirewall = true;
        secretKeyFile = "/etc/nixos/secrets/iron.cache.private-key.pem";
      };

      jellyfin = {
        enable = true;
        openFirewall = true;
      };

      journal-brief.settings.exclusions = [
        # It's some USB hub internal to the ASRock B650E PG Riptide.
        {
          MESSAGE = ["hub 8-0:1.0: config failed, hub doesn't have any ports! (err -19)"];
          _SELINUX_CONTEXT = ["kernel"];
        }
        # This stems from remapping the PrintScreen key on the MX Keys keyboard. The remapping
        # works, so probably it's an issue with timing, i.e. this rule runs before we connect to
        # the keyboard via wireless/usb.
        {
          MESSAGE = ["event4: Failed to call EVIOCSKEYCODE with scan code 0x70049, and key code 99: Invalid argument"];
          _SELINUX_CONTEXT = ["kernel"];
        }
        {
          CODE_FILE = ["src/login/logind-core.c"];
          _SELINUX_CONTEXT = ["kernel"];
        }
        {
          CODE_FILE = ["src/core/job.c"];
          _SELINUX_CONTEXT = ["kernel"];
        }
        {
          MESSAGE_ID = ["fc2e22bc-6ee6-47b6-b907-29ab34a250b1"];
          SYSLOG_IDENTIFIER = ["systemd-coredump"];
        }
        {
          MESSAGE = ["Failed to connect to coredump service: Connection refused"];
          _SELINUX_CONTEXT = ["kernel"];
        }
        {
          MESSAGE = ["src/profile.c:ext_io_disconnected() Unable to get io data for Hands-Free Voice gateway: getpeername: Transport endpoint is not connected (107)"];
          _SELINUX_CONTEXT = ["kernel"];
        }
        {
          MESSAGE = ["Gdm: Failed to contact accountsservice: Error calling StartServiceByName for org.freedesktop.Accounts: Refusing activation, D-Bus is shutting down."];
          _SELINUX_CONTEXT = ["kernel"];
        }
        {
          MESSAGE = ["DMAR: [Firmware Bug]: No firmware reserved region can cover this RMRR [0x000000003e2e0000-0x000000003e2fffff], contact BIOS vendor for fixes"];
          SYSLOG_IDENTIFIER = ["kernel"];
        }
        {
          MESSAGE = ["x86/cpu: SGX disabled by BIOS."];
          SYSLOG_IDENTIFIER = ["kernel"];
        }
        {
          MESSAGE = ["plymouth-quit.service: Service has no ExecStart=, ExecStop=, or SuccessAction=. Refusing."];
          SYSLOG_IDENTIFIER = ["systemd"];
        }
        {
          MESSAGE = ["event10: Failed to call EVIOCSKEYCODE with scan code 0x7c, and key code 190: Invalid argument"];
          _SELINUX_CONTEXT = ["kernel"];
        }
        {
          CODE_FILE = ["../src/modules/module-x11-bell.c"];
          _SELINUX_CONTEXT = ["kernel"];
        }
        {
          MESSAGE = ["gkr-pam: unable to locate daemon control file"];
          _SELINUX_CONTEXT = ["kernel"];
        }
        {
          MESSAGE = ["GLib: Source ID 2 was not found when attempting to remove it"];
          _SELINUX_CONTEXT = ["kernel"];
        }
        {
          MESSAGE = ["GLib-GObject: g_object_unref: assertion ''G_IS_OBJECT (object)'' failed"];
          _SELINUX_CONTEXT = ["kernel"];
        }
        {
          MESSAGE = [''/msg="Reset initiated: SandboxTerminated" func=go.amzn.com/lambda/rapid.handleReset file="/home/runner/work/lambda-runtime-init/lambda-runtime-init/lambda/rapid/handlers.go:710"/''];
        }
      ];

      udev.extraHwdb = ''
        evdev:input:b0003v046DpC548*
          KEYBOARD_KEY_70049=sysrq
      '';

      xserver = {
        videoDrivers = ["amdgpu"];
        xrandrHeads = [
          {
            output = "DP-1";
            primary = true;
          }
          {output = "DP-3";}
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
              name = "backups";
              type = "sink";
              serve = {
                type = "local";
                listener_name = "backups";
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
                "fast/nixos/etc-nixos<" = true;
                "fast/nixos/home<" = true;
                "fast/nixos/home/bakhtiyar/dump<" = false;
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
                "fast/nixos/var<" = true;
                "fast/nixos/home/bakhtiyar/dump<" = true;
              };
              inherit snapshotting;
              pruning = {
                keep = makeGrid "1x1h(keep=all)";
              };
            }
          ];
        };
      };

      wyoming = {
        satellite = {
          enable = true;
          package = pkgs.unstable.pkgs.wyoming-satellite.overridePythonAttrs (oldAttrs: {
            propagatedBuildInputs = [];
          });
          name = "iron";
          area = "Orc room";
          user = "bakhtiyar";
          sounds = {
            awake = /etc/nixos/sounds/awake.wav;
          };
          extraArgs = let
            # OpenRGB HttpHook plugin is configured to set the colors when a GET request is made to localhost:6743/COMMAND, where COMMAND is one of: listen, parse, think, speak, nap.
            effectCommand = {
              event,
              effect,
            }: let
              script =
                pkgs.writers.writeFish "execute-openrgb-effect-hook-${effect}"
                {
                  makeWrapperArgs = [
                    "--prefix"
                    "PATH"
                    ":"
                    "${lib.makeBinPath [pkgs.curl pkgs.fish]}"
                  ];
                }
                ''
                  source ${../scripts/effects.fish}
                  assistant_effect ${effect}
                '';
            in ''--${event}-command=${script}'';
          in
            [
              "--debug"
              "--wake-word-name=duh_meenah"
              "--wake-uri=tcp://localhost:10400"
            ]
            ++ map effectCommand [
              {
                event = "streaming-start";
                effect = "listen";
              }
              {
                event = "stt-stop";
                effect = "parse";
              }
              {
                event = "transcript";
                effect = "think";
              }
              {
                event = "tts-start";
                effect = "speak";
              }
              {
                event = "tts-played";
                effect = "nap";
              }
            ];
        };
      };
    };

    swapDevices = let
      toSwapDevice = diskId: let
        partitionId = toPartitionId diskId 4;
        device = toDevice partitionId;
      in {
        device = "/dev/mapper/decrypted-${partitionId}";
        encrypted = {
          blkDev = device;
          enable = true;
          # Created with `dd count=1 bs=512 if=/dev/urandom of=/etc/nixos/secrets/swap.key`.
          keyFile = "/sysroot/etc/nixos/secrets/swap.key";
          label = "decrypted-${partitionId}";
        };
      };
    in
      map toSwapDevice coreDiskIds;

    # This value determines the NixOS release with which your system is to be
    # compatible, in order to avoid breaking some software such as database
    # servers. You should change this only after NixOS release notes say you
    # should.
    system = {
      stateVersion = "22.11";
      autoUpgrade = {
        dates = "3:40"; # An hour before the default, so that other machines can use this one as a cache.
        flags = [
          "--commit-lock-file"
        ];
      };
    };

    users.users.bakhtiyar.uid = 1000;
  };
}
