# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

let
  # Don't put into /nix/store. Instead use the files in /etc/nixos directly.
  # This makes it easier to test out configuration changes while still
  # managing them centrally.
  unsafeRef = toString;
  prettyLock = import ./prettyLock.nix pkgs;
  idleToDimSecs = 60;
  dimToLockSecs = 10;
  lockToScreenOffSecs = 10;
  dim-screen = pkgs.callPackage ./dim-screen.nix { dimSeconds = dimToLockSecs; };
in {
  imports = [
    ./modules/i3status-rust.nix
    ./modules/dunst.nix
  ];

  boot = {
    tmpOnTmpfs = true;
    kernelPackages = pkgs.linuxPackages_latest;
    # Use the systemd-boot EFI boot loader.
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  # Select internationalisation properties.
  # i18n = {
  #   consoleFont = "Lat2-Terminus16";
  #   consoleKeyMap = "us";
  #   defaultLocale = "en_US.UTF-8";
  # };

  # This workaround is necessary even if service.localtime is enabled.
  time.timeZone = "America/Los_Angeles";

  # Don't forget to set a password with ‘passwd’.
  users = {
    mutableUsers = false;
    defaultUserShell = pkgs.fish;
    users.bakhtiyar = {
      description = "Bakhtiyar Neyman";
      isNormalUser = true;
      extraGroups = [
          "wheel" # Enable ‘sudo’ for the user.
          "adbusers"
          "video" # Allow changing brightness via `light`.
      ];
      hashedPassword = "$6$.9aOljbRDW00nl$vRfj6ZVwgWXLTw2Ti/I55ov9nNl6iQAqAuauCiVhoRWIv5txKFIb49FKY0X3dgVqE61rPOqBh8qQSk61P2lZI1";
    };
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # System.
    ntfs3g
    google-drive-ocamlfuse
    parted
    gparted
    # Utilities.
    wget
    neovim
    mkpasswd
    file
    xorg.xdpyinfo
    # UI.
    (callPackage <nixpkgs/pkgs/applications/misc/termite/wrapper.nix> {
       termite = termite-unwrapped;
       configFile = unsafeRef ./termite.conf;
    })
    prettyLock
    rofi
    pavucontrol # Pulse audio volume control.
    libnotify # Notification service API.
    clipmenu # Clipboard manager.
    xmobar
    # Browsers.
    google-chrome
    firefox
    (tor-browser-bundle-bin.override {
       mediaSupport = true;
       pulseaudioSupport = true;
    })
    # Shell packages.
    fish
    fzf
    # Communication.
    skype
    # Development.
    git
    (callPackage ./pkgs/vscode.nix {})
    atom
    cachix
    meld
  ];

  networking = {
    networkmanager.enable = true;
    firewall = {
      allowedTCPPorts = [
        # SSH.
        22
        # Chromecast ports.
        8008 8009
      ];
      allowedUDPPortRanges = [
        # Chromecast ports.
        { from = 32768; to = 60999; }
      ];
    };
  };

  sound = {
    enable = true;
    mediaKeys = {
      enable = true;
      volumeStep = "1%";
    };
  };

  hardware = {
    bluetooth.enable = true;
    pulseaudio = {
      enable = true;
      package = pkgs.pulseaudioFull; # For bluetooth headphones
    };
  };

  services = {

    # Enable the X11 windowing system.
    xserver = {
      enable = true;

      # Keyboard.
      layout = "us,ru,az";
      xkbOptions = "grp:alt_shift_toggle";

      inputClassSections = [ 
        ''
          Identifier      "mouse"
          MatchIsPointer  "on"
          Option          "NaturalScrolling"      "true"
        ''
      ];

      # Enable touchpad support.
      libinput = {
        enable = true;
        naturalScrolling = true;
      };

      displayManager = {
        # 1. Set wallpaper.
        # 2. Don't lock the screen by itself.
        # 3. Turn off the screen after time of inactivity. This triggers a screen lock
        sessionCommands =
          with builtins;
          let screenOffTime = toString
                (idleToDimSecs + dimToLockSecs + lockToScreenOffSecs);
          in ''
            ${pkgs.feh}/bin/feh --bg-fill ${./wallpaper.jpg}
            ${pkgs.xorg.xset}/bin/xset s ${toString idleToDimSecs} ${toString dimToLockSecs}
            ${pkgs.xorg.xset}/bin/xset dpms ${screenOffTime} ${screenOffTime} ${screenOffTime}
          '';
        lightdm = {
          enable = true;
          # Autologin is only safe because the disk is encrypted.
          # It can lead to an infinite loop if the window manager crashes.
          autoLogin = {
            enable = true;
            user = "bakhtiyar";
          };
          background = unsafeRef ./wallpaper.jpg;
        };
      };

      windowManager = {
        i3 = {
          enable = true;
          configFile = unsafeRef ./i3.conf;
          package = pkgs.i3-gaps;
          extraPackages = with pkgs; [
            rofi # dmenu alternative.
            upower # Charging state.
            lm_sensors # Temperature.
            xkblayout-state # Keyboard layout (a hack).
          ];
        };
        xmonad = {
          enable = true;
          enableContribAndExtras = true;
          extraPackages = with pkgs; haskellPackages: [
            haskellPackages.xmonad-contrib
            haskellPackages.xmonad-extras
            haskellPackages.xmonad
          ];
        };
        default = "i3";
      };

      desktopManager.default = "none";
    };

    compton = {
      enable = true;
      fade = true;
      fadeSteps = ["0.1" "0.1"];
      shadow = true;
      inactiveOpacity = "0.6";
      settings = {
        # This is needed for i3lock. Opacity rule doesn't work because there is no window id.
        mark-ovredir-focused = true;
      };
    };

    # Notification service.
    dunst = {
      enable = true;
      globalConfig = {
        monitor = "0";
        follow = "keyboard";
        geometry = "300x5-30+20";
        indicate_hidden = "yes";
        shrink = "true";
        transparency = "40";
        notification_height = "0";
        separator_height = "3";
        padding = "8";
        horizontal_padding = "8";
        frame_width = "0";
        frame_color = ''"#aaaaaa"'';
        separator_color = "auto";
        sort = "yes";
        idle_threshold = "120";
        font = "Ubuntu 12";
        line_height = "0";
        markup = "full";
        format = ''"<b>%s</b>\n%b"'';
        alignment = "center";
        show_age_threshold = "60";
        word_wrap = "yes";
        ellipsize = "middle";
        ignore_newline = "no";
        stack_duplicates = "true";
        hide_duplicate_count = "false";
        show_indicators = "yes";
        icon_position = "left";
        max_icon_size = "32";
        sticky_history = "yes";
        history_length = "100";
        dmenu = "${pkgs.dmenu}/bin/dmenu -p dunst:";
        browser = "${pkgs.google-chrome}/bin/google-chrome-stable -new-tab";
        always_run_script = "true";
        title = "Dunst";
        class = "Dunst";
        verbosity = "mesg";
        corner_radius = "10";
        force_xinerama = "false";
        mouse_left_click = "do_action";
        mouse_middle_click = "close_all";
        mouse_right_click = "close_current";
      };
      experimentalConfig = {
        per_monitor_dpi = "true";
      };
      shortcutsConfig = {
        close = "mod4+BackSpace";
        history = "mod4+shift+BackSpace";
        context = "mod4+period";
      };
      urgencyConfig = let q = s: ''"${s}"''; in {
        low = {
          background = q "#203040";
          foreground = q "#909090";
          timeout = "10";
        };
        normal = {
          background = q "#203040";
          foreground = q "#FFFFFF";
          timeout = "30";
        };
        critical = {
          background = q "#900000";
          foreground = q "#ffffff";
          timeout = "0";
        };
      };
      iconDirs =
        let icons = "${pkgs.gnome3.adwaita-icon-theme}/share/icons/Adwaita";
        in [ "${icons}/48x48" "${icons}/scalable" ];
    };

    gnome3.chrome-gnome-shell.enable = true;

    geoclue2.enable = true;

    localtime.enable = true;

    redshift.enable = true;

    actkbd = {
      enable = true;
      bindings =
        let
          light = "${pkgs.light}/bin/light";
          mkBinding = keys: events: command: { inherit keys events command; };
        in [
          (mkBinding [ 224 ] [ "key" "rep" ] "${light} -U 1")
          (mkBinding [ 225 ] [ "key" "rep" ] "${light} -A 1")
        ];
    };

    blueman.enable = true; # Bluetooth applet.
    openssh.enable = true;
    printing.enable = true;
    tlp.enable = true; # For battery conservation. Powertop disables wired mice.

    journald.extraConfig = ''
      SystemMaxUse=50M
    '';
  };

  programs = {
    fish = {
      enable = true;
      interactiveShellInit =
        with pkgs;
        let sourcePluginLoader = p:
              "source ${callPackage (./. + "/pkgs/fish/${p}.nix") {}}/loadPlugin.fish";
        in lib.strings.concatMapStringsSep "\n" sourcePluginLoader [
          "fzf" "themeAgnoster" "done" "humanizeDuration" "z" "getOpts"
        ] + ''

          function fish_user_key_bindings
            bind \cs 'exec fish'
          end

        '';
    };

    i3status-rust.enable = true;
    sway.enable = true;
    light.enable = true; # Brightness management.
    nm-applet.enable = true; # Wi-fi management.
    xss-lock = { # Lock on lid action.
      enable = true;
      extraOptions = ["--notifier=${dim-screen}/bin/dim-screen"];
      lockerCommand = "${prettyLock}/bin/prettyLock";
    };
    adb.enable = true;
  };

  # Allow elevating privileges dynamically via `pkexec`.
  # This doesn't currently help with `vscode` because `sudo-prompt` package is not working right.
  security.polkit = {
    enable = true;
    adminIdentities = [ "unix-user:bakhtiyar" ];
  };

  location.provider = "geoclue2";

  systemd.user.services.blueman = {
    enable = true;
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig.ExecStart = [
      "${pkgs.blueman}/bin/blueman-applet"
    ];
  };

  virtualisation.libvirtd.enable = true;

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system = {
    stateVersion = "19.03"; # Did you read the comment?
    autoUpgrade.enable = true;
  };

  nixpkgs.config = {
    allowUnfree = true;
    android_sdk.accept_license = true;
  };

  nix = {
    trustedUsers = [ "root" "bakhtiyar" ];
    gc = {
      automatic = true;
      options = "--delete-older-than 14d";
    };
  };

  fonts = {
    enableFontDir = true;
    enableGhostscriptFonts = true;
    fonts = with pkgs; [
      anonymousPro
      corefonts
      dejavu_fonts
      font-awesome_4
      font-awesome_5
      freefont_ttf
      google-fonts
      inconsolata
      liberation_ttf
      powerline-fonts
      source-code-pro
      terminus_font
      ttf_bitstream_vera
      ubuntu_font_family
    ];
  };

}
