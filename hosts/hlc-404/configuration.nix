{ clusterModule, ... }: {
  imports = [
    clusterModule
    ../../modules/hardware/rpi/rpi4.nix
  ];

  networking.hostName = "hlc-404";

  hlc.rescueIp = "10.23.50.44";

  system.stateVersion = "25.11";
}
