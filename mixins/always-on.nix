{
  machineName,
  machines,
  ...
}: {
  config = {
    services = {
      nix-serve = {
        enable = true;
        secretKeyFile = "/etc/nixos/secrets/${machineName}.nix-serve.secret-key";
      };
    };

    system.autoUpgrade = {
      enable = true;
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
        "--option"
        "extra-binary-caches"
        (builtins.concatStringsSep " " (builtins.attrValues (builtins.mapAttrs (mn: _cfg: "http://${mn}:5000") machines)))
      ];

      flake = "/etc/nixos";
      allowReboot = true;
      rebootWindow = {
        lower = "04:00";
        upper = "06:00";
      };
    };
  };
}
