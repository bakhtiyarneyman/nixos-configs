{
  hostName,
  lib,
  pkgs,
  ...
}: let
  containerName = "neurasium";
  agentName = "builder";
  buildkiteAgentName = "buildkite-agent-${agentName}";
  buildkiteUid = 986;
  buildkiteGid = 982;
  makeUserAndGroup = name: uid: gid: {
    users."${name}" = {
      uid = uid;
      group = name;
    };
    groups."${name}".gid = gid;
  };
  nix = pkgs.unstable.nix;

  # Shared definitions of users and groups for file permissions.
  users =
    makeUserAndGroup buildkiteAgentName buildkiteUid buildkiteGid;
in {
  config = {
    containers."${containerName}" = {
      autoStart = true;
      additionalCapabilities = [
        # Work around issue with spaces. https://github.com/NixOS/nixpkgs/issues/198857
        ''all" --system-call-filter="add_key keyctl bpf''
      ];

      allowedDevices = [
        {
          node = "/dev/fuse";
          modifier = "rwm";
        }
        {
          node = "/dev/console";
          modifier = "rwm";
        }
      ];

      bindMounts = {
        "/secrets/buildkite.pat".hostPath = "/etc/nixos/secrets/neurasium/buildkite.pat";
        "/secrets/buildkite.token".hostPath = "/etc/nixos/secrets/neurasium/buildkite.token";
        "/dev/fuse" = {
          hostPath = "/dev/fuse";
          isReadOnly = false;
        };
      };

      config = {
        config,
        pkgs,
        ...
      }: {
        boot.isContainer = true;

        networking = {
          firewall = {
            enable = true;
            logRefusedConnections = true;
            checkReversePath = "loose";
          };
          hostName = "${hostName}-${containerName}";
        };

        nix = {
          extraOptions = ''
            extra-experimental-features = nix-command flakes
          '';
          settings.cores = 8;
          settings.max-jobs = 1;
          package = nix;
        };

        programs = {
          git = {
            enable = true;
            config = {
              credential.helper = "store";
            };
            lfs.enable = true;
          };
        };

        services = {
          gerrit = {
            enable = true;
            serverId = "iron-${containerName}";
          };

          buildkite-agents."${agentName}" = {
            hooks.environment = ''
              export PAGER=
            '';
            runtimePackages = [
              pkgs.bash
              pkgs.direnv
              pkgs.docker
              pkgs.git
              pkgs.git-lfs
              pkgs.gnugrep
              pkgs.gnutar
              pkgs.gzip
              (pkgs.writeShellScriptBin "nix-env" ''
                exec ${nix}/bin/nix-env "$@"
              '')
              (pkgs.writeShellScriptBin "nix-store" ''
                exec ${nix}/bin/nix-store "$@"
              '')
              (pkgs.writeShellScriptBin "nix" ''
                exec ${nix}/bin/nix --print-build-logs "$@"
              '')
            ];
            shell = "${pkgs.bash}/bin/bash -euo pipefail -c";
            tokenPath = "/secrets/buildkite.token";
          };
        };

        system.stateVersion = "23.11";

        systemd.services = {
          "${buildkiteAgentName}" = {
            preStart = let
              userDir = config.services.buildkite-agents.${agentName}.dataDir;
              lfsCacheDir = "${userDir}/.cache/lfs";
            in ''
              set -euo pipefail
              export BUILDKITE_PAT=$(cat /secrets/buildkite.pat)
              echo \
                "https://neurasium-buildkite-agent:$BUILDKITE_PAT@github.com" \
                > "${userDir}/.git-credentials"
              mkdir -p ${lfsCacheDir}
              cat > ${userDir}/.gitconfig <<EOF
              [lfs]
              storage = ${lfsCacheDir}
              EOF
            '';
          };
          docker.path = [pkgs.fuse-overlayfs];
        };

        users =
          users
          // {users.${buildkiteAgentName}.extraGroups = ["docker"];};

        virtualisation.docker.enable = true;
      };

      ephemeral = false;
      # hostBridge = bridgeName;
      hostAddress = "192.168.100.10";
      localAddress = "192.168.100.11";
      privateNetwork = true;
    };

    networking = {
      nat = {
        internalInterfaces = ["ve-+"];
        enable = true;
        enableIPv6 = true;
      };
      useDHCP = lib.mkDefault true;
    };

    inherit users;
  };
}
