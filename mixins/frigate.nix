{
  pkgs,
  lib,
  config,
  ...
}: {
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
                path = "rtsp://admin:{FRIGATE_RTSP_PASSWORD}@${config.home.devices.camera_living_room.ip}:554/Preview_01_main";
                roles = ["detect"];
              }
            ];
          };
          detect = {
            width = 1280;
            height = 720;
          };
          motion.mask = "0.652,0.116,0.859,0.231,0.83,0.476,0.647,0.337";
        };
      };

      detect.enabled = true;

      detectors = {
        ov = {
          type = "openvino";
          device = "GPU";
        };
      };
      ffmpeg = {
        path = "${pkgs.jellyfin-ffmpeg}";
        hwaccel_args = "preset-intel-qsv-h265";
      };

      go2rtc = {
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
    };
  };

  systemd.services.frigate.serviceConfig = {
    AmbientCapabilities = ["iHD" "CAP_PERFMON"];
    EnvironmentFile = ["/run/frigate-auth/env"];
  };

  services.nginx.virtualHosts.${config.services.frigate.hostname}.listen = lib.mkForce [
    # { addr = "127.0.0.1"; port = 5000; }
    {
      # This is wrong.
      addr = "100.127.84.38";
      port = 5000;
    }
  ];

  systemd.services.frigate-auth = {
    before = ["frigate.service"];
    requiredBy = ["frigate.service"];
    serviceConfig = {
      Type = "oneshot";
      RuntimeDirectory = "frigate-auth";
      RuntimeDirectoryPreserve = "yes";
      ExecStart = pkgs.writeShellScript "frigate-auth" ''
        printf "FRIGATE_RTSP_PASSWORD=%s\n" "$(cat /etc/nixos/secrets/camera_living_room.password)" > /run/frigate-auth/env
        chmod 600 /run/frigate-auth/env
        ${pkgs.acl}/bin/setfacl -m u:frigate:r /run/frigate-auth/env
      '';
    };
  };
}
