{
  lib,
  config,
  ...
}: {
  config = {
    boot.kernelModules = ["kvm-amd"];

    hardware = {
      cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
      graphics.extraPackages = with pkgs; [
        libvdpau-va-gl # VDPAU frontend for VA-API backend.
      ];
    };
  };
}
