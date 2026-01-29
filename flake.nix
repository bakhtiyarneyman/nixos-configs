{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    vscode-server = {
      url = "github:nix-community/nixos-vscode-server";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-colors.url = "github:misterio77/nix-colors";
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.0.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Reminder: tend to `always-on.nix` when adding new inputs.
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    nix-colors,
    vscode-server,
    lanzaboote,
    ...
  }: let
    system = "x86_64-linux";
    overlay-unstable = final: prev: {
      unstable = import nixpkgs-unstable {
        inherit system;
        config = {
          allowUnfree = true;
        };
        overlays = [
          (self: super: {
            ctranslate2 = super.ctranslate2.override {
              withMkl = true;
              withOneDNN = false;
              withOpenblas = false;
              mkl = super.mkl.override {
                enableStatic = true;
              };
            };
          })
        ];
      };
    };
    machineNames = [
      "iron"
      "mercury"
      "tin"
      "tungsten"
    ];
    mkSystem = machineName: {
      name = machineName;
      value = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit machineName;
          inherit machines;
          yubikeys = [
            "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIG1XG551t2Yb8ryQ/lGRJXhfnWwz3B/MmOjMoz7x3G9iAAAABHNzaDo= blue"
            "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAICDUZrPTStLzzGeHC+c81L4u1B47CwOW3N3HRfM/2tzvAAAABHNzaDo= green"
          ];
          inherit nix-colors;
          nixServePort = 5383;
        };
        modules = [
          vscode-server.nixosModules.default
          lanzaboote.nixosModules.lanzaboote
          ./modules/initrd-network-access.nix
          ./modules/nfs-exports.nix
          ./modules/palette.nix
          ./modules/wifi-interface.nix
          ./mixins/core.nix
          (./machines/${machineName} + ".nix")
          {
            nix.registry = {
              nixpkgs.flake = nixpkgs;
              nixpkgs-unstable.flake = nixpkgs-unstable;
            };
            nixpkgs.overlays = [overlay-unstable];
            system.configurationRevision = self.rev or "dirty";
          }
        ];
      };
    };
    machines = builtins.listToAttrs (map mkSystem machineNames);
  in {
    nixosConfigurations = machines;
  };
}
