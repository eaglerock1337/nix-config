{ clusterModule, ... }: {
  imports = [
    clusterModule
    ../../modules/hardware/rpi5.nix
  ];

  networking.hostName = "hlc-508";

  hlc.rescueIp = "10.23.50.58";

  hlc.disko.usbDevice0 = "/dev/disk/by-path/platform-xhci-hcd.0-usb-0:1:1.0-scsi-0:0:0:0";
  hlc.disko.usbDevice1 = "/dev/disk/by-path/platform-xhci-hcd.1-usb-0:1:1.0-scsi-0:0:0:0";
  hlc.disko.nvmeDevice = "/dev/nvme0n1";

  system.stateVersion = "25.11";
}
