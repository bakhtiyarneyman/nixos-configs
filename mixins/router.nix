{
  pkgs,
  lib,
  config,
  ...
}: {
  config = let
    toMac = last: "a8:b8:e0:04:fa:6${last}";
    wanMac = toMac "b";
    lanMac = toMac "c";
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
      nameservers = ["127.0.0.1"];
      nftables = {
        enable = true;
        ruleset = let
          blockedDevices = lib.filterAttrs (_: dev: dev.wanBlocked) config.home.devices;
          blockedMacs = lib.mapAttrsToList (_: dev: dev.mac) blockedDevices;
          blockedRule = lib.optionalString (blockedMacs != []) ''
            ether saddr { ${lib.concatStringsSep ", " blockedMacs} } oifname "eth-wan" drop comment "Block internet access"
          '';
        in
          builtins.replaceStrings ["@BLOCKED_WAN@"] [blockedRule] (builtins.readFile ./router.nft);
      };
      useDHCP = lib.mkForce false;
    };

    services = {
      dnscrypt-proxy = {
        enable = true;
        settings = {
          listen_addresses = ["127.0.0.1:53" "192.168.10.1:53"];
          server_names = ["mullvad-doh"];
          # DNS stamp for Mullvad DoH (194.242.2.2). Regenerate with:
          # python3 -c "import base64,struct; d=bytes([0x02])+struct.pack('<Q',0x06)+bytes([11])+b'194.242.2.2'+bytes([0,15])+b'dns.mullvad.net'+bytes([10])+b'/dns-query'; print('sdns://'+base64.urlsafe_b64encode(d).decode().rstrip('='))"
          static.mullvad-doh.stamp = "sdns://AgYAAAAAAAAACzE5NC4yNDIuMi4yAA9kbnMubXVsbHZhZC5uZXQKL2Rucy1xdWVyeQ";
        };
      };

      hostapd = {
        enable = true;
        radios = let
          channel = 149; # The other channel that works is 36. Everything else requires radar detection. 149 also has better dBm.
          network = {
            authentication = {
              saePasswordsFile = "/etc/nixos/secrets/yurdoba6.password";
              pairwiseCiphers = [
                "CCMP"
                "CCMP-256"
                "GCMP"
                "GCMP-256"
              ];
            };
            ssid = "yurdoba6";
          };
        in {
          wlp0s13f0u2 = {
            band = "5g"; # "6g" for WiFi 6E.
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
        wireguard_bypass = 200; # For WireGuard tunnel packets to bypass the VPN default route.
      };

      links = let
        rename = mac: name: {
          matchConfig = {
            PermanentMACAddress = mac;
            Type = "ether";
          };
          linkConfig.Name = "eth-${name}";
        };
      in {
        "10-eth-wan" = rename wanMac "wan";
        "20-eth-lan" = rename lanMac "lan";
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
          dhcpServerStaticLeases =
            lib.mapAttrsToList (name: dev: {
              MACAddress = dev.mac;
              Address = dev.ip;
            })
            config.home.devices;
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
          matchConfig.Name = "eth-lan";
          bridge = ["lan-tenant"];
          linkConfig.RequiredForOnline = "no";
        };

        "20-wan" = {
          linkConfig.RequiredForOnline = "routable";
          matchConfig.Name = "eth-wan";
          networkConfig = {
            DHCP = "yes";
            IPv6AcceptRA = "yes";
            DHCPPrefixDelegation = "yes";
          };
          routes = [
            # Reject localhost-destined traffic in lan table so it's handled locally
            {
              Source = "192.168.0.0/16";
              Destination = "127.0.0.1";
              Table = "lan";
              Type = "throw";
            }
            # Give LAN clients internet access via ISP, independent of VPN state
            {
              Source = "192.168.0.0/16";
              Gateway = "_dhcp4";
              Table = "lan";
            }
            # Provide a VPN-free path for marked packets (WireGuard/Tailscale tunnel establishment)
            {
              Gateway = "_dhcp4";
              Table = "wireguard_bypass";
            }
            # Allow DNS-over-HTTPS to Mullvad even when VPN is down (killswitch bypass)
            {
              Destination = "194.242.2.2";
              Gateway = "_dhcp4";
            }
          ];
          routingPolicyRules = [
            {
              FirewallMark = 51820; # route WireGuard tunnel packets via WAN
              Table = "wireguard_bypass";
              Priority = 100;
            }
            {
              FirewallMark = 524288; # 0x80000 - Tailscale's internal bypass mark
              Table = "wireguard_bypass";
              Priority = 102;
            }
          ];
        };
      };
    };
  };
}
