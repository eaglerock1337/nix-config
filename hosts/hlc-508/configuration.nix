{ ... }: {
  imports = [
    ../../modules/cluster/hlc/default.nix
    ../../modules/hardware/rpi5.nix
  ];

  networking.hostName = "hlc-508";

  hlc.disko.usbDevice0 = "PLACEHOLDER";
  hlc.disko.usbDevice1 = "PLACEHOLDER";
  hlc.disko.nvmeDevice = "PLACEHOLDER";

  system.stateVersion = "25.11";
}
