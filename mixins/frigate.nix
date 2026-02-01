{
  pkgs,
  lib,
  config,
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
            "192.168.10.1:8555"
            "100.64.0.0/10"
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
        host = "localhost";
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
    # Override the module's after=go2rtc.service since we need frigate to start first
    # to generate its config, which go2rtc-config then reads to create go2rtc's config.
    after = lib.mkForce ["cameras-auth.service" "network.target"];
    requires = ["cameras-auth.service"];
    serviceConfig = {
      AmbientCapabilities = ["iHD" "CAP_PERFMON"];
      EnvironmentFile = ["/run/cameras-auth/env"];
    };
  };

  services.nginx.virtualHosts.${config.services.frigate.hostname}.listen = lib.mkForce [
    # { addr = "127.0.0.1"; port = 5000; }
    {
      # This is wrong.
      addr = "100.127.84.38";
      port = 5000;
    }
  ];

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

  # Generates go2rtc config from frigate config with secrets substituted
  systemd.services.go2rtc-config = {
    after = ["frigate.service" "cameras-auth.service"];
    requires = ["cameras-auth.service"];
    before = ["go2rtc.service"];
    requiredBy = ["go2rtc.service"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "go2rtc-config" ''
        set -euo pipefail
        export PYTHONPATH="${frigatePackage.pythonPath}"
        export CONFIG_FILE="/run/frigate/frigate.yml"
        set -a
        source /run/cameras-auth/env
        set +a
        ${frigatePackage.python}/bin/python3 ${createGo2rtcConfig}
      '';
    };
  };

  systemd.services.go2rtc.serviceConfig = {
    SupplementaryGroups = ["camera"];
    ExecStart = lib.mkForce "${pkgs.go2rtc}/bin/go2rtc -config /dev/shm/go2rtc.yaml";
  };

  users.groups.camera = {};

  users.users.frigate.extraGroups = ["camera"];
}
