{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    vscode-server = {
      url = "github:nix-community/nixos-vscode-server";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-colors.url = "github:misterio77/nix-colors";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    nixpkgs-unstable,
    nix-colors,
    ...
  }: let
    system = "x86_64-linux";
    overlay-unstable = final: prev: {
      unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
    };
    mkSystem = hostName: extraModules:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit hostName;
          yubikeys = [
            "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIG1XG551t2Yb8ryQ/lGRJXhfnWwz3B/MmOjMoz7x3G9iAAAABHNzaDo= blue"
            "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAICDUZrPTStLzzGeHC+c81L4u1B47CwOW3N3HRfM/2tzvAAAABHNzaDo= green"
          ];
          inherit nix-colors;
        };
        modules =
          [
            inputs.vscode-server.nixosModules.default
            ./mixins/core.nix
            ./mixins/palette.nix
            (./hosts/${hostName} + ".nix")
            {
              nix.registry = {
                nixpkgs.flake = nixpkgs;
                nixpkgs-unstable.flake = nixpkgs-unstable;
              };
              nixpkgs.overlays = [overlay-unstable];
              system.configurationRevision = self.rev or "dirty";
            }
          ]
          ++ extraModules;
      };
  in {
    nixosConfigurations = let
      owned = [
        ./mixins/bare-metal.nix
        ./mixins/gui.nix
        ./mixins/on-battery.nix
        ./mixins/trusted.nix
      ];
    in {
      iron = mkSystem "iron" (owned
        ++ [
          ./mixins/always-on.nix
          ./mixins/amd.nix
          ./mixins/ecc.nix
          ./mixins/neurasium.nix
          ./mixins/zfs.nix
        ]);
      tin = mkSystem "tin" [];
      mercury = mkSystem "mercury" owned;
      tungsten = mkSystem "tungsten" [
        ./mixins/always-on.nix
        ./mixins/untrusted.nix
        ./mixins/zfs.nix
      ];
    };
  };
}
