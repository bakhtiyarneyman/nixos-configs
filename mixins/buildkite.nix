{ pkgs, ... }:
{
  containers.buildkite = {
    autoStart = true;
    bindMounts = {
      "/secrets/buildkite".hostPath = "/etc/nixos/secrets/buildkite";
      "/secrets/buildkite-token".hostPath = "/etc/nixos/secrets/buildkite.token";
    };
    config = {
      nix = {
        extraOptions = ''
          extra-experimental-features = nix-command flakes
        '';
        settings.cores = 8;
        settings.max-jobs = 1;
        package = pkgs.nix;
      };
      programs.ssh.startAgent = true;
      services.buildkite-agents.neurasium = {
        hooks.environment = ''
          export PAGER=
        '';
        runtimePackages = [
          pkgs.bash
          pkgs.cachix
          pkgs.direnv
          pkgs.git
          pkgs.gnugrep
          pkgs.gnutar
          pkgs.gzip
          (pkgs.writeShellScriptBin "nix-env" ''
            exec ${pkgs.nix}/bin/nix-env "$@"
          '')
          (pkgs.writeShellScriptBin "nix-store" ''
            exec ${pkgs.nix}/bin/nix-store "$@"
          '')
          (pkgs.writeShellScriptBin "nix" ''
            exec ${pkgs.nix}/bin/nix --print-build-logs "$@"
          '')
        ];
        shell = "${pkgs.bash}/bin/bash -euo pipefail -c";
        tokenPath = "/secrets/buildkite-token";
        privateSshKeyPath = "/secrets/buildkite";
      };
      system.stateVersion = "23.11";
      systemd.user.services.add-ssh-key = {
        description = "Add SSH key to ssh-agent";
        wantedBy = [ "default.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScriptBin "add-ssh-key.sh" ''
            #!/usr/bin/env bash
            set -euo pipefail
            SSH_KEY = "/secrets/buildkite"
            if ! ${pkgs.openssh}/bin/ssh-add -l | ${pkgs.gnugrep}/bin/grep -q "$SSH_KEY"; then
              echo "Adding SSH key: $SSH_KEY"
              ${pkgs.openssh}/bin/ssh-add "$SSH_KEY"
            else
              echo "SSH key already added."
            fi
          '';
          RemainAfterExit = true;
        };
      };
      users.users.root.hashedPassword = "$6$.9aOljbRDW00nl$vRfj6ZVwgWXLTw2Ti/I55ov9nNl6iQAqAuauCiVhoRWIv5txKFIb49FKY0X3dgVqE61rPOqBh8qQSk61P2lZI1";
    };
    ephemeral = false;
  };
}
