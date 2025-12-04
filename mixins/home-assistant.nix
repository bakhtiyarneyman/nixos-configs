{
  config,
  machineName,
  pkgs,
  ...
}: {
  config = {
    environment.systemPackages = [config.services.home-assistant.package];
    services = {
      home-assistant = {
        enable = true;
        customComponents = let
          callPackage = config.services.home-assistant.package.python.pkgs.callPackage;
        in
          builtins.attrValues {
            openrgb-ha = callPackage ../pkgs/home-assistant/openrgb-ha.nix {};
            xiaomi_cloud_map_extractor = callPackage ../pkgs/home-assistant/xiaomi_cloud_map_extractor.nix {};
            extended_openai_conversation = callPackage ../pkgs/home-assistant/extended_openai_conversation.nix {};
          };
        customLovelaceModules = with pkgs.home-assistant-custom-lovelace-modules; [
          apexcharts-card
          atomic-calendar-revive
          bubble-card
          button-card
          card-mod
          decluttering-card
          hourly-weather
          light-entity-card
          mini-graph-card
          mini-media-player
          multiple-entity-row
          mushroom
          template-entity-row
          universal-remote-card
          weather-card
        ];
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
              colorlog
              elgato
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
              samsungctl
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
            ssl_certificate = "/etc/nixos/secrets/${machineName}.orkhon-mohs.ts.net.crt";
            ssl_key = "/etc/nixos/secrets/${machineName}.orkhon-mohs.ts.net.key";
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
          customModelsDirectories = [
            "/etc/nixos/models/openwakeword"
          ];
          threshold = 0.2;
          extraArgs = [
            "--debug"
          ];
        };
        faster-whisper = {
          servers.listener = {
            enable = true;
            uri = "tcp://0.0.0.0:10300";
            language = "en";
            model = "Systran/faster-whisper-base";
            extraArgs = [
              "--debug"
              "--compute-type=int8"
            ];
          };
        };
        piper = {
          servers.speaker = {
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
  };
}
