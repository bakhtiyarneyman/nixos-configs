{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.i3status-rust;
  settingsFormat = pkgs.formats.toml {};
in {
  options.programs.i3status-rust = with types; {
    enable = mkEnableOption "A status bar for i3";
    temperature = mkOption {
      type = submodule {
        options = {
          chip = mkOption {
            type = str;
            default = "*-isa-*";
            description = "A chip from /sys/class/hwmon";
          };
          idle = mkOption {
            type = int;
            default = 45;
            description = "Temperature in Celsius when the system is idle";
          };
        };
      };
    };
    batteries = mkOption {
      type = listOf (submodule {
        options = {
          device = mkOption {
            type = nullOr str;
            default = null;
          };
          model = mkOption {
            type = nullOr str;
            default = null;
          };
          icon = mkOption {
            type = str;
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
    extraBlocks = mkOption {
      type = settingsFormat.type;
      default = [];
      description = "Extra blocks configuration";
    };
  };

  config = let
    mkStatusBlock = which: icon: let
      getStatus = pkgs.writeText "get-systemd-status-for-i3.fish" ''
        if test (systemctl ${which} is-system-running) != running
            set state Warning
            set failed (systemctl ${which} --failed --no-pager --plain --quiet list-units | awk '{print $1}')
            set text (for line in $failed
              echo $line | string split --fields 1 '.'
            end | string join -- ',')
            set text "${icon} $text"
        else
            set text "${icon}"
            set state Idle
        end
        # Use jq for escaping.
        echo "$text" | jq --raw-input --arg state $state '{"icon": "", "state": $state, "text": . }'
      '';
    in {
      block = "custom";
      command = "${pkgs.fish}/bin/fish ${getStatus}";
      json = true;
    };

    configFile = let
      hash = color: "#${config.palette.${color}}";
    in
      settingsFormat.generate "config.toml" {
        scrolling = "natural";
        icons.icons = "awesome6";
        theme.overrides = {
          idle_bg = hash "background";
          idle_fg = hash "foreground";
          info_bg = hash "green";
          info_fg = hash "background";
          good_bg = hash "blue";
          good_fg = hash "background";
          warning_bg = hash "yellow";
          warning_fg = hash "background";
          critical_bg = hash "red";
          critical_fg = hash "background";
          separator = "";
          separator_bg = "auto";
          separator_fg = "auto";
          alternating_tint_bg = "#111111";
          alternating_tint_fg = "#111111";
        };
        block =
          [
            (mkStatusBlock "" "")
            (mkStatusBlock "--user" "")
            {
              block = "disk_space";
              path = "/";
              info_type = "used";
              alert = 80;
              warning = 60;
              format = " $icon $percentage ";
              format_alt = " $icon $used / $total ";
            }
            {
              block = "memory";
              format = " ^icon_memory_mem $mem_used_percents.eng(width:3)  ^icon_memory_swap $swap_used_percents.eng(width:3) ";
              format_alt = " ^icon_memory_mem $mem_used.eng / $mem_total  ^icon_memory_swap $swap_used / $swap_total ";
              interval = 1;
            }
            {
              block = "cpu";
              interval = 1;
              format = " $icon $utilization.eng(width:4) ";
              format_alt = " $icon $frequency.eng(prefix:G,width:3) ";
            }
            {
              block = "temperature";
              interval = 1;
              format = " $icon $max";
              idle = cfg.temperature.idle;
              chip = "${cfg.temperature.chip}";
            }
            {
              block = "sound";
              driver = "pulseaudio";
              format = " $icon $volume.eng(width:2) ";
              show_volume_when_muted = true;
              headphones_indicator = true;
              click = [
                {
                  button = "left";
                  cmd = "${pkgs.pavucontrol}/bin/pavucontrol";
                }
              ];
            }
          ]
          ++ (let
            optionalSet = condition: value:
              if condition
              then value
              else {};
            mkBatteryBlock = battery:
              {
                block = "battery";
                driver = "upower";
                format = " ${battery.icon} $percentage ";
                full_format = " ${battery.icon} ";
                missing_format = " ${battery.icon}  ";
                info = 100;
                warning = 50;
                critical = 20;
                good = 101;
                theme_overrides = {
                  good_bg = hash "background";
                  good_fg = hash "foreground";
                };
              }
              // (optionalSet (battery.device != null) {device = battery.device;})
              // (optionalSet (battery.model != null) {model = battery.model;});
          in
            map mkBatteryBlock cfg.batteries)
          ++ [
            {
              block = "net";
              format = " $icon ^icon_net_down $speed_down.eng(prefix:M,width:3)/s   ^icon_net_up $speed_up.eng(prefix:M,width:3)/s ";
              format_alt = " $icon {$signal_strength|} ";
              interval = 1;
            }
            {
              block = "keyboard_layout";
              driver = "sway";
              mappings = {
                "English (US)" = "EN";
                "Russian (N/A)" = "RU";
                "Azerbaijani (N/A)" = "AZ";
              };
            }
            {
              block = "time";
              interval = 1;
              format = {
                full = " $icon $timestamp.datetime(f:'%a %Y-%m-%d %T')";
                short = " $icon $timestamp.datetime(f:%T) ";
              };
              click = [
                {
                  button = "left";
                  cmd = "${pkgs.gnome-calendar}/bin/gnome-calendar";
                }
              ];
            }
            {
              block = "bluetooth";
              mac = "84:0F:2A:DE:EF:11";
              disconnected_format = " OP ";
              format = " $icon  OP{ $percentage|} ";
            }
            {
              block = "bluetooth";
              mac = "20:DF:B9:C8:29:13";
              disconnected_format = " DS ";
              format = " $icon  DS ";
            }
            {
              block = "notify";
              driver = "swaync";
              format = " $icon {$notification_count|0} ";
            }
          ]
          ++ cfg.extraBlocks;
      };

    i3status-rust = pkgs.symlinkJoin {
      name = "i3status-rust";
      paths = [(pkgs.unstable.i3status-rust.override {withNotmuch = false;})];
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
