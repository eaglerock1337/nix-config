{ clusterModule, ... }: {
  imports = [
    clusterModule
    ../../modules/hardware/rpi/rpi5.nix
  ];

  networking.hostName = "hlc-501";

  hlc.rescueIp = "10.23.50.51";

  system.stateVersion = "25.11";
}
