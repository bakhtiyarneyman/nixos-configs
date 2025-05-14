{
  pkgs,
  lib,
  ...
}: {
  config = let
    mullvad_dns = [
      "194.242.2.2"
      "2a07:e340::2"
    ];
  in {
    boot.kernel.sysctl = {
      "net.ipv6.conf.all.forwarding" = 1;
      "net.ipv4.ip_forward" = 1;
    };

    environment.systemPackages = with pkgs; [
      tcpdump
    ];

    networking = {
      firewall.enable = lib.mkForce false;
      iproute2.enable = true;
      nameservers = mullvad_dns;
      nftables = {
        enable = true;
        rulesetFile = ./router.nft;
        flattenRulesetFile = true;
      };
      useDHCP = lib.mkForce false;
    };

    systemd.network = {
      enable = true;

      config.routeTables = {
        lan = 100;
      };

      netdevs = {
        "10-lan-tenant".netdevConfig = {
          Name = "lan-tenant";
          Kind = "bridge";
        };
      };

      networks = {
        "10-lan" = {
          matchConfig.Name = "lan-tenant";
          networkConfig = {
            Address = [
              "192.168.10.1/24"
              "fd00:10::1/64"
            ];
            IPv6SendRA = "yes";
            DHCPServer = "yes";
          };
          dhcpServerConfig = {
            PoolOffset = 20;
            PoolSize = 150;
            EmitDNS = "yes";
            DNS = mullvad_dns;
          };
          routes = [
            {
              Source = "192.168.0.0/16";
              Destination = "192.168.0.0/16";
              Table = "lan";
              Type = "throw";
            }
          ];
          routingPolicyRules = [
            {
              IncomingInterface = "lan-tenant";
              Table = "lan";
              Priority = 6000;
            }
          ];
        };

        "11-lan-ethernet" = {
          matchConfig.Name = "enp3s0";
          bridge = ["lan-tenant"];
          linkConfig.RequiredForOnline = "no";
        };

        "12-lan-wifi" = {
          matchConfig.Name = "wlp0s13f0u2";
          bridge = ["lan-tenant"];
          linkConfig.RequiredForOnline = "no";
        };

        "20-wan" = {
          linkConfig.RequiredForOnline = "routable";
          matchConfig.Name = "enp2s0";
          networkConfig = {
            DHCP = "yes";
            IPv6AcceptRA = "yes";
            DHCPPrefixDelegation = "yes";
          };
          routes = [
            {
              Source = "192.168.0.0/16";
              Destination = "127.0.0.1";
              Table = "lan";
              Type = "throw";
            }
            {
              Source = "192.168.0.0/16";
              Gateway = "_dhcp4";
              Table = "lan";
            }
          ];
        };
      };
    };
  };
}
