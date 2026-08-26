{
  config,
  lib,
  pkgs,
  ...
}: let
  targetUser = "bakhtiyar";
  yubicoAuthFile = "/etc/security/yubico/authorized_yubikeys";

  protectedServices = [
    "login"
    "swaylock"
    "vlock"
    "sudo"
    "doas"
    "polkit-1"
    "systemd-run0"
    "sshd"
    "su"
    "passwd"
    "chfn"
    "chsh"
  ];

  isLocalSession = pkgs.writeShellScript "pam-is-local-session" ''
    case "$PAM_SERVICE" in
      sshd)
        exit 1
        ;;
      login | gdm-password)
        [ -z "$PAM_RHOST" ]
        exit
        ;;
      swaylock | vlock | polkit-1)
        exit 0
        ;;
    esac

    remote="$(${pkgs.coreutils}/bin/timeout 2s ${config.systemd.package}/bin/loginctl show-session self --property=Remote --value 2>/dev/null)" || exit 1
    [ "$remote" = no ]
  '';

  mkUserSpecificAuth = serviceName: let
    unixOrder = config.security.pam.services.${serviceName}.rules.auth.unix.order;
  in {
    # Disable inherited alternatives. The explicit rules below require the
    # password first and add a second factor only for targetUser.
    fprintAuth = lib.mkForce false;
    yubicoAuth = lib.mkForce false;

    rules.auth = {
      unix.control = lib.mkForce "requisite";

      target-user = {
        order = unixOrder + 1;
        control = "[success=1 default=ignore]";
        modulePath = "${config.security.pam.package}/lib/security/pam_succeed_if.so";
        settings.quiet = true;
        args = ["user" "=" targetUser];
      };

      other-user-success = {
        order = unixOrder + 2;
        control = "sufficient";
        modulePath = "${config.security.pam.package}/lib/security/pam_permit.so";
      };

      local-session = {
        order = unixOrder + 3;
        # Remote or unclassified sessions skip both local-only rules.
        control = "[success=ignore default=2]";
        modulePath = "${config.security.pam.package}/lib/security/pam_exec.so";
        settings = {
          quiet = true;
          quiet_log = true;
        };
        args = ["${isLocalSession}"];
      };

      local-fingerprint = {
        order = unixOrder + 4;
        control = "sufficient";
        modulePath = "${config.services.fprintd.package}/lib/security/pam_fprintd.so";
      };

      local-deny = {
        order = unixOrder + 5;
        control = "requisite";
        modulePath = "${config.security.pam.package}/lib/security/pam_deny.so";
      };

      remote-yubico = {
        order = unixOrder + 6;
        control = "sufficient";
        modulePath = "${pkgs.yubico-pam}/lib/security/pam_yubico.so";
        settings = {
          authfile = yubicoAuthFile;
          inherit (config.security.pam.yubico) debug mode;
          id = lib.mkIf (config.security.pam.yubico.mode == "client") config.security.pam.yubico.id;
        };
      };
    };
  };
in {
  config = {
    # The Framework module enables fprintd globally, which makes fingerprint
    # authentication sufficient for almost every PAM service. Keep the daemon
    # available without enabling that blanket PAM default.
    services.fprintd.enable = lib.mkForce false;
    services.dbus.packages = [config.services.fprintd.package];
    systemd.packages = [config.services.fprintd.package];
    environment.systemPackages = [config.services.fprintd.package];

    environment.etc."security/yubico/authorized_yubikeys" = {
      text = "bakhtiyar:cccccbijujci:cccccbijuinh\n";
      mode = "0444";
      user = "root";
      group = "root";
    };

    # GDM must use gdm-password's login substack. Its separate fingerprint
    # conversation would otherwise allow fingerprint-only authentication.
    programs.dconf.profiles.gdm.databases = lib.mkBefore [
      {
        settings."org/gnome/login-screen".enable-fingerprint-authentication = false;
        locks = ["/org/gnome/login-screen/enable-fingerprint-authentication"];
      }
    ];

    security.pam.services = lib.mkMerge [
      (lib.genAttrs protectedServices mkUserSpecificAuth)
      {
        gdm-fingerprint.enable = lib.mkForce false;
      }
    ];
  };
}
