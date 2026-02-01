{
  pkgs,
  lib,
  config,
  atGmail,
  ...
}: let
  frigatePackage = config.services.frigate.package;
  createGo2rtcConfig = "${frigatePackage.src}/docker/main/rootfs/usr/local/go2rtc/create_config.py";
in {
  services.go2rtc.enable = true;

  services.mosquitto = {
    enable = true;
    listeners = [
      {
        acl = ["pattern readwrite #"];
        omitPasswordAuth = true;
        settings.allow_anonymous = true;
      }
    ];
  };

  services.frigate = {
    enable = true;
    checkConfig = false;
    hostname = "tin.orkhon-mohs.ts.net";

    settings = {
      cameras = {
        living_room = {
          enabled = true;
          ffmpeg = {
            inputs = [
              {
                path = "rtsp://admin:{FRIGATE_CAMERAS_PASSWORD}@${config.home.devices.camera_living_room.ip}:554/Preview_01_main";
                roles = ["detect"];
              }
            ];
          };
          detect = {
            width = 1280;
            height = 720;
          };
          motion.mask = [
            "0.652,0.116,0.859,0.231,0.83,0.476,0.647,0.337" # TV
            "0.375,0.935,0.375,1,0,1,0,0.935" # Timestamp
          ];
          onvif = {
            host = config.home.devices.camera_living_room.ip;
            port = 8000;
            user = "admin";
            password = "{FRIGATE_CAMERAS_PASSWORD}";
          };
        };
      };

      detect.enabled = true;

      detectors = {
        ov = {
          type = "openvino";
          device = "GPU";
        };
      };

      face_recognition = {
        enabled = true;
        model_size = "large";
      };

      ffmpeg = {
        path = "${pkgs.jellyfin-ffmpeg}";
        hwaccel_args = "preset-intel-qsv-h265";
        output_args = {
          record = "preset-record-generic-audio-copy";
        };
      };

      go2rtc = {
        streams = {
          living_room = [
            "rtsp://admin:{FRIGATE_CAMERAS_PASSWORD}@${config.home.devices.camera_living_room.ip}:554/Preview_01_main"
          ];
        };
        webrtc = {
          candidates = [
            "100.64.0.0/10:8555" # Tailscale IP
            "192.168.10.1:8555" # LAN IP
            "stun:8555"
          ];
        };
      };

      live = {
        height = 2160;
        quality = 1;
      };

      model = {
        model_type = "yolo-generic";
        input_dtype = "float";
        width = 320;
        height = 320;
        input_tensor = "nchw";
        # TODO: Make this declarative.
        path = "/etc/models/yolov9-s-320.onnx";
        labelmap_path = "/etc/models/coco_80cl.txt";
      };

      mqtt = {
        enabled = true;
        host = "localhost";
      };

      notifications = {
        enabled = true;
        email = atGmail "bakhtiyarneyman";
      };

      record = {
        preview.quality = "very_high";
        enabled = true;
        # retain = {
        #   days = 0;
        #   mode = "all";
        # };
        alerts = {
          pre_capture = 10;
          post_capture = 10;
          retain = {
            days = 14;
            mode = "motion";
          };
        };
      };

      tls.enabled = true;
    };
  };

  systemd.services.frigate = {
    # Override the module's after=go2rtc.service since frigate must start first
    # to generate its config, which go2rtc's ExecStartPre reads to create go2rtc's config.
    after = lib.mkForce ["cameras-auth.service" "network.target"];
    requires = ["cameras-auth.service"];
    serviceConfig = {
      AmbientCapabilities = ["iHD" "CAP_PERFMON"];
      EnvironmentFile = ["/run/cameras-auth/env"];
    };
  };

  # Port 8971: external authenticated with TLS (frigate checks X-Server-Port header)
  # mkForce to override default listen directives; module adds 127.0.0.1:5000 via extraConfig
  services.nginx.virtualHosts.${config.services.frigate.hostname} = {
    listen = lib.mkForce [
      {
        addr = "100.127.84.38";
        port = 8971;
        ssl = true;
      }
    ];
    onlySSL = true;
    sslCertificate = "/etc/nixos/secrets/${config.services.frigate.hostname}.crt";
    sslCertificateKey = "/etc/nixos/secrets/${config.services.frigate.hostname}.key";
  };

  # Creates env file with camera secrets
  systemd.services.cameras-auth.serviceConfig = {
    Type = "oneshot";
    RuntimeDirectory = "cameras-auth";
    RuntimeDirectoryPreserve = "yes";
    # Environment variables must be prefixed with FRIGATE_ for Frigate to substitute them.
    ExecStart = pkgs.writeShellScript "cameras-auth" ''
      printf "FRIGATE_CAMERAS_PASSWORD=%s\n" "$(cat /etc/nixos/secrets/cameras.password)" > /run/cameras-auth/env
      chmod 600 /run/cameras-auth/env
      ${pkgs.acl}/bin/setfacl -m g:camera:r /run/cameras-auth/env
    '';
  };

  systemd.services.go2rtc = {
    after = ["frigate.service" "cameras-auth.service"];
    requires = ["cameras-auth.service"];
    partOf = ["frigate.service"];
    serviceConfig = {
      SupplementaryGroups = ["camera"];
      # Generate config from frigate's config with secrets substituted
      # + prefix runs as root (needed to read /run/frigate/frigate.yml)
      ExecStartPre =
        "+"
        + pkgs.writeShellScript "go2rtc-config" ''
          set -euo pipefail
          export PYTHONPATH="${frigatePackage.pythonPath}"
          export CONFIG_FILE="/run/frigate/frigate.yml"
          set -a
          source /run/cameras-auth/env
          set +a
          ${frigatePackage.python}/bin/python3 ${createGo2rtcConfig}
        '';
      ExecStart = lib.mkForce "${pkgs.go2rtc}/bin/go2rtc -config /dev/shm/go2rtc.yaml";
    };
  };

  users.groups.camera = {};

  users.users.frigate.extraGroups = ["camera"];
}
