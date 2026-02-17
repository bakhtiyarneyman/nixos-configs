{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.neolink;
  neolink = pkgs.callPackage ../pkgs/neolink.nix {};
  tomlFormat = pkgs.formats.toml {};

  cameraToToml = name: cam:
    lib.filterAttrs (_: v: v != null) (removeAttrs cam ["mac" "ip"])
    // {
      inherit name;
      address = cam.ip;
      password = "@PASSWORD@";
    };

  configToToml =
    removeAttrs cfg ["enable" "cameras" "mqtt"]
    // {cameras = lib.mapAttrsToList cameraToToml cfg.cameras;}
    // lib.optionalAttrs cfg.mqtt.enable {
      mqtt = removeAttrs cfg.mqtt ["enable"];
    };

  configFile = tomlFormat.generate "neolink.toml" configToToml;
in {
  options.services.neolink = with lib;
  with types; {
    enable = mkEnableOption "neolink RTSP bridge for Reolink cameras";

    bind = mkOption {
      type = str;
      default = "::";
      description = "Address to bind the RTSP server to.";
    };

    bind_port = mkOption {
      type = port;
      default = 1554;
      description = "Port for the RTSP server.";
    };

    cameras = mkOption {
      type = attrsOf (submodule {
        options = {
          mac = mkOption {
            type = str;
            description = "MAC address of the camera.";
          };
          ip = mkOption {
            type = str;
            description = "IP address of the camera.";
          };
          username = mkOption {
            type = str;
            default = "admin";
            description = "Username for the camera.";
          };
          uid = mkOption {
            type = nullOr str;
            default = null;
            description = "UID of the camera for discovery.";
          };
          push_notifications = mkOption {
            type = bool;
            default = false;
            description = "Enable Reolink cloud push notifications.";
          };
          buffer_duration = mkOption {
            type = ints.between 1 15000;
            default = 100;
            description = "Buffer duration in milliseconds (1-15000).";
          };
          pause = {
            on_disconnect = mkOption {
              type = bool;
              default = true;
              description = "Pause camera stream when no clients are connected.";
            };
            on_motion = mkOption {
              type = bool;
              default = false;
              description = "Pause camera stream on motion detection.";
            };
            motion_timeout = mkOption {
              type = numbers.nonnegative;
              default = 1.0;
              description = "Motion detection timeout in seconds.";
            };
            mode = mkOption {
              type = enum ["none" "black" "still" "test"];
              default = "none";
              description = "What to show when the stream is paused.";
            };
          };
        };
      });
      default = {};
      description = "Cameras to proxy.";
    };

    mqtt = {
      enable = mkEnableOption "MQTT integration";
      broker_addr = mkOption {
        type = str;
        default = "127.0.0.1";
        description = "MQTT broker address.";
      };
      port = mkOption {
        type = port;
        default = 1883;
        description = "MQTT broker port.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.neolink = {
      description = "Neolink RTSP bridge for Reolink cameras";
      wantedBy = ["multi-user.target"];
      after = ["cameras-auth.service" "network.target"];
      requires = ["cameras-auth.service"];

      serviceConfig = {
        DynamicUser = true;
        SupplementaryGroups = ["camera"];
        RuntimeDirectory = "neolink";
        StateDirectory = "neolink";
        Environment = ["HOME=/var/lib/neolink"];
        EnvironmentFile = ["/run/cameras-auth/env"];
        ExecStartPre = pkgs.writeShellScript "neolink-config" ''
          ${pkgs.gnused}/bin/sed "s/@PASSWORD@/$FRIGATE_CAMERAS_PASSWORD/g" ${configFile} > /run/neolink/neolink.toml
        '';
        ExecStart = "${neolink}/bin/neolink rtsp --config /run/neolink/neolink.toml";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
}
