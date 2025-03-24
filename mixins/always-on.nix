{
  config.system.autoUpgrade = {
    enable = false; # Disable temporarily.
    flags = [
      "--update-input"
      "nixpkgs"
      "--update-input"
      "nixpkgs-unstable"
      "--update-input"
      "vscode-server"
      "--update-input"
      "nix-colors"
      "--update-input"
      "lanzaboote"
    ];
    flake = "/etc/nixos";
    allowReboot = true;
    rebootWindow = {
      lower = "04:00";
      upper = "06:00";
    };
  };
}
