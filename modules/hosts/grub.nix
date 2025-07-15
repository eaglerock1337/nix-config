{ config, lib, pkgs, ... }:

let
  themeSource = ./grub; # dir containing theme.txt, png, pf2
in {
  # Install theme in /tmp
  environment.tmp."grub/themes/gruvbox".source = themeSource;

  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    gfxmodeEfi = "auto";
    device = "nodev";
    theme = "/tmp/grub/themes/gruvbox/theme.txt";
  };

  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = true;
}
