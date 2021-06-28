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
  dimToLockSecs = 15;
  lockToScreenOffSecs = 10;
  dim-screen = pkgs.callPackage ./dim-screen.nix { dimSeconds = dimToLockSecs; };
in {
  imports = [
    ./modules/i3status-rust.nix
    ./modules/dunst.nix
  ];

  boot = {
    tmpOnTmpfs = true;
    kernel.sysctl = {
      "kernel.sysrq" = 1;
    };
    # Use the systemd-boot EFI boot loader.
    loader = {
      systemd-boot.enable = true;
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
    # packages =  with pkgs; [
    #   anonymousPro
    #   corefonts
    #   dejavu_fonts
    #   fira-code
    #   font-awesome_4
    #   font-awesome_5
    #   freefont_ttf
    #   google-fonts
    #   inconsolata
    #   liberation_ttf
    #   powerline-fonts
    #   source-code-pro
    #   terminus_font
    #   ttf_bitstream_vera
    #   ubuntu_font_family
    # ];
    # font = "Inconsolata for Powerline:style=Medium";
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
          "networkmanager"
      ];
      hashedPassword = "$6$.9aOljbRDW00nl$vRfj6ZVwgWXLTw2Ti/I55ov9nNl6iQAqAuauCiVhoRWIv5txKFIb49FKY0X3dgVqE61rPOqBh8qQSk61P2lZI1";
    };
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment = {
    systemPackages = with pkgs; [
      # System.
      ntfs3g
      google-drive-ocamlfuse
      parted
      gparted
      # Utilities.
      wget
      neovim
      mkpasswd
      libsecret # For gnome-keyring.
      file
      xorg.xdpyinfo
      udiskie # USB disk automounting.
      unzip
      exa # Better ls.
      procs # Better ps.
      bat # Better cat.
      bottom # Better top.
      fd # Better find.
      du-dust # Better du.
      sd # Better sed.
      # UI.
      alacritty
      prettyLock
      rofi
      pavucontrol # Pulse audio volume control.
      libnotify # Notification service API.
      clipmenu # Clipboard manager.
      xmobar
      krusader
      breeze-icons
      # Hardware.
      psmisc
      pciutils
      glxinfo
      inxi
      # Browsers.
      (google-chrome.override { commandLineArgs = "--enable-features=VaapiVideoDecoder"; })
      firefox
      # Shell packages.
      fish
      peco
      # Communication.
      skype
      signal-desktop
      tdesktop # Telegram.
      zoom-us
      # Development.
      git
      (callPackage ./pkgs/vscode.nix {})
      atom
      cachix
      meld
      python3
      # Image.
      gimp
      # Audio.
      audacity
      # Video.
      vlc
      guvcview
      shotcut
      obs-studio
      # Privacy
      monero-gui
      (tor-browser-bundle-bin.override {
        mediaSupport = true;
        pulseaudioSupport = true;
      })
    ];
    etc."xdg/mimeapps.list" = {
      text = ''
        [Default Applications]
        video/mp4=vlc.desktop;
      '';
    };
  };

  networking = {
    networkmanager.enable = true;
    firewall = {
      enable = true;
      logRefusedConnections = true;
      allowedTCPPorts = [
        # SSH.
        22
        # Chromecast ports.
        8008 8009 8010 8443
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
  nixpkgs.config.packageOverrides = pkgs: {
    vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
  };

  hardware = {
    bluetooth.enable = true;
    pulseaudio = {
      enable = true;
      package = pkgs.pulseaudioFull; # For bluetooth headphones
    };
    opengl = {
      enable = true;
      driSupport32Bit = true;
      extraPackages = with pkgs; [
        intel-media-driver # LIBVA_DRIVER_NAME=iHD
        vaapiIntel         # LIBVA_DRIVER_NAME=i965 (older but works better for Firefox/Chromium)
        vaapiVdpau
        libvdpau-va-gl
      ];
    };
    video.hidpi.enable = true;
  };

  services = {

    # Enable the X11 windowing system.
    xserver = {
      enable = true;

      # Keyboard.
      layout = "us,ru,az";
      xkbOptions = "grp:alt_shift_toggle";

      # Enable touchpad support.
      libinput = {
        enable = true;
        touchpad.naturalScrolling = true;
        mouse.naturalScrolling = true;
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
            ${pkgs.xorg.xset}/bin/xset s ${toString idleToDimSecs} ${toString (dimToLockSecs + 5)}
            ${pkgs.xorg.xset}/bin/xset dpms ${screenOffTime} ${screenOffTime} ${screenOffTime}
          '';
        # Autologin is only safe because the disk is encrypted.
        # It can lead to an infinite loop if the window manager crashes.
        autoLogin = {
          enable = true;
          user = "bakhtiyar";
        };
        lightdm = {
          enable = true;
          background = unsafeRef ./wallpaper.jpg;
        };
        defaultSession = "none+i3";
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
      };
    };

    picom = {
      enable = true;
      fade = true;
      fadeSteps = [0.1 0.1];
      shadow = false;
      inactiveOpacity = 0.8;
      # Creates artifacts on scrolling, but vSync doesn't work otherwise, which leads to tearing.
      experimentalBackends = true;
      vSync = true;
      settings = {
        # This is needed for i3lock. Opacity rule doesn't work because there is no window id.
        mark-ovredir-focused = true;
        # Fixes screen tearing in full screen mode.
        unredir-if-possible = true;
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

    gnome = {
      chrome-gnome-shell.enable = true;
      gnome-keyring.enable = true;
    };

    geoclue2.enable = true;

    # localtime.enable = true; // This doesn't work and only generates errors.

    redshift.enable = true;

    actkbd = {
      enable = true;
      bindings =
        let
          light = "${pkgs.light}/bin/light";
          mkBinding = keys: events: command: { inherit keys events command; };
        in [
          (mkBinding [ 224 ] [ "key" "rep" ] "${light} -T 0.707")
          (mkBinding [ 225 ] [ "key" "rep" ] "${light} -T 1.414")
        ];
    };

    blueman.enable = true; # Bluetooth applet.
    openssh.enable = true;
    # openvpn.servers.nordvpn = {
    #   config = "config " + ./ca-us13.nordvpn.com.tcp443.ovpn ;
    # };
    printing.enable = true;
    avahi = {
      enable = true;
      # Important to resolve .local domains of printers, otherwise you get an error
      # like  "Impossible to connect to XXX.local: Name or service not known"
      nssmdns = true;
    };
    tlp.enable = true; # For battery conservation. Powertop disables wired mice.

    i2p.enable = true;

    journald.extraConfig = ''
      SystemMaxUse=50M
    '';

    clipmenu.enable = true;
    fwupd.enable = true;
  };

  programs = {
    fish = {
      enable = true;
      interactiveShellInit =
        with pkgs;
        let sourcePluginLoader = p:
              "source ${callPackage (./. + "/pkgs/fish/${p}.nix") {}}/loadPlugin.fish";
        in lib.strings.concatMapStringsSep "\n" sourcePluginLoader [
          "peco" "themeAgnoster" "done" "humantime" "z" "getOpts"
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
        '';
    };

    i3status-rust.enable = true;
    file-roller.enable = true;
    sway.enable = true;
    gnome-disks.enable = true; # GUI USB disk mounting.
    light.enable = true; # Brightness management.
    nm-applet.enable = true; # Wi-fi management.
    xss-lock = { # Lock on lid action.
      enable = true;
      extraOptions = ["--notifier=${dim-screen}/bin/dim-screen"];
      lockerCommand = "${prettyLock}/bin/prettyLock";
    };
    adb.enable = true;
    droidcam.enable = true;
  };

  # Allow elevating privileges dynamically via `pkexec`.
  # This doesn't currently help with `vscode` because `sudo-prompt` package is not working right.
  security.polkit = {
    enable = true;
    adminIdentities = [ "unix-user:bakhtiyar" ];
  };

  location.provider = "geoclue2";

  systemd.user.services =
    let autostart = cmd: {
      enable = true;
      wantedBy = [ "graphical-session.target" ];
      requires = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig.ExecStart = [ cmd ];
    };

    in {
      blueman = autostart "${pkgs.blueman}/bin/blueman-applet";
      # USB disk automounting.
      udiskie = autostart "${pkgs.udiskie}/bin/udiskie -t -n -a --appindicator -f ${pkgs.krusader}/bin/krusader";
    };

  virtualisation.libvirtd.enable = true;

  system = {
    autoUpgrade = {
      allowReboot = false;
      enable = true;
      channel = https://nixos.org/channels/nixos-20.09;
    };
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
    fontDir.enable = true;
    enableGhostscriptFonts = true;
    fonts = with pkgs; [
      anonymousPro
      corefonts
      dejavu_fonts
      fira-code
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

  swapDevices = [ { label = "swap"; } ];
  nix.maxJobs = lib.mkDefault 8;
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

}
