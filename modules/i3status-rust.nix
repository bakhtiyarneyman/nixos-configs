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
  };

  config =
    let
      configFile =
        let q = x: ''"${x}"'';
        in pkgs.writeText "i3status-rust.toml" ''
        theme = "solarized-dark"
        icons = "awesome"
        scrolling = "natural"

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
        block = "disk_space"
        path = "/"
        alias = ""
        info_type = "available"
        unit = "GB"
        interval = 20
        warning = 20.0
        alert = 10.0
        show_percentage = true

        [[block]]
        block = "memory"
        display_type = "memory"
        format_mem = "{Mup}%"
        format_swap = "{SUp}%"

        [[block]]
        block = "cpu"
        interval = 1
        format = "{utilization}% {frequency}GHz"

        [[block]]
        block = "temperature"
        collapsed = false
        interval = 1
        good = 35
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
        block = "bluetooth"
        mac = "DC:2C:26:A4:97:20"

        [[block]]
        block = "sound"
        on_click = "${pkgs.pavucontrol}/bin/pavucontrol"
        show_volume_when_muted = true

        [[block]]
        block = "battery"
        driver = "upower"
        format = "{percentage}% {time}"
        device = "DisplayDevice"

        # This dumps "us,ru,az".
        # [[block]]
        # block = "keyboard_layout"
        # driver = "localebus"

        # [[block]]
        # block = "custom"
        # command = "xkblayout-state print %s"
        # interval = 0.5

        [[block]]
        block = "time"
        on_click = "${pkgs.gnome3.gnome-calendar}/bin/gnome-calendar"
        interval = 1
        format = "%a %Y-%m-%d %T"
      '';
      i3status-rust = pkgs.writeShellScriptBin "i3status-rs" ''
        ${pkgs.callPackage ../pkgs/i3status-rust.nix {}}/bin/i3status-rs ${configFile}
      '';

    in mkIf cfg.enable {
      services.upower.enable = true;
      environment.systemPackages = [ i3status-rust ];
    };

}
