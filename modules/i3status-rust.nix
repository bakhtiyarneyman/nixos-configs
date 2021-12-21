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
        alternating_tint_bg = "#111111"
        alternating_tint_fg = "#111111"
      '';
      configFile = pkgs.writeText "i3status-rust.toml" ''
        icons = "awesome"
        scrolling = "natural"
        [theme]
        file = "${themeFile}"

        [[block]]
        block = "net"
        device = ${q cfg.networkInterface}
        format = "{ssid} {signal_strength}"
        interval = 5

        [[block]]
        block = "hueshift"

        [[block]]
        block = "disk_space"
        path = "/"
        alias = ""
        info_type = "used"
        alert = 90
        warning = 80
        format = "{icon} {percentage}"

        [[block]]
        block = "memory"
        display_type = "memory"
        format_mem = "{mem_used_percents}"
        format_swap = "{swap_used_percents}"

        [[block]]
        block = "cpu"
        interval = 1
        format = "{utilization} {frequency}"

        [[block]]
        block = "temperature"
        collapsed = false
        interval = 1
        good = -100
        format = "{max}"
        chip = "*-isa-*"

        [[block]]
        block = "load"
        interval = 1
        format = "{1m}"

        [[block]]
        block = "sound"
        on_click = "${pkgs.pavucontrol}/bin/pavucontrol"
        show_volume_when_muted = true

        [[block]]
        block = "battery"
        driver = "upower"
        format = "{percentage} {time}"
        device = "DisplayDevice"
        info = 100
        warning = 50
        critical = 20
        good = 101
        [block.theme_overrides]
        good_bg = "${black}"
        good_fg = "${white}"

        # This dumps "us,ru,az".
        # [[block]]
        # block = "keyboard_layout"
        # driver = "localebus"

        # [[block]]
        # block = "ibus"
        # [block.mappings]
        # "xkb:us::eng" = "EN"
        # "xkb:ru::rus" = "RU"
        # "xkb:az::aze" = "AZ"

        # [[block]]
        # block = "custom"
        # command = "xkblayout-state print %s"
        # interval = 0.5

        [[block]]
        block = "time"
        on_click = "${pkgs.gnome3.gnome-calendar}/bin/gnome-calendar"
        interval = 1
        format = "%a %Y-%m-%d %T"

        [[block]]
        block = "bluetooth"
        mac = "98:09:CF:BE:8B:61"
        format_unavailable = " OP"
        format = " OP"

        [[block]]
        block = "bluetooth"
        mac = "9B:5F:02:59:DB:63"
        format_unavailable = " ARI"
        format = " ARI"

        [[block]]
        block = "bluetooth"
        mac = "20:DF:B9:C8:29:13"
        format_unavailable = " DS"
        format = " DS"

        ${cfg.extraConfig}
      '' ;
      i3status-rust = pkgs.symlinkJoin {
        name = "i3status-rust";
        paths = [ pkgs.i3status-rust ];
        buildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/i3status-rs \
            --add-flags "${configFile}"
        '';
      };

    in mkIf cfg.enable {
      services.upower.enable = true;
      environment.systemPackages = [ i3status-rust ];
    };

}
