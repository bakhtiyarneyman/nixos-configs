{
  config,
  lib,
  pkgs,
  ...
}: {
  options.services.namespaced-openvpn = with lib;
  with types; {
    enable = mkEnableOption "Create a network network namespace using OpenVPN";
  };

  config = let
    resolv-conf = "${pkgs.openresolv}/bin/resolvconf";

    update-resolv-conf = pkgs.writeShellScriptBin "update-resolv-conf" ''
      # Used snippets of resolvconf script by Thomas Hood and Chris Hanson.
      # Licensed under the GNU GPL.  See /usr/share/common-licenses/GPL.
      #
      # Example envs set from openvpn:
      #
      #     foreign_option_1='dhcp-option DNS 193.43.27.132'
      #     foreign_option_2='dhcp-option DNS 193.43.27.133'
      #     foreign_option_3='dhcp-option DOMAIN be.bnc.ch'
      #

      [ -x /run/current-system/sw/bin/resolvconf ] || exit 0
      [ "$script_type" ] || exit 0
      [ "$dev" ] || exit 0

      split_into_parts()
      {
      	part1="$1"
      	part2="$2"
      	part3="$3"
      }

      case "$script_type" in
        up)
      	NMSRVRS=""
      	SRCHS=""
      	for optionvarname in $${!foreign_option_*} ; do
      		option="$${!optionvarname}"
      		echo "$option"
      		split_into_parts $option
      		if [ "$part1" = "dhcp-option" ] ; then
      			if [ "$part2" = "DNS" ] ; then
      				NMSRVRS="$${NMSRVRS:+$NMSRVRS }$part3"
      			elif [ "$part2" = "DOMAIN" ] ; then
      				SRCHS="$${SRCHS:+$SRCHS }$part3"
      			fi
      		fi
      	done
      	R=""
      	[ "$SRCHS" ] && R="search $SRCHS
      "
      	for NS in $NMSRVRS ; do
              	R="$${R}nameserver $NS
      "
      	done
      	echo -n "$R" | ${resolv-conf} -a "$${dev}.openvpn"
      	;;
        down)
      	${resolv-conf} -d "$${dev}.openvpn"
      	;;
      esac
    '';

    mullvad-conf = pkgs.writeText "mullvad.conf" ''
      client
      dev tun
      resolv-retry infinite
      nobind
      persist-key
      persist-tun
      verb 3
      remote-cert-tls server
      ping 10
      ping-restart 60
      sndbuf 524288
      rcvbuf 524288
      cipher AES-256-GCM
      tls-cipher TLS-DHE-RSA-WITH-AES-256-GCM-SHA384
      proto udp
      auth-user-pass /etc/nixos/secrets/mullvad_userpass.txt
      ca ${../mullvad/mullvad_ca.crt}
      tun-ipv6
      script-security 2
      up ${update-resolv-conf}/bin/update-resolv-conf
      down ${update-resolv-conf}/bin/update-resolv-conf
      fast-io
      remote-random
      remote 198.44.129.162 1302 # us-lax-ovpn-101
      remote 198.44.129.130 1302 # us-lax-ovpn-102
      remote 169.150.203.41 1302 # us-lax-ovpn-201
      remote 169.150.203.54 1302 # us-lax-ovpn-202
      remote 146.70.172.66 1302 # us-lax-ovpn-401
      remote 146.70.172.130 1302 # us-lax-ovpn-402
      remote 146.70.172.194 1302 # us-lax-ovpn-403
    '';
  in
    lib.mkIf config.services.namespaced-openvpn.enable {
      systemd.services.namespaced-openvpn = {
        description = "Network namespace using OpenVPN";
        wantedBy = ["multi-user.target"];
        requires = ["network-online.target"];
        after = ["network-online.target"];
        serviceConfig = {
          ExecStart = [
            "${pkgs.namespaced-openvpn}/bin/namespaced-openvpn --config ${mullvad-conf}"
          ];
          Restart = "on-failure";
        };
      };
    };
}
