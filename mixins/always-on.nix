{
  machineName,
  machines,
  nixServePort,
  ...
}: {
  config = {
    services = {
      nix-serve = {
        enable = true;
        port = nixServePort;
        secretKeyFile = "/etc/nixos/secrets/${machineName}.nix-serve.secret-key";
      };
    };

    system.autoUpgrade = {
      enable = true;
      dates = "Mon *-*-* 04:40";
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
        ''"${(builtins.concatStringsSep " " (builtins.attrValues (builtins.mapAttrs (mn: _cfg: "http://${mn}:${builtins.toString nixServePort}") machines)))}"''
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
