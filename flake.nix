{
  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-22.11;
    nixpkgs-unstable.url = github:NixOS/nixpkgs/nixos-unstable;
  };

  outputs = { self, nixpkgs, nixpkgs-unstable }:
    let
      system = "x86_64-linux";
      overlay-unstable = final: prev: {
        unstable = import nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
        };
      };
      mkSystem = hostName: extraModules: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit hostName; };
        modules = [
          {
            nix.registry = {
              nixpkgs.flake = nixpkgs;
              nixpkgs-unstable.flake = nixpkgs-unstable;
            };
            nixpkgs.overlays = [ overlay-unstable ];
            system.configurationRevision = self.rev or "dirty";
          }
          (./hosts/${hostName} + ".nix") # rnix-lsp complains about this.
          ./modules/core.nix
        ] ++ extraModules;
      };
    in
    {
      nixosConfigurations =
        let owned = [
          ./modules/gui.nix
          ./modules/trusted.nix
        ];
        in
        {
          iron = mkSystem "iron" owned;
          kevlar = mkSystem "kevlar" owned;
          tungsten = mkSystem "tungsten" [ ./modules/untrusted.nix ];
        };
    };
}
