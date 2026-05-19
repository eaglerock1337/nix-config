{ clusterModule, ... }: {
  imports = [
    clusterModule
    ../../modules/hardware/rpi5.nix
  ];

  networking.hostName = "hlc-503";

  hlc.rescueIp = "10.23.50.53";

  system.stateVersion = "25.11";
}
