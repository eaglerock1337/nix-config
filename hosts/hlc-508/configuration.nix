{ clusterModule, ... }: {
  imports = [
    clusterModule
    ../../modules/hardware/rpi/rpi5.nix
  ];

  networking.hostName = "hlc-508";

  hlc.rescueIp = "10.23.50.58";

  system.stateVersion = "25.11";
}
