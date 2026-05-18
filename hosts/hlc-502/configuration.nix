{ clusterModule, ... }: {
  imports = [
    clusterModule
    ../../modules/hardware/rpi5.nix
  ];

  networking.hostName = "hlc-502";

  hlc.rescueIp = "10.23.50.52";

  system.stateVersion = "25.11";
}
