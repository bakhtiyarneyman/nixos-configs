{
  pkgs,
  config,
  ...
}: let
  uid = 986;
  gid = 982;
in {
  containers.neurasium = {
    autoStart = true;

    bindMounts = {
      "/secrets/buildkite.pat".hostPath = "/etc/nixos/secrets/buildkite.pat";
      "/secrets/buildkite.token".hostPath = "/etc/nixos/secrets/buildkite.token";
    };

    ephemeral = false;

    config = let
      cfg = config.containers.neurasium.config;
    in {
      networking = {
        firewall = {
          enable = true;
          logRefusedConnections = true;
          checkReversePath = "loose";
        };
      };

      nix = {
        extraOptions = ''
          extra-experimental-features = nix-command flakes
        '';
        settings.cores = 8;
        settings.max-jobs = 1;
        package = pkgs.nix;
      };

      programs = {
        git = {
          enable = true;
          config = {
            credential.helper = "store";
          };
        };
      };

      services = {
        gerrit = {
          enable = true;
          serverId = "iron-neurasium";
        };

        buildkite-agents.neurasium = {
          hooks.environment = ''
            export PAGER=
          '';
          runtimePackages = [
            pkgs.bash
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
          tokenPath = "/secrets/buildkite.token";
        };
      };

      system.stateVersion = "23.11";

      systemd.services.buildkite-agent-neurasium = {
        preStart = ''
          set -euo pipefail
          export BUILDKITE_PAT=$(cat /secrets/buildkite.pat)
          echo \
            "https://neurasium-buildkite-agent:$BUILDKITE_PAT@github.com" \
            > "${cfg.services.buildkite-agents.neurasium.dataDir}/.git-credentials"
        '';
      };

      users = {
        users.buildkite-agent-neurasium = {
          inherit uid;
        };
        groups.buildkite-agent-neurasium = {
          inherit gid;
        };
      };
    };
  };

  users = {
    users.buildkite-agent-neurasium = {
      inherit uid;
      group = "buildkite-agent-neurasium";
    };
    groups.buildkite-agent-neurasium = {
      inherit gid;
    };
  };
}
