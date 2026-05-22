{ clusterModule, ... }: {
  imports = [
    clusterModule
    ../../modules/hardware/rpi/rpi4.nix
  ];

  networking.hostName = "hlc-401";

  hlc.rescueIp = "10.23.50.41";

  system.stateVersion = "25.11";
}
