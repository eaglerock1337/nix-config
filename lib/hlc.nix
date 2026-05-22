# HLC cluster helper functions — extracted from flake.nix for clarity.
# Receives flake inputs + path references, returns helper set for building
# cluster configurations.
{
  inputs, nixpkgs, home-manager, nixos-raspberrypi, disko, operatorPubkeys,
  # Paths that must resolve relative to the flake root (passed from flake.nix)
  clusterModulePath,
  provisionModulePath,
  bootstrapModulePath,
}:

let
  # mkHlcNode — provisioned nixosConfiguration for a cluster node.
  # SD bootstrap images are separate derivations built by mkHlcBootstrap below.
  mkHlcNode = { hostPath, extraModules ? [] }:
    nixos-raspberrypi.lib.nixosSystem {
      specialArgs = {
        inherit inputs operatorPubkeys;
        clusterModule = clusterModulePath;
      };
      modules = [
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
        }
        disko.nixosModules.disko
        hostPath
      ] ++ extraModules;
    };

  # mkHlcProvision — small closure for nixos-anywhere stage2.
  # No home-manager; passes clusterModule = provision.nix via specialArgs.
  mkHlcProvision = { hostPath, extraModules ? [] }:
    nixos-raspberrypi.lib.nixosSystem {
      specialArgs = {
        inherit inputs operatorPubkeys;
        clusterModule = provisionModulePath;
      };
      modules = [
        disko.nixosModules.disko
        hostPath
      ] ++ extraModules;
    };

  # mkHlcBootstrap — builds a minimal SD bootstrap image for a single node.
  mkHlcBootstrap = { hostname, piModule }:
    (nixos-raspberrypi.lib.nixosSystem {
      specialArgs = { inherit inputs operatorPubkeys; };
      modules = [
        piModule
        nixos-raspberrypi.nixosModules.sd-image
        bootstrapModulePath
        { networking.hostName = hostname; }
      ];
    }).config.system.build.sdImage;

  # Host lists — Pi 4: hlc-401..404 (4 nodes); Pi 5: hlc-501..508 (8 nodes).
  pi4Hosts = [ "hlc-401" "hlc-402" "hlc-403" "hlc-404" ];
  pi5Hosts = map (n: "hlc-5${nixpkgs.lib.fixedWidthNumber 2 n}") (nixpkgs.lib.range 1 8);

  # mkSdImages — generate { "<host>-sdImage" = <derivation>; } for a list of hosts.
  mkSdImages = piModule: hosts:
    builtins.listToAttrs (map (h: {
      name = "${h}-sdImage";
      value = mkHlcBootstrap { hostname = h; inherit piModule; };
    }) hosts);

in { inherit mkHlcNode mkHlcProvision mkHlcBootstrap mkSdImages pi4Hosts pi5Hosts; }
