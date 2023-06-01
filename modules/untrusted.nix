{
  config = {
    users.users =
      let
        hashedPassword = "$6$8/ZCmPvSRiRnXlJN$nCS1B6KlgAlHdh1P5t0iRmmTT2vzLlm5YF9eLiYGvHwDCNXK0g1737P5yazyZPHOYWcjQUizGP2/92c3TILNx1"; in
      {
        root = { inherit hashedPassword; };
        bakhtiyar = { inherit hashedPassword; };
      };
    programs.ssh.startAgent = true;
    security.pam = { 
      enableSSHAgentAuth = true;
      services = {
        sudo.sshAgentAuth = true;
      };
    };
  };
}
