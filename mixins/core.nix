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
        shell-genie
        # Shell packages
        fish
        peco
        # Hardware
        psmisc
        pciutils
        glxinfo
        inxi
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
              MESSAGE = [ "/Bluetooth: hci0: .*/" ];
              SYSLOG_IDENTIFIER = [ "kernel" ];
            }
            {
              SYSLOG_IDENTIFIER = [ "bluetoothd" ];
            }
            {
              SYSLOG_IDENTIFIER = [ "pipewire" ];
              MESSAGE = [
                "/pw.node: (bluez_output.*) .* -> error (Received error event)/"
              ];
            }
          ];
          inclusions = [
            {
              PRIORITY = [ "0" "1" "2" "3" ];
              SYSLOG_IDENTIFIER = [ "sshd" ];
              MESSAGE = [ "/Starting session: shell.*/" ];
            }
            {
              PRIORITY = [ "0" "1" "2" "3" ];
              SYSLOG_IDENTIFIER = [ "mount-sensitive-start" ];
              MESSAGE = [
                "/[Ee]rror/"
              ];
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
        nssmdns = false;
        openFirewall = true;
      };

      journald.extraConfig = ''
        SystemMaxUse=50M
      '';

    };

    system = {
      # settings from avahi-daemon.nix where mdns is replaced with mdns4
      nssModules = pkgs.lib.optional (!config.services.avahi.nssmdns) pkgs.nssmdns;
      nssDatabases.hosts = with pkgs.lib; optionals (!config.services.avahi.nssmdns) (mkMerge [
        (mkBefore [ "mdns4_minimal [NOTFOUND=return]" ]) # before resolve
        (mkAfter [ "mdns4" ]) # after dns
      ]);
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
            set -g glyph_status_nonzero 💀
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
            ${pkgs.eza}/bin/eza -l --icons --color=always | ${pkgs.bat}/bin/bat -
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

          function rename_gopro_files

            argparse --max-args=0 "confirm" "help" -- $argv

            if test $_flag_help
              echo "Usage: rename_gopro_files [--confirm]"
              echo "  --confirm          Actually rename files"
              return 0
            end

            # Loop through each MP4 file
            for old in (find -maxdepth 1 -type f -iname '*.mp4' | sort --numeric-sort)
              # Extract the filename without extension
              set filename (basename --suffix=.mp4 $old)

              # Extract relevant parts from the filename
              set gopro_marker (string sub --start=1 --length=1 $filename)
              set encoding (string sub --start=2 --length=1 $filename)
              set chapter_number (string sub --start=3 --length=2 $filename)
              set file_number (string sub --start=5 --length=4 $filename)
              set suffix (string sub --start=9 $filename)

              echo "gopro_marker=$gopro_marker"
              echo "encoding=$encoding"
              echo "chapter_number=$chapter_number"
              echo "file_number=$file_number"

              # Verify that the filename is in the format G%encoding%%chapter_number%%file_number%.MP4
              #   1. G is a literal character
              #   2. encoding is either 'H' or 'X'
              #   3. chapter_number is a two-digit number
              #   4. file_number is a four-digit number

              if test $gopro_marker != "G"
                echo "$filename doesn't start with G: $gopro_marker"
                return 1
              end

              if test $encoding != "H" -a $encoding != "X"
                echo "encoding of $filename doesn't have encoding H or X: $encoding"
                return 1
              end

              if test $chapter_number -lt 1 -o $chapter_number -gt 99
                echo "chapter_number of $filename isn't between 1 and 99: $chapter_number"
                return 1
              end

              if test $file_number -lt 1 -o $file_number -gt 9999
                echo "file_number of $filename isn't between 1 and 9999: $file_number"
                return 1
              end

              if test -n $suffix
                echo "$filename doesn't end with .MP4: $suffix"
                return 1
              end

              # Create the new filename
              set new "$file_number.$chapter_number.mp4"

              if test $_flag_confirm
                echo "Renaming $old to $new"
                # mv $old $new; or return 1
              else
                echo Would have renamed $old to $new
              end
            end
          end

          function recode
              set --local options (fish_opt --long-only --short h --long help)
              set options $options (fish_opt --optional-val --long-only --short n --long noise)
              set options $options (fish_opt --optional-val --long-only --short g --long max-keyframe-gap)
              set options $options (fish_opt --optional-val --long-only --short s --long speed )
              set options $options (fish_opt --required-val --long-only --short i --long input-file)
              set options $options (fish_opt --required-val --long-only --short o --long output-dir)

              set --local crf 32
              set --local preset 4
              set --local g 300

              argparse --name="recode" --ignore-unknown $options -- $argv
              or return

              if test -n "$_flag_help"
                  echo "Recode video files using ffmpeg/libsvtav1"
                  echo "Usage:"
                  echo "  recode --help"
                  echo "  recode [--noise <noise>] [--max-keyframe-gap <max-keyframe-gap>] [--speed <speed>] --input-file <input-file> --output-dir <output-dir>"
                  echo "Options:"
                  echo " -h, --help: show this help"
                  echo " -n, --noise: noise level (-crf in libsvtav1). Default: $crf"
                  echo " -g, --max-keyframe-gap: max keyframe gap (-g in libsvtav1). Default: $g"
                  echo " -s, --speed: speed (-preset in libsvtav1). Default: $preset"
                  echo " -i, --input-file: input file"
                  echo " -o, --output-dir: output directory"
                  return 0
              end

              if test -n "$_flag_noise"
                  set crf $_flag_noise
              end

              if test -n "$_flag_max_keyframe_gap"
                  set g $_flag_max_keyframe_gap
              end

              if test -n "$_flag_speed"
                  set preset $_flag_speed
              end


              set --local file $_flag_input_file
              set --local output_dir $_flag_output_dir
              set --local base (path basename $file)

              set --local temp_target $output_dir/(path change-extension crf=$crf.preset=$preset.g=$g.unfinished.mkv $base)
              set --local target (path change-extension mkv (path change-extension "" $temp_target))

              if test -e "$target"
                  set_color green
                  echo "'$target' already exists."
                  return 0
              end

              set_color yellow
              echo "Recoding '$file' as '$target'..."
              set_color normal

              ffmpeg \
                  -i $file \
                  -c:v libsvtav1 \
                  -preset $preset \
                  -crf $crf \
                  -g $g \
                  -svtav1-params tune=0 \
                  -c:a copy \
                  -y \
                  $argv \
                  $temp_target
              or return 1

              mv $temp_target $target
          end

            # Should not be necessary once fish 3.6.2 is released.
          function __fish_is_zfs_feature_enabled -a feature target -d "Returns 0 if the given ZFS feature is available or enabled for the given full-path target (zpool or dataset), or any target if none given"
              type -q zpool
              or return
              set -l pool (string replace -r '/.*' "" -- $target)
              set -l feature_name ""
              if test -z "$pool"
                  set feature_name (zpool get -H all 2>/dev/null | string match -r "\s$feature\s")
              else
                  set feature_name (zpool get -H all $pool 2>/dev/null | string match -r "$pool\s$feature\s")
              end
              if test $status -ne 0 # No such feature
                  return 1
              end
              set -l state (echo $feature_name | cut -f3)
              string match -qr '(active|enabled)' -- $state
              return $status
          end
        '';
      };

      direnv.enable = true;

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
          credential = {
            "https://github.com/neurasium".username = "neurasium";
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

      wireshark.enable = true;
    };

    security.polkit = {
      enable = true;
      adminIdentities = [ "unix-user:bakhtiyar" ];
    };

    location.provider = "geoclue2";

    virtualisation = {
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
          journal-brief = super.callPackage ../pkgs/journal-brief.nix { };
          namespaced-openvpn = super.python3Packages.callPackage ../pkgs/namespaced-openvpn.nix { };
        })
      ];
    };

    fonts.packages = with pkgs; [
      powerline-fonts
    ];

  };
}
