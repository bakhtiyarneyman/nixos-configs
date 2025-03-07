{yubikeys, ...}: {
  config = {
    programs.ssh.startAgent = true;

    security.pam = {
      sshAgentAuth.enable = true;
      services = {
        sudo.sshAgentAuth = true;
      };
    };

    users.users = let
      hashedPassword = "$6$8/ZCmPvSRiRnXlJN$nCS1B6KlgAlHdh1P5t0iRmmTT2vzLlm5YF9eLiYGvHwDCNXK0g1737P5yazyZPHOYWcjQUizGP2/92c3TILNx1";
    in {
      root = {inherit hashedPassword;};
      bakhtiyar = {
        inherit hashedPassword;
        openssh.authorizedKeys.keys =
          [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGxoBwt5zviLpPomH5vHq0OQzN/G9dMKmyq+2y91xkRe github@1password"
          ]
          ++ yubikeys;
      };
    };
  };
}
