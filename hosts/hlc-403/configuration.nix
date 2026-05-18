{ clusterModule, ... }: {
  imports = [
    clusterModule
    ../../modules/hardware/rpi4.nix
  ];

  networking.hostName = "hlc-403";

  hlc.rescueIp = "10.23.50.43";

  system.stateVersion = "25.11";
}
