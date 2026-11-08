{
  config,
  lib,
  pkgs,
  ...
}: {
  config = {
    boot.kernelModules = ["kvm-amd"];

    environment.systemPackages = [pkgs.amdgpu_top];

    hardware = {
      cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
      graphics.extraPackages = with pkgs; [
        libvdpau-va-gl # VDPAU frontend for VA-API backend.
      ];
    };

    nixpkgs.overlays = [
      (self: super: {
        # amdgpu_top stops refreshing VRAM and sensors once it judges the dGPU
        # idle, and resumes only when it sees a process using the GPU via
        # /proc/<pid>/fd and fdinfo. Those are unreadable for processes of
        # other users (e.g. the ollama service), so their GPU work stays
        # invisible and the stats remain frozen until restart. AGT_NO_DROP=1
        # disables the idle freeze.
        amdgpu_top = self.symlinkJoin {
          name = "amdgpu_top-no-drop";
          paths = [super.amdgpu_top];
          nativeBuildInputs = [self.makeWrapper];
          postBuild = ''
            wrapProgram $out/bin/amdgpu_top --set AGT_NO_DROP 1
          '';
        };
      })
    ];
  };
}
