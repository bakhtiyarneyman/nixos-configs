{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.neolink;
  neolink = pkgs.callPackage ../pkgs/neolink.nix {};
  tomlFormat = pkgs.formats.toml {};

  cameraList =
    lib.mapAttrsToList (name: cam:
      {
        inherit name;
        inherit (cam) username address push_notifications;
        password = "@PASSWORD@";
      }
      // lib.optionalAttrs (cam.uid != null) {inherit (cam) uid;})
    cfg.cameras;

  configFile = tomlFormat.generate "neolink.toml" (
    {
      bind = cfg.bind;
      bind_port = cfg.port;
      cameras = cameraList;
    }
    // lib.optionalAttrs cfg.mqtt.enable {
      mqtt = {
        broker_addr = cfg.mqtt.broker_addr;
        port = cfg.mqtt.port;
      };
    }
  );
in {
  options.services.neolink = with lib;
  with types; {
    enable = mkEnableOption "neolink RTSP bridge for Reolink cameras";

    bind = mkOption {
      type = str;
      default = "0.0.0.0";
      description = "Address to bind the RTSP server to.";
    };

    port = mkOption {
      type = port;
      default = 1554;
      description = "Port for the RTSP server.";
    };

    cameras = mkOption {
      type = attrsOf (submodule {
        options = {
          address = mkOption {
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
