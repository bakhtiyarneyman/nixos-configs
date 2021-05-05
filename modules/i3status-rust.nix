{ config, lib, pkgs, ... }:

with lib;

let
   cfg = config.programs.i3status-rust;
in {

  options.programs.i3status-rust = {
    enable = mkEnableOption "A status bar for i3";
    networkInterface = mkOption {
      type = types.str;
      default = "eno1";
      description = "An interface from /sys/class/net";
    };
    extraConfig = mkOption {
      type = types.str;
      default = "";
      description = "Extra configuration";
    };
  };

  config =
    let
      q = x: ''"${x}"'';
      black = "#282c34";
      green = "#7a9f60";
      blue = "#3b84c0";
      yellow = "#d19a66";
      red = "#be5046";
      magenta = "#9a52af";
      # green = "#98c379";
      # blue = "#61afef";
      # yellow = "#e5c07b";
      # red = "#e06c75";
      # magenta  = "#c678dd";
      white = "#abb2bf";
      themeFile = pkgs.writeText "onedark.toml" ''
        idle_bg = "${black}" # black
        idle_fg = "${white}" # base1
        info_bg = "${green}" # blue
        info_fg = "${black}" # black
        good_bg = "${blue}" # green
        good_fg = "${black}" # black
        warning_bg = "${yellow}" # yellow
        warning_fg = "${black}" # black
        critical_bg = "${red}" # red
        critical_fg = "${black}" # black
        separator = "\ue0b2"
        separator_bg = "auto"
        separator_fg = "auto"
        alternating_tint_bg = "#000000"
        alternating_tint_fg = "#000000"
      '';
      configFile = pkgs.writeText "i3status-rust.toml" ''
        icons = "awesome"
        scrolling = "natural"
        [theme]
        file = "${themeFile}"

        [[block]]
        block = "net"
        device = ${q cfg.networkInterface}
        ssid = true
        bitrate = false
        ip = false
        speed_up = false
        speed_down = false
        graph_up = false
        interval = 5

        [[block]]
        block = "hueshift"

        [[block]]
        block = "disk_space"
        path = "/"
        alias = ""
        info_type = "used"
        format = "{icon} {percentage}"

        [[block]]
        block = "memory"
        display_type = "memory"
        format_mem = "{Mup}%"
        format_swap = "{SUp}%"

        [[block]]
        block = "cpu"
        interval = 1
        format = "{utilization} {frequency}"

        [[block]]
        block = "temperature"
        collapsed = false
        interval = 1
        good = -100
        format = "{max}°"
        chip = "*-isa-*"

        [[block]]
        block = "load"
        interval = 1
        format = "{1m}"

        [[block]]
        block = "bluetooth"
        mac = "98:09:CF:BE:8B:61"

        [[block]]
        block = "sound"
        on_click = "${pkgs.pavucontrol}/bin/pavucontrol"
        show_volume_when_muted = true

        [[block]]
        block = "battery"
        driver = "upower"
        format = "{percentage}% {time}"
        device = "DisplayDevice"
        info = 100
        warning = 50
        critical = 20
        good = 101
        [block.color_overrides]
        good_bg = "${black}"
        good_fg = "${white}"

        # This dumps "us,ru,az".
        [[block]]
        block = "keyboard_layout"
        driver = "localebus"

        # [[block]]
        # block = "custom"
        # command = "xkblayout-state print %s"
        # interval = 0.5

        [[block]]
        block = "time"
        on_click = "${pkgs.gnome3.gnome-calendar}/bin/gnome-calendar"
        interval = 1
        format = "%a %Y-%m-%d %T"

        ${cfg.extraConfig}
      '' ;
      i3status-rust =
        let unstable = import <nixos-unstable> { config = { allowUnfree = true; }; };
      in pkgs.writeShellScriptBin "i3status-rs" ''
        ${unstable.i3status-rust}/bin/i3status-rs ${configFile}
      '';

    in mkIf cfg.enable {
      services.upower.enable = true;
      environment.systemPackages = [ i3status-rust ];
    };

}
