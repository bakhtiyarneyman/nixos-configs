{
  pkgs,
  machineName,
  ...
}: {
  imports = [
    ../modules/namespaced-openvpn.nix
  ];

  config = {
    boot.initrd.network.access.unlockOnly = true;

    users = {
      users.root.hashedPassword = "$6$kk14WW519ZVXvG5u$jI0cFAwRdko9K3LnHzMpYTriPLI.d17JCbfmR/QubRpjNlFNj6xUbg8Pv10w.LQRSIZqifGu5JV0uT2R7AaHs/";
      users.bakhtiyar.hashedPassword = "$6$5TwQDWuZT9WcJ4f7$yWDB9FXONsV4dTcIIf2SY3N.U56lDOL/t.PQPJOF5BmOFCTDyxIdPJeLiuC.u/9Mx6hKGQStuByi/zTh9N2Fc1";
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
      tailscale.enable = true;
      i2p.enable = true;
      namespaced-openvpn.enable = true;
      syncthing = {
        enable = true;
        key = "/etc/nixos/secrets/${machineName}.syncthing.secret-key.pem";
        cert = "/etc/nixos/secrets/${machineName}.syncthing.public-key.pem";
        settings = {
          devices = let
            mkDevice = name: id: {
              "${name}" = {
                id = id;
                name = name;
                address = "tcp://${name}:22000";
              };
            };
          in
            {}
            // mkDevice "iron" "3BDA4VS-QOLWHD3-2IYBEWR-A7KLWHI-AMQWEVP-ASGQSIS-HGGDXBI-T36EXAO"
            // mkDevice "mercury" "U2GZE3M-HHXAVHB-WRB7OIY-GM6W4EJ-PZVRPNA-SIBX4C4-MZ7PRRA-UXMGYQR"
            // mkDevice "lithium" "PVF44S6-X47TD2M-FXJNTXN-DDZBIXW-FQEHVTU-NRJQLKL-IVREOR4-LFMOMAO";
          folders = {
            "sync" = {
              path = "/home/bakhtiyar/sync";
              devices = ["iron" "mercury" "lithium"];
            };
          };
          gui = {
            user = "bakhtiyar";
            password = "$2a$10$.WS3YI4AUencLTTke3bgDOUb6q0qInVOPjSJysDGP2YgrGCI3KpNG";
          };
        };
      };
    };
  };
}
