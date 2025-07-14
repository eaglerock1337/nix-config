{ config, lib, pkgs, ... }:

let
  grubThemePath = "/etc/grub/themes/gruvbox";
in {
  boot.loader.systemd-boot.enable = false;
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    gfxmodeEfi = "auto";
    device = "nvme0n1";
    theme = "${grubThemePath}/theme.txt";
  };

  boot.loader.efi.canTouchEfiVariables = true;

  environment.etc."grub/themes/gruvbox".source = ./grub;
}
