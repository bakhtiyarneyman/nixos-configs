{
  imports = [
    ./namespaced-openvpn.nix
  ];

  config = {
    users = {
      users.root.hashedPassword = "$6$.9aOljbRDW00nl$vRfj6ZVwgWXLTw2Ti/I55ov9nNl6iQAqAuauCiVhoRWIv5txKFIb49FKY0X3dgVqE61rPOqBh8qQSk61P2lZI1";
      users.bakhtiyar.hashedPassword = "$6$.9aOljbRDW00nl$vRfj6ZVwgWXLTw2Ti/I55ov9nNl6iQAqAuauCiVhoRWIv5txKFIb49FKY0X3dgVqE61rPOqBh8qQSk61P2lZI1";
    };

    networking = {
      firewall.trustedInterfaces = [ "tailscale0" ];
      hosts = {
        "100.65.77.115" = [ "iron-tailscale" ];
        "100.126.205.61" = [ "kevlar-tailscale" ];
      };
    };

    services = {
      openssh = {
        enable = true;
        knownHosts = {
          iron = {
            hostNames = [ "iron-tailscale" "100.65.135.29" ];
            publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOeAfprNGrQ2RfrDT81UxfTD/GfnOwz8gPzGppNiTw40";
          };
          kevlar = {
            hostNames = [ "kevlar-tailscale" "100.126.205.61" ];
            publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKSyMQogWih9Tk8cpckwxP6CLzJxZqtg+qdFbXYbF9Sc";
          };
        };
      };

      tailscale.enable = true;
      i2p.enable = true;
      namespaced-openvpn.enable = true;
    };

    nix.settings.trusted-public-keys = [
      "iron-tailscale:Qz1cJrsuEhnOHXU/FDiv0kaEkdq0HI2vIy8qxDLubFw="
    ];
  };
}
