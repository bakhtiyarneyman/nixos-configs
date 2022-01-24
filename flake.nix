{
  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-21.11;
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
      mkSystem = hostName: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit hostName; };
        modules = [
          ({ config, pkgs, ... }: { nixpkgs.overlays = [ overlay-unstable ]; })
          (./hosts/${hostName} + ".nix") # rnix-lsp complains about this.
          ./common.nix
          ./modules/dunst.nix
          ./modules/i3status-rust.nix
        ];
      };
    in {
      nixosConfigurations.iron = mkSystem "iron";
      nixosConfigurations.kevlar = mkSystem "kevlar";
    };
}