{
  config.system.autoUpgrade = {
    enable = true;
    allowReboot = true;
    flags = [
      "--update-input=nixpkgs"
      "--update-input=nixpkgs-unstable"
      "--commit-lock-file"
    ];
    flake = "/etc/nixos";
    rebootWindow = {
      lower = "12:00";
      upper = "16:00";
    };
  };
}



