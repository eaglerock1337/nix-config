{ clusterModule, ... }: {
  imports = [
    clusterModule
    ../../modules/hardware/rpi4.nix
  ];

  networking.hostName = "hlc-402";

  hlc.rescueIp = "10.23.50.42";

  system.stateVersion = "25.11";
}
