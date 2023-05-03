# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, hostName, ... }:

let
  prettyLock = import ./prettyLock.nix pkgs;
  idleToDimSecs = 60;
  dimToLockSecs = 15;
  idleToLockSecs = idleToDimSecs + dimToLockSecs;
  idleToScreenOffSecs = idleToLockSecs + 10;
  dim-screen = pkgs.callPackage ./dim-screen.nix { dimSeconds = dimToLockSecs; };
  journst = pkgs.callPackage ./journst.nix { };
  email = let at = "@"; in "bakhtiyarneyman${at}gmail.com";
in
{
  boot = {
    tmpOnTmpfs = true;
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
        "docker"
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
      # System
      ntfs3g
      google-drive-ocamlfuse
      parted
      gparted
      # Utilities
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
      xcp # Better cp.
      cryfs
      (python3Packages.callPackage ./pkgs/namespaced-openvpn.nix { })
      # UI
      alacritty
      prettyLock
      rofi-wayland
      pavucontrol # Pulse audio volume control.
      pulseaudio # For pactl to be used from i3.
      libnotify # Notification service API.
      xmobar
      krusader
      # Themes.
      breeze-icons
      (callPackage ./pkgs/adwaita-one-dark.nix { })
      # Hardware
      psmisc
      pciutils
      glxinfo
      inxi
      # Browsers
      (google-chrome.override { commandLineArgs = "--enable-features=VaapiVideoDecoder"; })
      firefox
      # Shell packages
      fish
      peco
      # Communication
      skypeforlinux
      signal-desktop
      tdesktop # Telegram.
      unstable.tutanota-desktop
      zoom-us
      unstable.pkgs.discord
      slack
      teams
      # Development
      vscode
      cachix
      meld
      python3
      rnix-lsp
      nixpkgs-fmt
      cntr
      ghc
      cabal-install
      haskell-language-server
      haskellPackages.fourmolu
      stack
      # Productivity
      unstable.obsidian
      # Nix
      direnv
      nix-direnv
      # Image
      gimp
      inkscape
      # Audio
      audacity
      # Video
      vlc
      guvcview
      shotcut
      obs-studio
      # Privacy
      monero-gui
      (unstable.pkgs.tor-browser-bundle-bin.override {
        mediaSupport = true;
        pulseaudioSupport = true;
      })
    ];

    pathsToLink = [
      "/share/nix-direnv"
    ];

    etc = {
      "xdg/mimeapps.list".text = ''
        [Default Applications]
        video/mp4=vlc.desktop;
        video/mkv=vlc.desktop;
      '';
      "xdg/gtk-3.0/settings.ini".text = ''
        [Settings]
        gtk-theme-name = Adwaita-One-Dark
        gtk-application-prefer-dark-theme = true
        gtk-icon-theme-name = kora
      '';
      "aliases" = {
        text = ''
          root: ${email}
        '';
        mode = "0644";
      };
    };
    sessionVariables.NIXOS_OZONE_WL = "1";
  };

  networking = {
    inherit hostName;
    networkmanager.enable = true;
    firewall = {
      enable = true;
      logRefusedConnections = true;
      allowedTCPPorts = [
        # SSH.
        22
        # Development web server.
        1234
        # Chromecast ports.
        8008
        8009
        8010
        8443
        # Misc.
        38422
      ];
      allowedUDPPorts = [
        # GoPro web server.
        8554
      ];
      allowedUDPPortRanges = [
        # Chromecast ports.
        { from = 32768; to = 60999; }
      ];
      trustedInterfaces = [ "tailscale0" ];
      checkReversePath = "loose";
    };
    hosts = {
      "100.65.77.115" = [ "iron-tailscale" ];
      "100.126.205.61" = [ "kevlar-tailscale" ];
    };
  };

  sound.enable = true;

  hardware = {
    bluetooth = {
      enable = true;
      settings = {
        General = {
          DiscoverableTimeout = 0;
          AlwaysPairable = true;
          MultiProfile = "multiple";
          Privacy = "device";
          FastConnectable = "true"; # Energy-inefficient.
          ControllerMode = "dual";
          JustWorksRepairing = "always";
          Experimental = "true";
        };
        Policy = {
          AutoEnable = false;
        };
      };
    };
    enableRedistributableFirmware = true;
    opengl = {
      enable = true;
      driSupport32Bit = true;
      extraPackages = with pkgs; [
        intel-media-driver # LIBVA_DRIVER_NAME=iHD
        vaapiIntel # LIBVA_DRIVER_NAME=i965 (older but works better for Firefox/Chromium)
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
      displayManager.defaultSession = "sway";
      # TODO: use this when unblocked: https://github.com/NixOS/nixpkgs/issues/54150
      # desktopManager.gnome.extraGSettingsOverrides = ''
      #   [org.gnome.desktop.interface]
      #   gtk-theme='Adwaita-One-Dark'
      #   icon-theme='kora'
      #   font-name='Fira Sans'
      # '';
      exportConfiguration = true;
    };

    pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };

    # Notification service.
    dunst = {
      enable = true;
      globalConfig = {
        follow = "keyboard";
        width = "(0, 500)";
        height = "300";
        notification_limit = "5";
        origin = "top-right";
        offset = "50x50";
        shrink = "true";
        separator_height = "1";
        padding = "8";
        horizontal_padding = "8";
        text_icon_padding = "8";
        frame_width = "1";
        separator_color = "foreground";
        sort = "false";
        idle_threshold = "120";
        font = "Fira Sans 12";
        line_height = "0";
        markup = "full";
        format = ''"<span size="larger" weight="light">%s</span> <span size="smaller" weight="bold" fgalpha="50%%">%a</span>\n%b"'';
        alignment = "left";
        show_age_threshold = "60";
        word_wrap = "yes";
        ellipsize = "middle";
        ignore_newline = "no";
        hide_duplicate_count = "false";
        show_indicators = "yes";
        icon_position = "left";
        # max_icon_size = "64";
        sticky_history = "yes";
        history_length = "100";
        dmenu = "${pkgs.rofi-wayland}/bin/rofi -dmenu -theme /etc/nixos/onedark.rasi -p dunst";
        always_run_script = "true";
        corner_radius = "10";
        force_xinerama = "false";
        mouse_left_click = "context";
        mouse_middle_click = "close_all";
        mouse_right_click = "close_current";
        icon_path =
          let
            categories = [
              "actions"
              "places"
              "animations"
              "devices"
              "status"
              "apps"
              "emblems"
              "mimetypes"
              "categories"
              "emotes"
              "panel"
            ];
            prefix = x: "${pkgs.kora-icon-theme}/share/icons/kora/${x}";
          in
          lib.concatStringsSep ":"
            (map prefix
              (map (category: "${category}/scalable") categories ++ [ "panel/24" ]));
      };
      experimentalConfig = {
        per_monitor_dpi = "true";
      };
      urgencyConfig =
        let
          q = s: ''"${s}"'';
          urgency = bg: fg: timeout: {
            background = q bg;
            foreground = q fg;
            frame_color = q fg;
            timeout = toString timeout;
          };
        in
        {
          low = urgency "#282c34" "#abb2bf" 10;
          normal = urgency "#61afef" "#282c34" 30;
          critical = urgency "#ff0000" "#ffffff" 0;
        };
    };

    gnome = {
      gnome-browser-connector.enable = true;
      gnome-keyring.enable = true;
    };

    geoclue2.enable = true;

    # localtime.enable = true; // This doesn't work and only generates errors.

    actkbd = {
      enable = true;
      bindings =
        let
          light = "${pkgs.light}/bin/light";
          mkBinding = keys: events: command: { inherit keys events command; };
        in
        [
          (mkBinding [ 224 ] [ "key" "rep" ] "${light} -T 0.707")
          (mkBinding [ 225 ] [ "key" "rep" ] "${light} -T 1.414")
        ];
    };

    logind.extraConfig = ''
      HandlePowerKey=suspend
    '';

    blueman.enable = true; # Bluetooth applet.
    openssh = {
      enable = true;
      knownHosts = {
        iron = {
          hostNames = [ "iron-tailscale" "100.65.135.29" ];
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP9JkARs/riIN3LTQm3pLhOmc9JiWNczDrUL1coQpLDa";
        };
        kevlar = {
          hostNames = [ "kevlar-tailscale" "100.126.205.61" ];
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKSyMQogWih9Tk8cpckwxP6CLzJxZqtg+qdFbXYbF9Sc";
        };
      };
    };
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

    tailscale.enable = true;
    fwupd.enable = true;
    onedrive.enable = true;
  };

  programs = {
    dconf.enable = true; # For gnome-keyring. See: https://github.com/NixOS/nixpkgs/issues/161224
    fish = {
      enable = true;
      interactiveShellInit =
        with pkgs;
        let
          sourcePluginLoader = p:
            "source ${callPackage (./. + "/pkgs/fish/${p}.nix") {}}/loadPlugin.fish";
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

          direnv hook fish | source
        '';
    };

    i3status-rust.enable = true;
    file-roller.enable = true;
    git = {
      enable = true;
      package = pkgs.gitFull;
      config = {
        user = {
          inherit email;
          name = "Bakhtiyar Neyman";
        };
        alias = {
          plog = "log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(bold yellow)%d%C(reset)' --all";
        };
        diff = {
          tool = "${pkgs.meld}/bin/meld";
        };
        credential = {
          helper = "libsecret";
        };
      };
    };
    sway = {
      enable = true;
      extraOptions = [
        "--config=${./sway.conf}"
      ];
      extraPackages = with pkgs; [
        sway-contrib.grimshot
        (callPackage ./pkgs/inactive-windows-transparency.nix { })
        swayidle
        gammastep
        upower # Charging state.
        lm_sensors # Temperature.
        xkblayout-state # Keyboard layout (a hack).
        wl-clipboard
        clipman # Clipboard manager.
      ];
      wrapperFeatures.base = true;
      wrapperFeatures.gtk = true;
    };
    gnome-disks.enable = true; # GUI USB disk mounting.
    light.enable = true; # Brightness management.
    nm-applet.enable = true; # Wi-fi management.
    adb.enable = true;
    droidcam.enable = true;
    seahorse.enable = true;
    gnupg.agent = {
      enable = true;
      pinentryFlavor = "gtk2";
    };
    steam = {
      enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
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
          passwordeval = "cat /etc/email_password";
          from = email;
        };
      };
    };
  };

  # Allow elevating privileges dynamically via `pkexec`.
  # This doesn't currently help with `vscode` because `sudo-prompt` package is not working right.
  security.polkit = {
    enable = true;
    adminIdentities = [ "unix-user:bakhtiyar" ];
  };

  location.provider = "geoclue2";

  systemd.user.services =
    let
      autostart = cmd: {
        enable = true;
        wantedBy = [ "graphical-session.target" ];
        requires = [ "graphical-session.target" ];
        after = [ "graphical-session.target" ];
        serviceConfig.ExecStart = [ cmd ];
        environment."XDG_CONFIG_DIRS" = "/etc/xdg";
      };
      mkJournst = phase:
        let
          cfg = if phase == "boot" then { flags = "--boot --no-pager"; restart = "no"; } else
          if phase == "run" then { flags = "--follow --lines=0"; restart = "on-failure"; } else
          throw "Phase ${phase} is not supported";
        in
        {
          "journst-${phase}" = {
            wantedBy = [ "graphical-session.target" ];
            requires = [ "dunst.service" ];
            after = [ "graphical-session.target" "dunst.service" ];
            serviceConfig = {
              ExecStart = [ "${journst}/bin/journst ${cfg.flags}" ];
              Restart = cfg.restart;
            };
          };
        };
    in
    {
      blueman = autostart "${pkgs.blueman}/bin/blueman-applet";
      # USB disk automounting.
      udiskie = autostart "${pkgs.udiskie}/bin/udiskie -t -n -a --appindicator -f ${pkgs.krusader}/bin/krusader";
      signal = autostart "${pkgs.signal-desktop}/bin/signal-desktop";
      telegram = autostart "${pkgs.tdesktop}/bin/telegram-desktop";
      discord = autostart "${pkgs.unstable.discord}/bin/discord";
      nm-applet.environment."XDG_CONFIG_DIRS" = "/etc/xdg";
      inactive-windows-transparency = {
        wantedBy = [ "graphical-session.target" ];
        partOf = [ "graphical-session.target" ];
        serviceConfig.ExecStart = [
          "${pkgs.callPackage ./pkgs/inactive-windows-transparency.nix { }}/bin/inactive-windows-transparency.py"
        ];
      };
      gammastep = autostart "${pkgs.gammastep}/bin/gammastep -t 6500:3300";
      swayidle = autostart "${pkgs.writeShellScriptBin "autolock" ''
        ${pkgs.swayidle}/bin/swayidle -w \
          timeout ${builtins.toString idleToDimSecs} 'echo "Dimming..."; ${dim-screen}/bin/dim-screen &' \
            resume 'echo "Undim."; ${pkgs.psmisc}/bin/killall dim-screen' \
          timeout ${builtins.toString idleToLockSecs} 'echo "Locking..."; ${prettyLock}/bin/prettyLock &' \
          timeout ${builtins.toString idleToScreenOffSecs} 'echo "Screen off..."; ${pkgs.sway}/bin/swaymsg "output * dpms off"' \
            resume 'echo "Screen on"; ${pkgs.sway}/bin/swaymsg "output * dpms on"' \
          before-sleep ${prettyLock}/bin/prettyLock
      ''}/bin/autolock";
      wl-paste = autostart "${pkgs.wl-clipboard}/bin/wl-paste -t text --watch ${pkgs.clipman}/bin/clipman store --max-items 1024";
    } // mkJournst "boot" // mkJournst "run";

  virtualisation = {
    libvirtd.enable = true;
    docker.enable = true;
  };

  nixpkgs = {
    config = {
      allowUnfree = true;
      android_sdk.accept_license = true;
      config.packageOverrides.vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
    };
    overlays = [
      (self: super: {
        nix-direnv = super.nix-direnv.override { enableFlakes = true; };
        # TODO: remove when https://github.com/NixOS/nixpkgs/issues/206744 closed.
        signal-desktop = super.signal-desktop.overrideAttrs (old: {
          runtimeDependencies = old.runtimeDependencies ++ [ super.wayland ];
        });
      })
    ];
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
      keep-derivations = true
      keep-outputs = true
    '';
  };

  fonts = {
    fontDir.enable = true;
    enableGhostscriptFonts = true;
    fontconfig.defaultFonts = {
      monospace = [ "Fira Mono" ];
      sansSerif = [ "Fira Sans" ];
      serif = [ "Lora" ];
    };
    fonts = with pkgs; [
      anonymousPro
      corefonts
      dejavu_fonts
      fira
      fira-code
      font-awesome_4
      font-awesome_5
      freefont_ttf
      google-fonts
      inconsolata
      liberation_ttf
      noto-fonts-emoji
      powerline-fonts
      source-code-pro
      terminus_font
      ttf_bitstream_vera
      ubuntu_font_family
    ];
  };

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

}
