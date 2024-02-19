{pkgs, ...}: {
  config = {
    environment.systemPackages = with pkgs; [
      edac-utils
      rasdaemon
    ];
    hardware.rasdaemon.enable = true;
  };
}
