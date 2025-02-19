{
  pkgs,
  hostName,
  ...
}: {
  config.services = {
    home-assistant = {
      enable = true;
      package = pkgs.unstable.home-assistant;
      customComponents = builtins.attrValues {
        openrgb-ha = pkgs.callPackage ../pkgs/home-assistant/openrgb-ha.nix {};
        xiaomi_cloud_map_extractor = pkgs.callPackage ../pkgs/home-assistant/xiaomi_cloud_map_extractor.nix {};
      };
      extraPackages = python3Packages:
        builtins.attrValues {
          inherit
            (python3Packages)
            aiohomekit
            aiohttp-fast-zlib
            aiolifx
            aiolifx-effects
            aiolifx-themes
            androidtvremote2
            brother
            getmac
            govee-ble
            gtts
            ibeacon-ble
            led-ble
            openai
            openrgb-python
            pyatv
            pychromecast
            pyipp
            python-otbr-api
            python-roborock
            radios
            tuya-device-sharing-sdk
            vacuum-map-parser-base
            wakeonlan
            wyoming
            yalexs-ble
            ;
        }
        ++ python3Packages.aiohttp-fast-zlib.optional-dependencies.isal
        ++ python3Packages.aiohttp-fast-zlib.optional-dependencies.zlib_ng;
      config = {
        default_config = {};
        automation = "!include automations.yaml";
        scene = "!include scenes.yaml";
        http = {
          ssl_certificate = "/etc/nixos/secrets/${hostName}.orkhon-mohs.ts.net.crt";
          ssl_key = "/etc/nixos/secrets/${hostName}.orkhon-mohs.ts.net.key";
        };
        camera = [
          {
            platform = "xiaomi_cloud_map_extractor";
            host = "!secret xiaomi_vacuum_host";
            token = "!secret xiaomi_vacuum_token";
            username = "!secret xiaomi_cloud_username";
            password = "!secret xiaomi_cloud_password";
            draw = ["all"];
            attributes = ["calibration_points"];
          }
        ];
      };
    };

    wyoming = {
      openwakeword = {
        enable = true;
        customModelsDirectories = [
          "/etc/nixos/models/openwakeword"
        ];
        preloadModels = [
          "duh_meenuh"
        ];
        extraArgs = [
          "--debug"
        ];
      };
      faster-whisper.servers.listen = {
        enable = true;
        uri = "tcp://0.0.0.0:10300";
        language = "en";
        model = "small-int8";
        extraArgs = [
          "--debug"
        ];
      };
      piper.servers.speak = {
        enable = true;
        uri = "tcp://0.0.0.0:10200";
        voice = "en_US-lessac-high";
        extraArgs = [
          "--debug"
        ];
      };
    };
  };
}
