# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

let 
  # Don't put into /nix/store. Instead use the files in /etc/nixos directly.
  # This makes it easier to test out configuration changes while still
  # managing them centrally.
  unsafeRef = toString;
in {
  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.kernelPackages = pkgs.linuxPackages_5_2;
  boot.loader.efi.canTouchEfiVariables = true;

  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  # i18n = {
  #   consoleFont = "Lat2-Terminus16";
  #   consoleKeyMap = "us";
  #   defaultLocale = "en_US.UTF-8";
  # };

  # Set your time zone.
  # time.timeZone = "Europe/Amsterdam";

  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    wget 
    neovim
    fish 
    peco 
    google-chrome
    firefox
    (tor-browser-bundle-bin.override { 
       mediaSupport = true;
       pulseaudioSupport = true;
    })
    guake
    gnomeExtensions.battery-status
    skype
    mkpasswd
    google-drive-ocamlfuse
    git
    vscode
    atom
    android-studio
    ntfs3g
    (callPackage <nixpkgs/pkgs/applications/misc/termite/wrapper.nix> {
       termite = termite-unwrapped;
       configFile = unsafeRef ./termite.conf;
    })
    rofi 
    xmobar
    clipmenu
    pavucontrol
  ];

  fonts = {
    enableFontDir = true;
    enableGhostscriptFonts = true;
    fonts = with pkgs; [
      anonymousPro
      corefonts
      dejavu_fonts
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

  users.defaultUserShell = pkgs.fish;
  programs.fish.enable = true;
  programs.fish.interactiveShellInit = 
    ''
      function fish_user_key_bindings
        bind \cr 'peco_select_history (commandline -b)'
      end
    '';
  programs.light.enable = true; # Brightness management.
  programs.nm-applet.enable = true; # Wi-fi management.
  programs.sway.enable = true;
  # programs.sway.extraPackages = with pkgs; [
  #   xwayland # Wayland bindings.
  #   dmenu # Launcher. Alternative to rofi.
  #   rxvt_unicode # Terminal. Alternative to termite.
  #   termite
  #   i3status-rust # Status bar. 
  #   swaylock # Lock screen.
  #   swayidle # Idle-related tasks.
  # ];  
  programs.adb.enable = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = { enable = true; enableSSHSupport = true; };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Enable CUPS to print documents.
  services.printing.enable = true;
  services.gnome3.chrome-gnome-shell.enable = true;

  # Enable sound.
  sound.enable = true;
  sound.mediaKeys = {
    enable = true;
    volumeStep = "1%";
  };
  hardware.pulseaudio = {
    enable = true;
    package = pkgs.pulseaudioFull; # For bluetooth headphones
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;
  services.xserver.layout = "us";
  # services.xserver.xkbOptions = "eurosign:e";

  # Enable touchpad support.
  services.xserver.libinput = {
    enable = true;
    naturalScrolling = true;
  };

  services.xserver.displayManager.gdm.enable = true;


  # Autologin is only safe becae the harddisk is encrypted. 
  # It can lead to an infinite loop if the window manager crashes.
  services.xserver.displayManager.gdm.autoLogin.enable = true; 
  services.xserver.displayManager.gdm.autoLogin.user = "bakhtiyar";
  services.xserver.windowManager = {
    i3 = {
      enable = true;
      configFile = unsafeRef ./i3.conf;
      package = pkgs.i3-gaps;
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
  services.xserver.desktopManager.gnome3.enable = true;
  # services.xserver.displayManager.sddm.enable = true;
  # services.xserver.desktopManager.plasma5.enable = true;

  services.compton.enable = true;

  services.geoclue2.enable = true;

  services.redshift = {
    enable = true;
    provider = "geoclue2";
  };

  services.actkbd = {
    enable = true;
    bindings = 
      let 
        light = "${pkgs.light}/bin/light";
	mkBinding = keys: events: command: { 
	  inherit keys;
	  inherit events;
	  inherit command;
	};
      in [
        (mkBinding [ 224 ] [ "key" "rep" ] "${light} -U 1")
        (mkBinding [ 225 ] [ "key" "rep" ] "${light} -A 1")
      ];  };

  powerManagement.powertop.enable = true; # Battery optimizations.

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.mutableUsers = false;
  users.users.bakhtiyar = {
    description = "Bakhtiyar Neyman";
    isNormalUser = true;
    extraGroups = [ 
	"wheel" # Enable ‘sudo’ for the user.
        "adbusers"
        "video" # Allow changing brightness via `light`.
    ];
    hashedPassword = "$6$.9aOljbRDW00nl$vRfj6ZVwgWXLTw2Ti/I55ov9nNl6iQAqAuauCiVhoRWIv5txKFIb49FKY0X3dgVqE61rPOqBh8qQSk61P2lZI1";
  };

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "19.03"; # Did you read the comment?
  system.autoUpgrade.enable = true;  
  nix.gc.automatic = true;
  nix.gc.dates = "03:15";
}
