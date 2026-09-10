{...}: {
  config = {
    nix = {
      buildMachines = [
        {
          hostName = "iron-tailscale";
          system = "x86_64-linux";
          protocol = "ssh-ng";
          sshUser = "nix-remote-builder";
          sshKey = "/etc/ssh/ssh_host_ed25519_key";
          maxJobs = 32;
          speedFactor = 10;
          supportedFeatures = [
            "nixos-test"
            "benchmark"
            "big-parallel"
            "kvm"
          ];
          mandatoryFeatures = [];
        }
      ];
      distributedBuilds = true;
    };
  };
}
