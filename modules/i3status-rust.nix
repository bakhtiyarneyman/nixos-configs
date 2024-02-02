{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.i3status-rust;
in {
  options.programs.i3status-rust = {
    enable = mkEnableOption "A status bar for i3";
    networkInterface = mkOption {
      type = types.str;
      default = "eno1";
      description = "An interface from /sys/class/net";
    };
    batteries = mkOption {
      type = types.listOf (types.submodule {
        options = {
          device = mkOption {
            type = types.nullOr types.str;
            default = null;
          };
          model = mkOption {
            type = types.nullOr types.str;
            default = null;
          };
          icon = mkOption {
            type = types.str;
          };
        };
      });
      default = [
        {
          device = "DisplayDevice";
          icon = "$icon";
        }
      ];
    };
    extraConfig = mkOption {
      type = types.str;
      default = "";
      description = "Extra configuration";
    };
  };

  config = let
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

      scrolling = "natural"
      [icons]
      icons = "awesome6"
      [theme]
      theme = "${themeFile}"

      [[block]]
      block = "disk_space"
      path = "/"
      info_type = "used"
      alert = 80
      warning = 60
      format = " $icon $percentage "
      format_alt = " $icon $used / $total "

      [[block]]
      block = "memory"
      format = " ^icon_memory_mem $mem_used_percents.eng(width:3)  ^icon_memory_swap $swap_used_percents.eng(width:3) "
      format_alt = " ^icon_memory_mem $mem_used.eng / $mem_total  ^icon_memory_swap $swap_used / $swap_total "
      interval = 1

      [[block]]
      block = "cpu"
      interval = 1
      format = " $icon $utilization.eng(width:4) "
      format_alt = " $icon $frequency.eng(prefix:G,width:3) "

      [[block]]
      block = "temperature"
      interval = 1
      good = -100
      format = " $icon $max"
      chip = "*-isa-*"

      [[block]]
      block = "sound"
      driver = "pulseaudio"
      format = " $icon $volume.eng(width:2) "
      show_volume_when_muted = true
      headphones_indicator = true
      [[block.click]]
      button = "left"
      cmd = "${pkgs.pavucontrol}/bin/pavucontrol"

      ${
        let
          mkBatterySection = battery: ''
            [[block]]
            block = "battery"
            driver = "upower"
            format = " ${battery.icon} $percentage "
            full_format = " ${battery.icon} "
            missing_format = " ${battery.icon}  "
            ${lib.optionalString (battery.device != null) ''device = "${battery.device}"''}
            ${lib.optionalString (battery.model != null) ''model = "${battery.model}"''}
            info = 100
            warning = 50
            critical = 20
            good = 101
            [block.theme_overrides]
            good_bg = "${black}"
            good_fg = "${white}"
          '';
        in
          lib.concatMapStrings mkBatterySection cfg.batteries
      }

      [[block]]
      block = "net"
      device = ${q cfg.networkInterface}
      format = " $icon ^icon_net_down $speed_down.eng(prefix:M,width:3)/s   ^icon_net_up $speed_up.eng(prefix:M,width:3)/s "
      format_alt = " $icon {$ssid $signal_strength|N/A} "
      interval = 1

      [[block]]
      block = "keyboard_layout"
      driver = "sway"
      [block.mappings]
      "English (US)" = "EN"
      "Russian (N/A)" = "RU"
      "Azerbaijani (N/A)" = "AZ"

      [[block]]
      block = "time"
      interval = 1
      [block.format]
      full = " $icon $timestamp.datetime(f:'%a %Y-%m-%d %T')"
      short = " $icon $timestamp.datetime(f:%T) "
      [[block.click]]
      button = "left"
      cmd = "${pkgs.gnome3.gnome-calendar}/bin/gnome-calendar"

      [[block]]
      block = "bluetooth"
      mac = "8C:64:A2:AB:D5:15"
      disconnected_format = " OP "
      format = " $icon  OP{ $percentage|} "

      [[block]]
      block = "bluetooth"
      mac = "20:DF:B9:C8:29:13"
      disconnected_format = " DS "
      format = " $icon  DS "

      [[block]]
      block = "notify"
      format = " $icon {$notification_count|0} "

      ${cfg.extraConfig}
    '';
    i3status-rust = pkgs.symlinkJoin {
      name = "i3status-rust";
      paths = [pkgs.i3status-rust];
      buildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/i3status-rs \
          --add-flags "${configFile}"
      '';
    };
  in
    mkIf cfg.enable {
      services.upower.enable = true;
      environment.systemPackages = [i3status-rust];
    };
}
