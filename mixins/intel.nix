{
  pkgs,
  lib,
  config,
  ...
}: {
  config = {
    boot.kernelModules = ["kvm-intel"];

    hardware = {
      cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
      graphics.extraPackages = with pkgs; [
        intel-media-driver # LIBVA_DRIVER_NAME=iHD
        # Tiger Lake and Alder Lake are both supported by non-legacy runtime and vpl-gpu-rt.
        intel-compute-runtime
        vpl-gpu-rt
      ];
    };

    environment.systemPackages = with pkgs; [
      intel-gpu-tools
    ];
  };
}
