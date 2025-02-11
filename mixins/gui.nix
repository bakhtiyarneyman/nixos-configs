{
  pkgs,
  lib,
  config,
  ...
}: let
  dimToLockSecs = 15;
in {
  imports = [
    ../modules/i3status-rust.nix
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
        libreoffice
        # UI
        alacritty
        swaynotificationcenter
        prettyLock
        rofi-wayland
        pavucontrol # Pulse audio volume control.
        pulseaudio # For pactl to be used from i3.
        libnotify # Notification service API.
        krusader
        wlr-randr
        junction
        glib # Needed for junction.
        dim-screen
        # Themes.
        breeze-icons
        adwaita-one-dark
        # Browsers
        (google-chrome.override {commandLineArgs = "--enable-features=VaapiVideoDecoder";})
        brave
        firefoxpwa
        # Communication
        skypeforlinux
        signal-desktop
        tdesktop # Telegram.
        tutanota-desktop
        zoom-us
        unstable.pkgs.discord
        slack
        rofimoji
        # Development
        (unstable.vscode.override {isInsiders = false;})
        cachix
        meld
        python3
        # nixd
        nil
        alejandra
        nixpkgs-fmt
        cntr
        (haskellPackages.ghcWithPackages (ps: with ps; [protolude text turtle text]))
        cabal-install
        haskell-language-server
        haskellPackages.fourmolu
        stack
        # Productivity
        obsidian
        # Image
        gimp
        inkscape
        # Audio
        audacity
        # Video
        blender
        ffmpeg_6-full
        guvcview
        libva-utils
        mpv
        obs-studio
        vlc
        # Privacy
        monero-gui
        (unstable.pkgs.tor-browser-bundle-bin.override {
          mediaSupport = true;
          pulseaudioSupport = true;
        })
        yubioath-flutter
        # VM
        quickemu
        waydroid_script
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
        {
          from = 32768;
          to = 60999;
        }
      ];
    };

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
      graphics = {
        enable = true;
        enable32Bit = true;
        extraPackages = with pkgs; [
          vaapiVdpau
          libvdpau-va-gl
        ];
      };
      logitech.wireless.enableGraphical = true;
    };

    security.soteria.enable = true;

    services = {
      dbus.implementation = "broker";
      displayManager = {
        enable = true;
        defaultSession = "sway";
      };
      # Enable the X11 windowing system.
      xserver = {
        displayManager = {
          gdm = {
            enable = true;
            autoSuspend = false;
          };
        };
        desktopManager.gnome.extraGSettingsOverrides = ''
          [org.gnome.desktop.interface]
          gtk-theme='Adwaita-One-Dark'
          icon-theme='kora'
          font-name='Fira Sans'
        '';
        exportConfiguration = true;
      };

      pipewire = {
        enable = true;
        alsa.enable = true;
        pulse.enable = true;
        wireplumber.enable = true;
      };

      gnome = {
        gnome-browser-connector.enable = true;
        gnome-keyring.enable = true;
      };

      # localtime.enable = true; // This doesn't work and only generates errors.
      actkbd = {
        enable = true;
        bindings = let
          light = "${pkgs.light}/bin/light";
          mkBinding = keys: events: command: {inherit keys events command;};
        in [
          (mkBinding [224] ["key" "rep"] "${light} -T 0.707")
          (mkBinding [225] ["key" "rep"] "${light} -T 1.414")
        ];
      };

      blueman.enable = true; # Bluetooth applet.
      pcscd.enable = true;
      printing = {
        enable = true;
        drivers = with pkgs; [
          gutenprint
          gutenprintBin
          brlaser
          brgenml1lpr
          brgenml1cupswrapper
        ];
        allowFrom = [
          "all"
        ];
      };
    };

    programs = {
      dconf.enable = true; # For gnome-keyring. See: https://github.com/NixOS/nixpkgs/issues/161224

      git.config = {
        diff = {
          tool = "${pkgs.meld}/bin/meld";
        };
        credential = {
          helper = "${pkgs.gitFull}/bin/git-credential-libsecret";
        };
      };

      i3status-rust.enable = true;
      file-roller.enable = true;
      sway = {
        enable = true;
        extraOptions = [
          "--config=/etc/nixos/sway.conf"
        ];
        extraPackages = with pkgs; [
          clipman # Clipboard manager.
          inactive-windows-transparency
          lm_sensors # Temperature.
          sway-contrib.grimshot
          swayidle
          upower # Charging state.
          wl-clipboard
          wlsunset
          xkblayout-state # Keyboard layout (a hack).
        ];
        wrapperFeatures.gtk = true;
      };
      firefox = {
        enable = true;
        nativeMessagingHosts.packages = [pkgs.firefoxpwa];
        preferences = {
          "media.ffmpeg.vaapi.enabled" = true;
          "media.navigator.mediadatadecoder_vpx_enabled" = true;
          "media.rdd-ffmpeg.enabled" = true;
          "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        };
      };
      gnome-disks.enable = true; # GUI USB disk mounting.
      light.enable = true; # Brightness management.
      nm-applet.enable = true; # Wi-fi management.
      adb.enable = true;
      droidcam.enable = true;
      seahorse.enable = true;
      gnupg.agent = {
        enable = true;
        pinentryPackage = pkgs.pinentry-gtk2;
      };
      steam = {
        enable = true;
        remotePlay.openFirewall = true;
        dedicatedServer.openFirewall = true;
        localNetworkGameTransfers.openFirewall = true;
      };

      _1password-gui = {
        enable = true;
        polkitPolicyOwners = ["bakhtiyar"];
      };
      system-config-printer.enable = true;
      wireshark.package = pkgs.wireshark;
    };

    systemd.user.targets = {
      sway-session = {
        enable = true;
        bindsTo = ["graphical-session.target"];
        wants = ["graphical-session-pre.target"];
        after = ["graphical-session-pre.target"];
      };
    };
    systemd.user.services = let
      autostart = cmd: {
        enable = true;
        # Won't start unless sway-session.target has been started.
        requisite = ["sway-session.target"];
        after = ["sway-session.target"];
        # Will be started if sway-session is started.
        wantedBy = ["sway-session.target"];
        serviceConfig.ExecStart = [cmd];
        environment."XDG_CONFIG_DIRS" = "/etc/xdg";
      };
      mkJournst = phase: let
        cfg =
          if phase == "boot"
          then {
            flags = "--boot --no-pager";
            restart = "no";
          }
          else if phase == "run"
          then {
            flags = "--follow --lines=0";
            restart = "on-failure";
          }
          else throw "Phase ${phase} is not supported";
      in {
        "journst-${phase}" = {
          wantedBy = ["sway-session.target"];
          requires = ["swaync.service"];
          after = ["swaync.service"];
          serviceConfig = {
            ExecStart = ["${pkgs.journst}/bin/journst ${cfg.flags}"];
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

        slack = autostart "${pkgs.slack}/bin/slack";

        nm-applet.environment."XDG_CONFIG_DIRS" = "/etc/xdg";

        inactive-windows-transparency =
          autostart
          "${pkgs.inactive-windows-transparency}/bin/inactive-windows-transparency.py";

        swaync = autostart "${pkgs.swaynotificationcenter}/bin/swaync --config /etc/nixos/swaync.conf --style /etc/nixos/swaync.css";

        wlsunset = let
          wlsunset-here = pkgs.writeShellScriptBin "wlsunset-here" ''
            ${pkgs.wlsunset}/bin/wlsunset -t 3300 $(${pkgs.curl}/bin/curl -s http://ip-api.com/json | ${pkgs.jq}/bin/jq -r '"-l \(.lat) -L \(.lon)"')
          '';
        in
          autostart ''${wlsunset-here}/bin/wlsunset-here'';

        swayidle = let
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

        # The flag might not be necessary after the fix:
        # https://nixpk.gs/pr-tracker.html?pr=278953
        tutanota = autostart "${pkgs.tutanota-desktop}/bin/tutanota-desktop --password-store=gnome-libsecret";

        wl-paste = autostart "${pkgs.wl-clipboard}/bin/wl-paste -t text --watch ${pkgs.clipman}/bin/clipman store --max-items 1024";

        # # Execute shell script that runs "env > /tmp/vars.systemd". Useful for finding discrepancies between systemd and shell environments.
        # dump_vars = autostart "${pkgs.writeShellScriptBin "dump_vars" ''
        #   env | sort > /tmp/vars.systemd
        # ''}/bin/dump_vars";
      }
      // mkJournst "boot"
      // mkJournst "run";

    nixpkgs = {
      config = {
        android_sdk.accept_license = true;
        permittedInsecurePackages = [
          "qbittorrent-4.6.4" # For qbittorrent.
        ];
      };
      overlays = [
        (self: super: {
          adwaita-one-dark = pkgs.callPackage ../pkgs/adwaita-one-dark.nix {};
          android-udev-rules = super.pkgs.unstable.android-udev-rules.override {};
          blender = super.blender.override {
            ffmpeg = pkgs.ffmpeg_6-full;
            hipSupport = true;
          };
          dim-screen = pkgs.callPackage ../pkgs/dim-screen.nix {
            inherit config;
            dimSeconds = dimToLockSecs;
          };
          inactive-windows-transparency = pkgs.callPackage ../pkgs/inactive-windows-transparency.nix {};
          journst = pkgs.callPackage ../pkgs/journst.nix {inherit config;};
          # nixd = super.pkgs.unstable.nixd.override {
          #   # nix = self.pkgs.unstable.nix;
          # };
          prettyLock = pkgs.callPackage ../pkgs/prettyLock.nix {};
          tutanota-desktop = super.pkgs.unstable.tutanota-desktop;
          waydroid_script = pkgs.callPackage ../pkgs/waydroid_script.nix {};
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
        monospace = ["Fira Mono"];
        sansSerif = ["Fira Sans"];
        serif = ["Lora"];
      };
      packages = with pkgs; [
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

    virtualisation = {
      spiceUSBRedirection.enable = true;
      waydroid.enable = true;
    };

    xdg.portal = {
      enable = true;
      wlr = {
        enable = true;
        settings = {
          screencast = {
            max_fps = 30;
            exec_before = "${pkgs.swaynotificationcenter}/bin/swaync-client --inhibitor-add xdg-desktop-portal-wlr";
            exec_after = "${pkgs.swaynotificationcenter}/bin/swaync-client --inhibitor-remove xdg-desktop-portal-wlr";
            chooser_type = "simple";
            chooser_cmd = "${pkgs.slurp}/bin/slurp -f %o -or";
          };
        };
      };
    };
  };
}
