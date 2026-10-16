{ clusterModule, ... }: {
  imports = [
    clusterModule
    ../../modules/hardware/rpi/rpi5.nix
  ];

  networking.hostName = "hlc-507";

  hlc.rescueIp = "10.23.50.57";

  system.stateVersion = "25.11";
}
