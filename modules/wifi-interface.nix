{lib, ...}: {
  options.networking = with lib;
  with types; {
    wifiInterface = mkOption {
      type = nullOr str;
      default = null;
      description = "An interface from /sys/class/net";
    };
    kernelModules = mkOption {
      type = listOf str;
      default = [];
      description = "Kernel modules to load for wifi";
    };
  };
}
