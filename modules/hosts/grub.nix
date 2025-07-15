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
  };

  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.efiSysMountPoint = "/boot";
  boot.loader.efi.canTouchEfiVariables = true;
}
