{
  config,
  lib,
  pkgs,
  ...
}: let
  localPasswordAndFingerprintServices = [
    "login"
    "swaylock"
    "vlock"
    "passwd"
    "chfn"
    "chsh"
  ];

  elevationServices = [
    "sudo"
    "doas"
    "polkit-1"
    "systemd-run0"
  ];

  servicesWithoutBuiltInFingerprint = [
    "chpasswd"
    "cups"
    "doas"
    "gdm-autologin"
    "gdm-fingerprint"
    "gdm-launch-environment"
    "gdm-password"
    "groupadd"
    "groupdel"
    "groupmems"
    "groupmod"
    "other"
    "polkit-1"
    "runuser"
    "runuser-l"
    "sshd"
    "su"
    "sudo"
    "systemd-run0"
    "systemd-user"
    "useradd"
    "userdel"
    "usermod"
  ];

  yubicoAuthFile = "/etc/security/yubico/authorized_yubikeys";

  isRemoteSession = pkgs.writeShellScript "pam-is-remote-session" ''
    remote="$(${pkgs.coreutils}/bin/timeout 2s ${config.systemd.package}/bin/loginctl show-session self --property=Remote --value 2>/dev/null)" || exit 1
    [ "$remote" = yes ]
  '';

  mkLocalPasswordAndFingerprint = serviceName: {
    fprintAuth = lib.mkForce true;

    rules.auth = {
      unix.control = lib.mkForce "requisite";
      fprintd = {
        control = lib.mkForce "sufficient";
        order = config.security.pam.services.${serviceName}.rules.auth.unix.order + 1;
      };
    };
  };

  mkElevationService = serviceName: let
    service = config.security.pam.services.${serviceName};
    firstOrder = service.rules.auth.fprintd.order;
  in {
    fprintAuth = lib.mkForce false;

    rules.auth = {
      # Replace the built-in password, fingerprint, YubiOTP, and final deny
      # rules with one explicit local/remote branch. Other PAM phases retain
      # the NixOS defaults.
      fprintd.enable = lib.mkForce false;
      unix.enable = lib.mkForce false;
      yubico.enable = lib.mkForce false;
      deny.enable = lib.mkForce false;

      remote-session = {
        order = firstOrder;
        control = "[success=3 default=ignore]";
        modulePath = "${config.security.pam.package}/lib/security/pam_exec.so";
        settings = {
          quiet = true;
          quiet_log = true;
        };
        args = ["${isRemoteSession}"];
      };

      local-password = {
        order = firstOrder + 1;
        control = "requisite";
        modulePath = "${config.security.pam.package}/lib/security/pam_unix.so";
        settings = {
          nullok = service.allowNullPassword;
          inherit (service) nodelay;
          likeauth = true;
          try_first_pass = true;
        };
      };

      local-fingerprint = {
        order = firstOrder + 2;
        control = "sufficient";
        modulePath = "${config.services.fprintd.package}/lib/security/pam_fprintd.so";
      };

      local-deny = {
        order = firstOrder + 3;
        control = "requisite";
        modulePath = "${config.security.pam.package}/lib/security/pam_deny.so";
      };

      remote-password = {
        order = firstOrder + 4;
        control = "requisite";
        modulePath = "${config.security.pam.package}/lib/security/pam_unix.so";
        settings = {
          nullok = service.allowNullPassword;
          inherit (service) nodelay;
          likeauth = true;
          try_first_pass = true;
        };
      };

      remote-yubico = {
        order = firstOrder + 5;
        control = "sufficient";
        modulePath = "${pkgs.yubico-pam}/lib/security/pam_yubico.so";
        settings = {
          authfile = yubicoAuthFile;
          inherit (config.security.pam.yubico) debug mode;
          id = lib.mkIf (config.security.pam.yubico.mode == "client") config.security.pam.yubico.id;
        };
      };

      remote-deny = {
        order = firstOrder + 6;
        control = "requisite";
        modulePath = "${config.security.pam.package}/lib/security/pam_deny.so";
      };
    };
  };

  enabledFingerprintServices = lib.attrNames (
    lib.filterAttrs (_: service: service.enable && service.fprintAuth) config.security.pam.services
  );

  unexpectedFingerprintServices = lib.subtractLists localPasswordAndFingerprintServices enabledFingerprintServices;
in {
  config = {
    assertions = [
      {
        assertion = unexpectedFingerprintServices == [];
        message = ''
          Fingerprint authentication was enabled for unexpected PAM services:
          ${lib.concatStringsSep ", " unexpectedFingerprintServices}
        '';
      }
    ];

    environment.etc."security/yubico/authorized_yubikeys" = {
      text = "bakhtiyar:cccccbijujci:cccccbijuinh\n";
      mode = "0444";
      user = "root";
      group = "root";
    };

    programs.dconf.profiles.gdm.databases = lib.mkBefore [
      {
        settings."org/gnome/login-screen".enable-fingerprint-authentication = false;
        locks = ["/org/gnome/login-screen/enable-fingerprint-authentication"];
      }
    ];

    security.pam.services = lib.mkMerge [
      (lib.genAttrs localPasswordAndFingerprintServices mkLocalPasswordAndFingerprint)
      (lib.genAttrs servicesWithoutBuiltInFingerprint (_: {
        fprintAuth = lib.mkForce false;
      }))
      (lib.genAttrs elevationServices mkElevationService)
      {
        # GDM must use gdm-password's login substack. Its separate fingerprint
        # service authenticates with a fingerprint alone.
        gdm-fingerprint.enable = false;

        # SSH cannot use the laptop's fingerprint reader. Retain the existing
        # YubiOTP policy, but use the root-owned system mapping above.
        sshd.rules.auth.yubico.settings.authfile = yubicoAuthFile;

        # Preserve pam_rootok for callers already running as root, then reject
        # every non-root caller before any authentication method can run.
        su.rules.auth = {
          fprintd.enable = lib.mkForce false;
          unix.enable = lib.mkForce false;
          non-root-deny = {
            order = config.security.pam.services.su.rules.auth.rootok.order + 1;
            control = "requisite";
            modulePath = "${config.security.pam.package}/lib/security/pam_deny.so";
          };
        };
      }
    ];
  };
}
