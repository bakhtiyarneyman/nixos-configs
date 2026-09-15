{
  config,
  lib,
  pkgs,
  ...
}: let
  targetUser = "bakhtiyar";
  authFile = "security/yubico/authorized_yubikeys";
  pam = name: "${config.security.pam.package}/lib/security/pam_${name}.so";
  rule = name: control: modulePath: args: {inherit name control modulePath args;};
  otherUser = rule "other-user" "sufficient" (pam "succeed_if") ["quiet" "user" "!=" targetUser];
  deny = rule "deny" "requisite" (pam "deny") [];
  yubico =
    (rule "otp" "sufficient" "${pkgs.yubico-pam}/lib/security/pam_yubico.so" [])
    // {
      settings = {
        authfile = "/etc/${authFile}";
        inherit (config.security.pam.yubico) debug mode;
        id = lib.mkIf (config.security.pam.yubico.mode == "client") config.security.pam.yubico.id;
      };
    };
  # pam_fprintd already skips known remote callers and readers without enrolled prints.
  fingerprint = rule "fingerprint" "sufficient" "${config.services.fprintd.package}/lib/security/pam_fprintd.so" [];

  # Whole-rule ownership and consecutive integer orders prevent ordinary
  # overrides or insertion inside the block; nixpkgs rejects order collisions.
  ownedRules = start: rules:
    lib.listToAttrs (lib.imap1 (offset: r:
      lib.nameValuePair r.name (lib.mkForce ((removeAttrs r ["name"]) // {order = start + offset;})))
    rules);

  pamServicePolicy = {
    config,
    name,
    ...
  }: let
    # User-manager startup and printer administration keep their native authentication.
    exempt = lib.elem name ["systemd-user" "cups"];
    managed = config.enable && config.useDefaultRules && config.unixAuth && !exempt;
    rules = lib.filter (r: r.enable) (lib.attrValues config.rules.auth);
    unixOrder = config.rules.auth.unix.order;
    safePrefix = r:
      r.order
      >= unixOrder
      || lib.elem r.control ["optional" "required" "requisite"]
      || (config.rootOK && r.modulePath == pam "rootok" && r.control == "sufficient" && r.args == []);
  in {
    options.text = lib.mkOption {
      # Keep the native renderer; reject raw service text overrides.
      readOnly = config.enable;
      apply = text:
        assert lib.assertMsg (!config.enable
          || managed
          || exempt
          || !lib.any (r: baseNameOf r.modulePath == "pam_unix.so") rules)
        "PAM ${name}: custom password authentication needs the default two-factor stack.";
        assert lib.assertMsg (!managed || lib.all safePrefix rules)
        "PAM ${name}: an earlier rule can bypass the required authentication block."; text;
    };
    config = {
      # Enable the normal daemon integration, never the fingerprint-only default.
      fprintAuth = lib.mkForce false;
      yubicoAuth = lib.mkIf managed (lib.mkForce false);
      rules.auth = lib.mkIf managed (
        {
          unix = lib.mapAttrs (_: lib.mkForce) {
            enable = true;
            control = "requisite";
            modulePath = pam "unix";
          };
        }
        // ownedRules unixOrder (
          [otherUser fingerprint]
          # Swaylock supplies the password but cannot collect a separate OTP.
          ++ lib.optional (name != "swaylock") yubico
          ++ [deny]
        )
      );
    };
  };
in {
  options.security.pam.services = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule pamServicePolicy);
  };
  config = {
    services.fprintd.enable = true;
    environment.etc.${authFile}.text = "${targetUser}:cccccbijujci:cccccbijuinh\n";

    # Use GDM's password conversation, not its parallel fingerprint-only one.
    programs.dconf.profiles.gdm.databases = lib.mkBefore [
      {
        settings."org/gnome/login-screen".enable-fingerprint-authentication = false;
        locks = ["/org/gnome/login-screen/enable-fingerprint-authentication"];
      }
    ];
    security.pam.services = {
      gdm-fingerprint.enable = lib.mkForce false;
      gdm-password = lib.mkIf config.services.displayManager.gdm.enable {
        useDefaultRules = lib.mkForce false;
        rules.auth = lib.mkForce (ownedRules 0 [(rule "login" "substack" "login" [])]);
      };
      # Root can use su; everyone else must elevate through sudo with 2FA.
      su = {
        unixAuth = lib.mkForce false;
        rules.auth = lib.mkForce (ownedRules 0 [
          (rule "rootok" "sufficient" (pam "rootok") [])
          deny
        ]);
      };
    };
  };
}
