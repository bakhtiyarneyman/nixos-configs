{ config, pkgs, lib, hostName, ... }:
let
  dimToLockSecs = 15;
in
{
  imports = [
    ./dunst.nix
    ./i3status-rust.nix
  ];

  config = {

    users.users.bakhtiyar.extraGroups = [
      "adbusers"
      "video" # Allow changing brightness via `light`.
    ];


    # List packages installed in system profile. To search, run:
    # $ nix search wget
    environment = {
      systemPackages = with pkgs; [
        # System
        gparted
        # Utilities
        libsecret # For gnome-keyring.
        xorg.xdpyinfo
        udiskie # USB disk automounting.
        qbittorrent
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
        adwaita-one-dark
        # Browsers
        (google-chrome.override { commandLineArgs = "--enable-features=VaapiVideoDecoder"; })
        firefox
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
        # Image
        gimp
        inkscape
        # Audio
        audacity
        # Video
        libva-utils
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
        "avahi/services/unused".text = "";
      };
      sessionVariables = {
        NIXOS_OZONE_WL = "1";
        SSH_AUTH_SOCK = "/home/bakhtiyar/.1password/agent.sock";
      };
    };

    networking.firewall = {
      allowedTCPPorts = [
        # CUPS.
        631
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
        # CUPS.
        631
        # GoPro web server.
        8554
      ];
      allowedUDPPortRanges = [
        # Chromecast ports.
        { from = 32768; to = 60999; }
      ];
    };

    sound.enable = true;

    hardware = {
      # pulseaudio.enable = false;
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
      logitech.wireless.enableGraphical = true;
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

      blueman.enable = true; # Bluetooth applet.
      printing = {
        enable = true;
        drivers = with pkgs; [
          gutenprint
          gutenprintBin
          brlaser
          brgenml1lpr
          brgenml1cupswrapper
        ];
      };

      onedrive.enable = true;
    };

    programs = {
      dconf.enable = true; # For gnome-keyring. See: https://github.com/NixOS/nixpkgs/issues/161224

      git.config = {
        diff = {
          tool = "${pkgs.meld}/bin/meld";
        };
        credential = {
          helper = "libsecret";
        };
      };

      i3status-rust.enable = true;
      file-roller.enable = true;
      sway = {
        enable = true;
        extraOptions = [
          "--config=${../sway.conf}"
        ];
        extraPackages = with pkgs; [
          sway-contrib.grimshot
          inactive-windows-transparency
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

      _1password.enable = true;
      _1password-gui = {
        enable = true;
        polkitPolicyOwners = [ "bakhtiyar" ];
      };
      system-config-printer.enable = true;
    };

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
                ExecStart = [ "${pkgs.journst}/bin/journst ${cfg.flags}" ];
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
            "${pkgs.inactive-windows-transparency}/bin/inactive-windows-transparency.py"
          ];
        };
        gammastep = autostart "${pkgs.gammastep}/bin/gammastep -t 6500:3300";
        swayidle =
          let
            idleToDimSecs = 60;
            idleToLockSecs = idleToDimSecs + dimToLockSecs;
            idleToScreenOffSecs = idleToLockSecs + 10;
          in
          autostart "${pkgs.writeShellScriptBin "autolock" ''
        ${pkgs.swayidle}/bin/swayidle -w \
          timeout ${builtins.toString idleToDimSecs} 'echo "Dimming..."; ${pkgs.dim-screen}/bin/dim-screen &' \
            resume 'echo "Undim."; ${pkgs.psmisc}/bin/killall dim-screen' \
          timeout ${builtins.toString idleToLockSecs} 'echo "Locking..."; ${pkgs.prettyLock}/bin/prettyLock &' \
          timeout ${builtins.toString idleToScreenOffSecs} 'echo "Screen off..."; ${pkgs.sway}/bin/swaymsg "output * dpms off"' \
            resume 'echo "Screen on"; ${pkgs.sway}/bin/swaymsg "output * dpms on"' \
          before-sleep ${pkgs.prettyLock}/bin/prettyLock
      ''}/bin/autolock";
        polkit-gnome-authentication-agent-1 = {
          description = "polkit-gnome-authentication-agent-1";
          wantedBy = [ "graphical-session.target" ];
          wants = [ "graphical-session.target" ];
          after = [ "graphical-session.target" ];
          serviceConfig = {
            Type = "simple";
            ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
            Restart = "on-failure";
            RestartSec = 1;
            TimeoutStopSec = 10;
          };
        };
        wl-paste = autostart "${pkgs.wl-clipboard}/bin/wl-paste -t text --watch ${pkgs.clipman}/bin/clipman store --max-items 1024";
      } // mkJournst "boot" // mkJournst "run";

    nixpkgs = {
      config = {
        android_sdk.accept_license = true;
        config.packageOverrides.vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
      };
      overlays = [
        (self: super: {
          journst = pkgs.callPackage ../pkgs/journst.nix { };
          dim-screen = pkgs.callPackage ../pkgs/dim-screen.nix { dimSeconds = dimToLockSecs; };
          prettyLock = pkgs.callPackage ../pkgs/prettyLock.nix { };
          adwaita-one-dark = pkgs.callPackage ../pkgs/adwaita-one-dark.nix { };
          inactive-windows-transparency = pkgs.callPackage ../pkgs/inactive-windows-transparency.nix { };
        })
      ];
    };

    nix.extraOptions = ''
      keep-derivations = true
      keep-outputs = true
    '';

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
        font-awesome_6
        freefont_ttf
        google-fonts
        inconsolata
        liberation_ttf
        noto-fonts-emoji
        source-code-pro
        terminus_font
        ttf_bitstream_vera
        ubuntu_font_family
      ];
    };

    powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  };

}
