# Speech-to-text for Open WebUI on a Vulkan GPU; Open WebUI's built-in Whisper
# runs only on CPU or CUDA. Open WebUI keeps its STT engine in its database, so
# point it here in the admin Tools -> Audio settings: engine OpenAI, URL
# http://127.0.0.1:11436/v1, any non-empty API key.
{
  lib,
  options,
  pkgs,
  ...
}: {
  systemd.services.whisper-server = {
    description = "whisper.cpp speech-to-text server";
    wantedBy = ["multi-user.target"];
    # The dynamic user has no home, so RADV would otherwise recompile its
    # shaders on the first request after every start (~1 s).
    environment.XDG_CACHE_HOME = "%C/whisper-server";
    serviceConfig = {
      DynamicUser = true;
      CacheDirectory = "whisper-server";
      Restart = "on-failure";
      # q5_0 holds 866 MiB of VRAM. q8_0 holds ~300 MiB more and transcribes
      # no more accurately.
      ExecStart = lib.escapeShellArgs [
        "${pkgs.unstable.whisper-cpp-vulkan}/bin/whisper-server"
        "--model"
        (pkgs.fetchurl {
          url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin";
          hash = "sha256-OUIhcJzVrR9AxG5gMcphvOiJMebgiMGIKUxtWlX/p+I=";
        })
        "--host"
        "127.0.0.1"
        "--port"
        "11436"
        "--inference-path"
        "/v1/audio/transcriptions"
        # Decode the browser's webm/opus recordings with ffmpeg.
        "--convert"
        "--tmp-dir"
        "/tmp"
        "--language"
        "auto"
      ];
    };
  };

  services.open-webui.environment =
    options.services.open-webui.environment.default
    // {
      # whisper-server decodes webm itself, so skip Open WebUI's own ~0.5 s
      # webm-to-mp3 conversion per recording.
      BYPASS_PYDUB_PREPROCESSING = "True";
    };
}
