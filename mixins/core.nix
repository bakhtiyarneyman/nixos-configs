# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  config,
  pkgs,
  lib,
  machineName,
  machines,
  ...
}: let
  atGmail = address: "${address}@gmail.com";
  myEmail = atGmail "bakhtiyarneyman";
  hostEmailFrom = "${machineName} (${myEmail})";
in {
  imports = [
    ../modules/auto-unlock.nix
    ../modules/journal-brief.nix
  ];

  config = {
    boot = {
      tmp.useTmpfs = true;
      kernel.sysctl."kernel.sysrq" = 1;
      # Use the systemd-boot EFI boot loader.
      loader = {
        efi.canTouchEfiVariables = true;
      };
    };

    # i18n = {
    #   inputMethod = {
    #     enabled = "ibus";
    #     ibus.engines = with pkgs.ibus-engines; [ m17n ];
    #   };
    # };

    # This workaround is necessary even if service.localtime is enabled.
    time.timeZone = "America/Los_Angeles";

    users = {
      mutableUsers = false;
      defaultUserShell = pkgs.fish;
      users.bakhtiyar = {
        description = "Bakhtiyar Neyman";
        homeMode = "701";
        isNormalUser = true;
        extraGroups = [
          "networkmanager"
          "wheel" # Enable ‘sudo’ for the user.
          "wireshark"
        ];
      };
    };
    environment = {
      systemPackages = with pkgs; [
        # System
        ntfs3g
        google-drive-ocamlfuse
        parted
        smem
        # Utilities
        wget
        lnav
        mkpasswd
        file
        unzip
        eza # Better ls.
        procs # Better ps.
        bat # Better cat.
        bottom # Better top.
        htop # Better top.
        fd # Better find.
        du-dust # Better du.
        sd # Better sed.
        xcp # Better cp.
        nethogs
        nmap
        lsof
        iperf3
        shell-genie
        github-cli
        ngrok
        jq
        config.boot.kernelPackages.perf
        # Nix
        # nixd
        nil
        alejandra
        # Shell packages
        fish
        peco
        # Hardware
        dmidecode
        fio # Disk benchmarking.
        glxinfo # OpenGL information.
        inxi # System information.
        pciutils # lspci
        psmisc
        usbutils # lsusb
        # Privacy
        namespaced-openvpn
        cryfs
      ];

      etc = {
        "aliases" = {
          text = ''
            root: ${myEmail}
          '';
          mode = "0644";
        };
        "avahi/services/unused".text = "";
      };
      sessionVariables = {
        CARGO_HOME = "/var/cache/cargo";
        npm_config_cache = "/var/cache/npm";
        STACK_ROOT = "/var/cache/stack";
      };
    };

    networking = {
      hostName = machineName;
      firewall = {
        enable = true;
        logRefusedConnections = true;
        checkReversePath = "loose";
      };
    };

    services = {
      avahi = {
        enable = true;
        # Important to resolve .local domains of printers, otherwise you get an error
        # like  "Impossible to connect to XXX.local: Name or service not known"
        nssmdns4 = false;
        openFirewall = true;
      };

      gvfs.enable = true;

      iperf3.enable = true;

      journal-brief = {
        enable = true;
        settings = {
          priority = "err";
          email = {
            from = hostEmailFrom;
            to = atGmail "bakhtiyarneyman+journal-brief";
            command = ''
              (cat <(echo "Subject: Journal brief") -) | ${pkgs.msmtp}/bin/msmtp -t
            '';
          };
          exclusions = [
            {
              MESSAGE = ["/Bluetooth: hci0: .*/"];
              SYSLOG_IDENTIFIER = ["kernel"];
            }
            {
              SYSLOG_IDENTIFIER = ["bluetoothd"];
            }
            {
              SYSLOG_IDENTIFIER = ["pipewire"];
              MESSAGE = [
                "/pw.node: (bluez_output.*) .* -> error (Received error event)/"
              ];
            }
            {
              SYSLOG_IDENTIFIER = ["pipewire"];
              MESSAGE = [
                "pipewire-pulse[12823]: mod.protocol-pulse: server 0x55b5e001ba20: failed to create client: Connection refused"
              ];
            }
            {
              SYSLOG_IDENTIFIER = ["dbus-broker-launch"];
              MESSAGE = [
                "/Ignoring duplicate name/"
              ];
            }
          ];
          inclusions = [
            {
              PRIORITY = ["0" "1" "2" "3"];
              SYSLOG_IDENTIFIER = ["sshd"];
              MESSAGE = ["/Starting session: shell.*/"];
            }
            {
              PRIORITY = ["0" "1" "2" "3"];
              SYSLOG_IDENTIFIER = ["hass"];
              MESSAGE = [
                "/ModuleNotFoundError:/"
              ];
            }
          ];
        };
      };

      journald.extraConfig = ''
        SystemMaxUse=512M
      '';

      ntopng = {
        enable = true;
        httpPort = 4256;
      };

      nfs.server.importers = ["iron" "mercury"];

      openssh = {
        enable = true;
        settings = {
          AllowAgentForwarding = true;
        };
      };

      vscode-server.enable = true;
    };

    system = {
      # settings from avahi-daemon.nix where mdns is replaced with mdns4
      nssModules = pkgs.lib.optional (!config.services.avahi.nssmdns4) pkgs.nssmdns;
      nssDatabases.hosts = with pkgs.lib;
        optionals (!config.services.avahi.nssmdns4) (mkMerge [
          (mkBefore ["mdns4_minimal [NOTFOUND=return]"]) # before resolve
          (mkAfter ["mdns4"]) # after dns
        ]);
    };

    # Workaround for nm-online issues.
    # See: https://github.com/NixOS/nixpkgs/issues/180175
    systemd.services.NetworkManager-wait-online = {
      serviceConfig = {
        ExecStart = ["" "${pkgs.networkmanager}/bin/nm-online -q"];
      };
    };

    programs = {
      direnv.enable = true;

      fish = {
        enable = true;
        interactiveShellInit = with pkgs; let
          sourcePluginLoader = p: "source ${callPackage (../. + "/pkgs/fish/${p}.nix") {}}/loadPlugin.fish";
        in
          ''
            set -g color_status_nonzero_bg brred
            set -g color_status_nonzero_str white
            set -g glyph_status_nonzero 💀
          ''
          + lib.strings.concatMapStringsSep "\n" sourcePluginLoader [
            "peco"
            "themeAgnoster"
            "done"
            "humantime"
            "z"
            "getOpts"
          ]
          + ''

            source ${../scripts/init.fish}
          '';
      };

      git = {
        enable = true;
        config = {
          user = {
            email = myEmail;
            name = "Bakhtiyar Neyman";
          };
          alias = {
            plog = "log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(bold yellow)%d%C(reset)' --all";
          };
          credential = {
            "https://github.com/".username = "bakhtiyarneyman";
            "https://github.com/neurasium".username = "neurasium";
          };
          http.version = "HTTP/2";
          safe.directory = "/etc/nixos";
        };
        lfs.enable = true;
        package = pkgs.gitFull;
      };

      msmtp = {
        enable = true;
        setSendmail = true;
        defaults = {
          aliases = "/etc/aliases";
          port = 465;
          tls_trust_file = "/etc/ssl/certs/ca-certificates.crt";
          tls = "on";
          auth = "login";
          tls_starttls = "off";
        };
        accounts = {
          default = {
            host = "smtp.gmail.com";
            user = "bakhtiyarneyman";
            passwordeval = "${pkgs.coreutils-full}/bin/cat /etc/nixos/secrets/smtp.passphrase";
            from = hostEmailFrom;
          };
        };
      };

      nix-ld = {
        enable = true;
        package = pkgs.nix-ld-rs;
      };

      neovim = {
        enable = true;
        defaultEditor = true;
        viAlias = true;
      };

      ssh = {
        knownHosts = {
          iron = {
            hostNames = ["iron-tailscale"];
            publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOeAfprNGrQ2RfrDT81UxfTD/GfnOwz8gPzGppNiTw40";
          };
          iron-initrd = {
            hostNames = ["iron-initrd"];
            publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJZsOTJo1rw8XwP0ErdkXlRnGY5A6C7NtO93IXht2lNT";
          };
          mercury = {
            hostNames = ["mercury-tailscale"];
            publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKSyMQogWih9Tk8cpckwxP6CLzJxZqtg+qdFbXYbF9Sc";
          };
          tin.publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHYdHpGj0w2iRMKgyDSmJuk7oEJHQHWMOavKMyrB/uQB";
          tungsten = {
            hostNames = ["bakhtiyar.zfs.rent"];
            publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFWtgyWNQ//nFGPEwdsUizf08UOL+EtFnergd2HgAkqy";
          };
        };
        extraConfig = let
          toHost = host: _config: ''
            Host ${host} ${host}.orkhon-mohs.ts.net
              HostName ${host}
              ForwardAgent yes
          '';
        in
          builtins.concatStringsSep "\n" (builtins.attrValues (builtins.mapAttrs toHost machines));
      };

      wireshark.enable = true;
    };

    security = {
      doas.enable = true;
      polkit = {
        enable = true;
        adminIdentities = ["unix-user:bakhtiyar"];
      };
    };

    location.provider = "geoclue2";

    nix = {
      package = pkgs.unstable.nix;
      settings = {
        trusted-public-keys = [
          "iron:OaC7pyOu4UcI9Fgp4Go1d5Qo2dChSjr0bTuCJqfgirc="
          "tin:1xuVbjflY1Z/kH6uEaeNivgLHYvORLli3r//baX6N78="
        ];
        trusted-users = ["root" "bakhtiyar"];
      };
      gc = {
        automatic = true;
        options = "--delete-older-than 14d";
      };
      extraOptions = ''
        experimental-features = nix-command flakes
      '';
    };

    nixpkgs = {
      config = {
        allowUnfree = true;
      };
      overlays = [
        (self: super: {
          # This is only needed on tin, but we build it on iron, so that it gets picked up from cache.
          jellyfin-ffmpeg = super.callPackage ../pkgs/jellyfin-ffmpeg-with-vpl.nix {};
          journal-brief = self.python3Packages.callPackage ../pkgs/journal-brief.nix {};
          github-cli = super.unstable.pkgs.github-cli;
          home-assistant = super.unstable.home-assistant;
          namespaced-openvpn = super.callPackage ../pkgs/namespaced-openvpn.nix {};
          wyoming-openwakeword = self.unstable.wyoming-openwakeword;
          wyoming-faster-whisper = super.unstable.wyoming-faster-whisper;
          wyoming-piper = self.unstable.wyoming-piper;
        })
      ];
    };

    fonts.packages = with pkgs; [
      powerline-fonts
    ];
  };
}
