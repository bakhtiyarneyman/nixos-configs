{
  pkgs,
  hostName,
  ...
}: {
  config = {
    services = {
      home-assistant = {
        enable = true;
        package = pkgs.unstable.home-assistant;
        customComponents = builtins.attrValues {
          openrgb-ha = pkgs.callPackage ../pkgs/home-assistant/openrgb-ha.nix {};
          xiaomi_cloud_map_extractor = pkgs.callPackage ../pkgs/home-assistant/xiaomi_cloud_map_extractor.nix {};
          extended_openai_conversation = pkgs.callPackage ../pkgs/home-assistant/extended_openai_conversation.nix {};
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
              jellyfin-apiclient-python
              led-ble
              openai
              openrgb-python
              oralb-ble
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
          logger.logs = {
            "custom_components.extended_openai_conversation" = "info";
            "homeassistant.components.openai_conversation" = "info";
          };
        };
      };

      wyoming = {
        openwakeword = {
          enable = true;
          package = pkgs.unstable.wyoming-openwakeword;
          customModelsDirectories = [
            "/etc/nixos/models/openwakeword"
          ];
          threshold = 0.2;
          preloadModels = [
            "duh_meenuh"
          ];
          extraArgs = [
            "--debug"
          ];
        };
        faster-whisper = {
          package = pkgs.unstable.wyoming-faster-whisper;
          servers.small-int8 = {
            enable = true;
            uri = "tcp://0.0.0.0:10300";
            language = "en";
            model = "small-int8";
            extraArgs = [
              "--debug"
              "--compute-type=int8"
            ];
          };
        };
        piper = {
          package = pkgs.unstable.wyoming-piper;
          servers.speak = {
            enable = true;
            uri = "tcp://0.0.0.0:10200";
            voice = "en_US-lessac-high";
            extraArgs = [
              "--debug"
            ];
          };
        };
      };
    };

    systemd.services.wyoming-faster-whisper-small-int8.environment = {
      # Only good for iron.
      "OMP_NUM_THREADS" = "16";
    };
  };
}
