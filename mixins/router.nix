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

    services = {
      dnsmasq = {
        enable = true;
        alwaysKeepRunning = true;
        settings = {
          server = mullvad_dns;
        };
      };

      hostapd = {
        enable = true;
        radios = let
          channel = 149; # The other channel that works is 36. Everything else requires radar detection. 149 also has better dBm.
          network = {
            authentication = {
              saePasswordsFile = "/etc/nixos/secrets/yurdoba.password";
              pairwiseCiphers = [
                "CCMP"
                "CCMP-256"
                "GCMP"
                "GCMP-256"
              ];
            };
            ssid = "yurdoba";
          };
        in {
          wlp0s13f0u2 = {
            band = "5g"; # "5g" for WiFi 6.
            inherit channel;
            countryCode = "US";
            networks.wlp0s13f0u2 = lib.recursiveUpdate network {
              authentication = {
                mode = "wpa3-sae";
                pairwiseCiphers = [
                  "CCMP"
                  "CCMP-256"
                  "GCMP"
                  "GCMP-256"
                ];
              };
              settings = {
                ieee80211w = 2;
              };
            };
            settings = {
              # beacon_int = 100;
              bridge = "lan-tenant";
              bss_load_update_period = 50;
              # country3 = "0x49";
              # dtim_period = 2;
              # he_6ghz_max_mpdu = 2;
              # he_6ghz_rx_ant_pat = 1;
              # he_6ghz_tx_ant_pat = 1;
              # he_6ghz_reg_pwr_type = 0;
              he_bss_color = 38; # Must be unique for each AP.
              he_mu_edca_ac_be_aci = 0;
              he_mu_edca_ac_be_aifsn = 8;
              he_mu_edca_ac_be_ecwmax = 10;
              he_mu_edca_ac_be_ecwmin = 9;
              he_mu_edca_ac_be_timer = 255;
              he_mu_edca_ac_bk_aci = 1;
              he_mu_edca_ac_bk_aifsn = 15;
              he_mu_edca_ac_bk_ecwmax = 10;
              he_mu_edca_ac_bk_ecwmin = 9;
              he_mu_edca_ac_bk_timer = 255;
              he_mu_edca_ac_vi_aci = 2;
              he_mu_edca_ac_vi_aifsn = 5;
              he_mu_edca_ac_vi_ecwmax = 7;
              he_mu_edca_ac_vi_ecwmin = 5;
              he_mu_edca_ac_vi_timer = 255;
              he_mu_edca_ac_vo_aci = 3;
              he_mu_edca_ac_vo_aifsn = 5;
              he_mu_edca_ac_vo_ecwmax = 7;
              he_mu_edca_ac_vo_ecwmin = 5;
              he_mu_edca_ac_vo_timer = 255;
              he_mu_edca_qos_info_param_count = 0;
              he_mu_edca_qos_info_q_ack = 0;
              he_mu_edca_qos_info_queue_request = 0;
              he_mu_edca_qos_info_txop_request = 0;
              he_oper_centr_freq_seg0_idx = channel + 6;
              max_num_sta = 16;
              okc = 1;
              # op_class = 133;
              skip_inactivity_poll = 1;
              uapsd_advertisement_enabled = 1;
              vht_oper_centr_freq_seg0_idx = channel + 6;
              wme_enabled = 1;
            };
            wifi4 = {
              enable = true;
              capabilities = [
                "GF"
                "HT40-"
                "HT40+"
                "LDPC"
                "MAX-AMSDU-7935"
                "RX-STBC1"
                "SHORT-GI-20"
                "SHORT-GI-40"
                "TX-STBC"
              ];
            };
            wifi5 = {
              enable = true;
              capabilities = [
                "MAX-MPDU-11454"
                "RXLDPC"
                "SHORT-GI-80"
                "TX-STBC-2BY1"
                "SU-BEAMFORMEE"
                "MU-BEAMFORMEE"
                "RX-ANTENNA-PATTERN"
                "TX-ANTENNA-PATTERN"
                "RX-STBC-1"
                "BF-ANTENNA-4"
                "MAX-A-MPDU-LEN-EXP7"
              ];
              operatingChannelWidth = "80";
            };
            wifi6 = {
              enable = true;
              operatingChannelWidth = "80";
              singleUserBeamformer = true;
              singleUserBeamformee = true;
              multiUserBeamformer = true;
            };
          };
        };
      };

      # Alternatively, resolved could have been configured to start after dnsmasq.
      resolved.extraConfig = ''
        DNSStubListener=no
      '';
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
            DNS = [
              "192.168.10.1"
              "fd00:10::1"
            ];
          };
          linkConfig.RequiredForOnline = "no";
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
