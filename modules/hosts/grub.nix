{ config, lib, pkgs, ... }:

let
  themeSource = ./grub; # dir containing theme.txt, png, pf2
in {
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    gfxmodeEfi = "auto";
    device = "nodev";
    splashImage = "${themeSource}/grub-wallpaper.png";
    font = "${themeSource}/FiraSans-Regular.pf2";
    theme = "${themeSource}/theme.txt";
  };

  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = true;
}
