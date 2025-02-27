{pkgs, ...}: {
  imports = [
    ../modules/namespaced-openvpn.nix
  ];

  config = {
    users = {
      users.root.hashedPassword = "$6$.9aOljbRDW00nl$vRfj6ZVwgWXLTw2Ti/I55ov9nNl6iQAqAuauCiVhoRWIv5txKFIb49FKY0X3dgVqE61rPOqBh8qQSk61P2lZI1";
      users.bakhtiyar.hashedPassword = "$6$.9aOljbRDW00nl$vRfj6ZVwgWXLTw2Ti/I55ov9nNl6iQAqAuauCiVhoRWIv5txKFIb49FKY0X3dgVqE61rPOqBh8qQSk61P2lZI1";
    };

    networking = {
      firewall = {
        trustedInterfaces = [
          "tailscale0"
        ];
        extraCommands = ''
          iptables --append nixos-fw \
            --source 172.28.14.0/24 \
            --jump ACCEPT
        '';
      };
      hosts = {
        "100.65.77.115" = ["iron-tailscale" "iron-initrd"];
        "100.126.205.61" = ["mercury-tailscale"];
      };
    };

    programs = {
      _1password.enable = true;
    };

    security.pam = {
      yubico = {
        enable = false;
        control = "required";
        debug = true;
        mode = "client";
        id = "99202";
      };
      services = {
        sshd.yubicoAuth = true;
      };
    };

    services = {
      openssh.knownHosts = {
        iron = {
          hostNames = ["iron-tailscale"];
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOeAfprNGrQ2RfrDT81UxfTD/GfnOwz8gPzGppNiTw40";
        };
        iron-initrd = {
          hostNames = ["iron-initrd"];
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJZsOTJo1rw8XwP0ErdkXlRnGY5A6C7NtO93IXht2lNT";
        };
        mercury = {
          hostNames = ["mercury-tailscale"];
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKSyMQogWih9Tk8cpckwxP6CLzJxZqtg+qdFbXYbF9Sc";
        };
      };

      tailscale.enable = true;
      i2p.enable = true;
      namespaced-openvpn.enable = true;
      onedrive.enable = true;
    };

    systemd.services.mount-sensitive = {
      enable = true;
      environment = {
        CRYFS_FRONTEND = "noninteractive";
        CRYFS_NO_UPDATE_CHECK = "true";
      };
      bindsTo = ["local-fs.target"];
      wantedBy = ["local-fs.target"];
      after = ["local-fs.target"];
      script = ''
        cat /etc/nixos/secrets/sensitive.passphrase |\
          ${pkgs.sudo}/bin/sudo \
          --user=bakhtiyar \
          ${pkgs.cryfs}/bin/cryfs \
            --foreground \
            /home/bakhtiyar/OneDrive/encrypted \
            /home/bakhtiyar/sensitive
      '';
      preStop = "kill -SIGTERM $MAINPID";
      postStop = "${pkgs.sudo}/bin/sudo ${pkgs.util-linux}/bin/umount -l /home/bakhtiyar/sensitive";
    };

    nix.settings.trusted-public-keys = [
      "iron-tailscale:Qz1cJrsuEhnOHXU/FDiv0kaEkdq0HI2vIy8qxDLubFw="
    ];
  };
}
