{ clusterModule, ... }: {
  imports = [
    clusterModule
    ../../modules/hardware/rpi/rpi5.nix
  ];

  networking.hostName = "hlc-504";

  hlc.rescueIp = "10.23.50.54";

  system.stateVersion = "25.11";
}
