{ clusterModule, ... }: {
  imports = [
    clusterModule
    ../../modules/hardware/rpi4.nix
  ];

  networking.hostName = "hlc-401";

  hlc.rescueIp = "10.23.50.41";

  hlc.disko.usbDevice0 = "/dev/disk/by-path/platform-fd500000.pcie-pci-0000:01:00.0-usbv3-0:2:1.0-scsi-0:0:0:0"; # left port
  hlc.disko.usbDevice1 = "/dev/disk/by-path/platform-fd500000.pcie-pci-0000:01:00.0-usbv3-0:1:1.0-scsi-0:0:0:0"; # right port
  hlc.disko.nvmeDevice = null;  # Pi 4: no NVMe

  system.stateVersion = "25.11";
}
