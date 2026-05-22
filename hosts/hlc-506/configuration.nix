{ clusterModule, ... }: {
  imports = [
    clusterModule
    ../../modules/hardware/rpi/rpi5.nix
  ];

  networking.hostName = "hlc-506";

  hlc.rescueIp = "10.23.50.56";

  system.stateVersion = "25.11";
}
