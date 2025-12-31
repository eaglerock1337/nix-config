{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, ... } @ inputs:
  let
    system = "x86_64-linux";

    unstable = import nixpkgs-unstable {
      inherit system;
      config = {
        allowUnfreePredicate = pkg:
          builtins.elem ((pkg.pname or (pkg.name or ""))) [
            "claude-code"
          ];
      };
    };
  in {
    nixosConfigurations.silicon = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit self nixpkgs nixpkgs-unstable home-manager; };
      modules = [
        ./hosts/silicon/configuration.nix

        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = { inherit unstable; };
          home-manager.users.eaglerock = import ./home/eaglerock.nix;
        }
        {
          nixpkgs.config.allowUnfreePredicate = pkg:
            builtins.elem ((pkg.pname or (pkg.name or ""))) [
              "claude-code"
            ];
        }
      ];
    };
  };
}
