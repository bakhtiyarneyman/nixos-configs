{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    vscode-server = {
      url = "github:nix-community/nixos-vscode-server";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    nixpkgs-unstable,
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
        specialArgs = {inherit hostName;};
        modules =
          [
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
          inputs.vscode-server.nixosModules.default
        ]);
      kevlar = mkSystem "kevlar" owned;
      tungsten = mkSystem "tungsten" [
        ./mixins/always-on.nix
        ./mixins/untrusted.nix
        ./mixins/zfs.nix
      ];
    };
  };
}
