{
  description = "eaglerock's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, home-manager, ... }:
    nixosConfigurations.silicon = nixpkgs.lib.nixosSystem: {
      system = "x86_64-linux";
      modules = [ ./hosts/silicon/configuration.nix ];
    };

    homeConfigurations = {
      "eaglerock" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs { system = "x86_64-linux"; };
        modules = [
          ./home/eaglerock.nix
        ];
      };
    };

    let
      system = "x86_64-linux";
      mkHost = hostname: nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./hosts/${hostname}/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useUserPackages = true;
            home-manager.users.eaglerock = import ./home/eaglerock.nix;
          }
        ];
      };
    in {
      nixosConfigurations = {
        silicon = mkHost "silicon";
      };
    };
}