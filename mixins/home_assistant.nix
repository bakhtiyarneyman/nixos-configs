{pkgs, ...}: {
  config.services = {
    home-assistant = {
      enable = true;
      package = pkgs.unstable.home-assistant;
      extraPackages = python3Packages:
        with python3Packages; [
          aiohomekit
          aiolifx
          aiolifx-effects
          aiolifx-themes
          androidtvremote2
          brother
          getmac
          govee-ble
          gtts
          openai
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
        ];
      config = {
        default_config = {};
        automation = "!include automations.yaml";
        scene = "!include scenes.yaml";
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
      };
      faster-whisper.servers.listen = {
        enable = true;
        uri = "tcp://0.0.0.0:10300";
        language = "en";
        model = "small.en";
      };
      piper.servers.speak = {
        enable = true;
        uri = "tcp://0.0.0.0:10200";
        voice = "en_US-amy-medium";
      };
    };
  };
}
