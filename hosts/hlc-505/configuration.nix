{ clusterModule, ... }: {
  imports = [
    clusterModule
    ../../modules/hardware/rpi5.nix
  ];

  networking.hostName = "hlc-505";

  hlc.rescueIp = "10.23.50.55";

  system.stateVersion = "25.11";
}
