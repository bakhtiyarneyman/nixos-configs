# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  config,
  pkgs,
  lib,
  hostName,
  ...
}: let
  atGmail = address: "${address}@gmail.com";
  myEmail = atGmail "bakhtiyarneyman";
  hostEmailFrom = "${hostName} (${myEmail})";
in {
  imports = [
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
      extraModprobeConfig = ''
        options v4l2loopback exclusive_caps=1 video_nr=9 card_label="DroidCam"
      '';
    };

    # i18n = {
    #   inputMethod = {
    #     enabled = "ibus";
    #     ibus.engines = with pkgs.ibus-engines; [ m17n ];
    #   };
    # };

    console = {
      packages = with pkgs; [
        powerline-fonts
      ];
      font = "ter-powerline-v32n";
      colors = [
        "282c34"
        "e06c75"
        "98c379"
        "e5c07b"
        "61afef"
        "c678dd"
        "56b6c2"
        "5c6370"
        "abb2bf"
        "be5046"
        "7a9f60"
        "d19a66"
        "3b84c0"
        "9a52af"
        "3c909b"
        "abb2bf" # Use white for gray.
      ];
    };

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
          "wheel" # Enable ‘sudo’ for the user.
          "docker"
          "networkmanager"
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
        # Utilities
        wget
        neovim
        mkpasswd
        file
        unzip
        eza # Better ls.
        procs # Better ps.
        bat # Better cat.
        bottom # Better top.
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
      inherit hostName;
      networkmanager.enable = true;
      firewall = {
        enable = true;
        logRefusedConnections = true;
        checkReversePath = "loose";
      };
    };

    services = {
      openssh = {
        enable = true;
        settings = {
          AllowAgentForwarding = true;
        };
      };

      gvfs.enable = true;

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
              SYSLOG_IDENTIFIER = ["mount-sensitive-start"];
              MESSAGE = [
                "/[Ee]rror/"
              ];
            }
          ];
        };
      };

      logind.extraConfig = ''
        HandlePowerKey=${
          if builtins.elem "nohibernate" config.boot.kernelParams
          then "suspend"
          else "suspend-then-hibernate"
        }
      '';

      avahi = {
        enable = true;
        # Important to resolve .local domains of printers, otherwise you get an error
        # like  "Impossible to connect to XXX.local: Name or service not known"
        nssmdns4 = false;
        openFirewall = true;
      };

      journald.extraConfig = ''
        SystemMaxUse=50M
      '';

      iperf3.enable = true;
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

      direnv.enable = true;

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

      wireshark.enable = true;
    };

    security.polkit = {
      enable = true;
      adminIdentities = ["unix-user:bakhtiyar"];
    };

    location.provider = "geoclue2";

    virtualisation = {
      docker.enable = true;
    };

    nix = {
      package = pkgs.unstable.nix;
      settings = {
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
          journal-brief = super.callPackage ../pkgs/journal-brief.nix {};
          namespaced-openvpn = super.python3Packages.callPackage ../pkgs/namespaced-openvpn.nix {};
          github-cli = super.unstable.pkgs.github-cli;
        })
      ];
    };

    fonts.packages = with pkgs; [
      powerline-fonts
    ];
  };
}
