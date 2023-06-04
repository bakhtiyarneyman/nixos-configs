# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, hostName, ... }:

let
  atGmail = address: "${address}@gmail.com";
  myEmail = atGmail "bakhtiyarneyman";
  hostEmailFrom = "${hostName} (${myEmail})";
in
{

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
      kernelModules = [ "kvm-intel" ];
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
        exa # Better ls.
        procs # Better ps.
        bat # Better cat.
        bottom # Better top.
        fd # Better find.
        du-dust # Better du.
        sd # Better sed.
        xcp # Better cp.
        # Shell packages
        fish
        peco
        # Hardware
        psmisc
        pciutils
        glxinfo
        inxi
        # Nix
        direnv
        nix-direnv
        # Privacy
        namespaced-openvpn
        cryfs
      ];

      pathsToLink = [
        "/share/nix-direnv"
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

    hardware = {
      enableRedistributableFirmware = true;
      logitech.wireless.enable = true;
    };

    services = {
      openssh = {
        enable = true;
        settings = {
          AllowAgentForwarding = true;
        };
      };

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
              MESSAGE = [ "Bluetooth: hci0: link tx timeout" ];
              SYSLOG_IDENTIFIER = [ "kernel" ];
            }
            {
              SYSLOG_IDENTIFIER = [ "bluetoothd" ];
            }
          ];
        };
      };

      logind.extraConfig = ''
        HandlePowerKey=suspend
      '';

      avahi = {
        enable = true;
        # Important to resolve .local domains of printers, otherwise you get an error
        # like  "Impossible to connect to XXX.local: Name or service not known"
        nssmdns = true;
        openFirewall = true;
      };

      tlp.enable = true; # For battery conservation. Powertop disables wired mice.

      journald.extraConfig = ''
        SystemMaxUse=50M
      '';

      fwupd.enable = true;

      smartd = {
        enable = true;
        extraOptions = [
          "-A /var/log/smartd/"
          "--interval=3600"
        ];
      };

    };

    programs = {

      fish = {
        enable = true;
        interactiveShellInit =
          with pkgs;
          let
            sourcePluginLoader = p:
              "source ${callPackage (../. + "/pkgs/fish/${p}.nix") {}}/loadPlugin.fish";
          in
          ''
            set -g color_status_nonzero_bg brred
            set -g color_status_nonzero_str white
            set -g color_status_nonzero_indicator 💀
          '' + lib.strings.concatMapStringsSep "\n" sourcePluginLoader [
            "peco"
            "themeAgnoster"
            "done"
            "humantime"
            "z"
            "getOpts"
          ] + ''

          function fish_user_key_bindings
            bind \cs 'exec fish'
            bind \cr 'peco_select_history (commandline -b)'
          end

          function list
            ${pkgs.exa}/bin/exa -l --icons --color=always | ${pkgs.bat}/bin/bat -
          end

          function goin -w cd
            cd $argv; and list
          end

          function goto -w z
            z $argv; and list
          end

          alias nix-shell-fish 'nix-shell --run fish'

          function bluetoothctl
              command bluetoothctl devices Paired; and command bluetoothctl
          end

          function delete_old_snapshots
            argparse --max-args=1 "older-than=?" "confirm" "help" -- $argv

            if test $_flag_help
              echo "Usage: delete_old_snapshots --older-than=DATE [--confirm] [FILESYSTEM]"
              echo "  --older-than=DATE  Delete snapshots older than this date, e.g. '05/14/2023 00:00:00+07'"
              echo "  --confirm            Actually delete snapshots"
              echo "  FILESYSTEM         The pool or dataset to delete snapshots from"
              return 0
            end


            if test $_flag_older_than
              set threshold (date -d $_flag_older_than +%s)
            else
              echo "You must specify --older-than"
              return 1
            end

            zfs list -H -o name,creation -t snapshot $argv | while read -s line;set name (echo $line | cut -f1)
              set date (echo $line | cut -f2- -d' ' | date -f - +%s)

              if test $date -lt $threshold
                if test $_flag_confirm
                  echo Deleting $name
                  sudo zfs destroy $name; or return 1
                else
                  echo Would have deleted $name
                end
              end
            end
          end

          direnv hook fish | source
        '';
      };


      git = {
        enable = true;
        package = pkgs.gitFull;
        config = {
          user = {
            email = myEmail;
            name = "Bakhtiyar Neyman";
          };
          alias = {
            plog = "log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(bold yellow)%d%C(reset)' --all";
          };
        };
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

    };

    security.polkit = {
      enable = true;
      adminIdentities = [ "unix-user:bakhtiyar" ];
    };

    location.provider = "geoclue2";

    virtualisation = {
      libvirtd.enable = true;
      docker.enable = true;
    };

    nix = {
      package = pkgs.unstable.nix;
      settings = {
        trusted-users = [ "root" "bakhtiyar" ];
        max-jobs = lib.mkDefault 8;
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
          nix-direnv = super.nix-direnv.override { enableFlakes = true; };
          journal-brief = super.callPackage ../pkgs/journal-brief.nix { };
          namespaced-openvpn = super.python3Packages.callPackage ../pkgs/namespaced-openvpn.nix { };
        })
      ];
    };

    fonts.fonts = with pkgs; [
      powerline-fonts
    ];

  };
}
