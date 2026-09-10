{...}: {
  config = {
    programs.ssh.extraConfig = ''
      Host iron-builder
        HostName iron-tailscale
        HostKeyAlias iron-tailscale
        ConnectTimeout 5
    '';

    nix = {
      buildMachines = [
        {
          hostName = "iron-builder";
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
