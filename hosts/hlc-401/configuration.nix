{ ... }: {
  imports = [
    ../../modules/cluster/hlc/default.nix
    ../../modules/hardware/rpi4.nix
  ];

  networking.hostName = "hlc-401";

  hlc.disko.usbDevice0 = "PLACEHOLDER";
  hlc.disko.usbDevice1 = "PLACEHOLDER";
  hlc.disko.nvmeDevice = null;  # Pi 4: no NVMe

  system.stateVersion = "25.11";
}
