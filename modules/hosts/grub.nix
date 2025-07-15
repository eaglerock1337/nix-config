{ config, lib, pkgs, ... }:

let
  themeSource = ./grub; # dir containing theme.txt, png, pf2
in {
  # Install theme in /etc
  environment.etc."grub/themes/gruvbox".source = themeSource;

  # Copy to /boot after build
  boot.postBootCommands = ''
    mkdir -p /boot/grub/themes/gruvbox
    cp -r /etc/grub/themes/gruvbox/* /boot/grub/themes/gruvbox/
  '';

  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    gfxmodeEfi = "auto";
    device = "nodev";
    theme = "/boot/grub/themes/gruvbox/theme.txt";
  };

  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = true;
}
