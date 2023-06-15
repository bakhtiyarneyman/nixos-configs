{ pkgs, lib, config, ... }:
{
  config = {
    boot.kernelModules = [ "kvm-intel" ];

    hardware = {
      cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
      opengl.extraPackages = with pkgs; [
        intel-media-driver # LIBVA_DRIVER_NAME=iHD
        intel-compute-runtime
      ];
    };

    environment.systemPackages = with pkgs; [
      intel-gpu-tools
    ];

  };
}
