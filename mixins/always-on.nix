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

    systemd.services.nixos-upgrade.serviceConfig.CPUWeight = 75;

    system.autoUpgrade = {
      enable = true;
      dates = "Mon *-*-* 04:40";
      flags = [
        "--update-input"
        "nixpkgs"
        "--update-input"
        "nixpkgs-unstable"
        "--update-input"
        "claude-code"
        "--update-input"
        "codex-cli"
        "--update-input"
        "vscode-server"
        "--update-input"
        "nix-colors"
        "--update-input"
        "lanzaboote"
        "--update-input"
        "nixos-hardware"
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
