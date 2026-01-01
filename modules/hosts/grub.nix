{ config, lib, pkgs, ... }:

let
  themeSource = ./grub;
in {
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    gfxmodeEfi = "auto";
    device = "nodev";
    theme = themeSource;
    # Limit boot menu entries to prevent clutter
    configurationLimit = 20;
  };

  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.efiSysMountPoint = "/boot";
  boot.loader.efi.canTouchEfiVariables = true;
}
