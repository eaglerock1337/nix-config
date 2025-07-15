{ config, lib, pkgs, ... }:

let
  grubThemePath = ./grub;
  gruvboxTheme = pkgs.runCommand "grub-theme" {
    inherit grubThemePath;
  }
  ''
    mkdir -p "$out"
    cp -r "$grubThemePath/." "$out/"
  '';
in {
  boot.loader.systemd-boot.enable = false;

  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    gfxmodeEfi = "auto";
    device = "nodev";
    theme = "${gruvboxTheme}/theme.txt";
  };

  boot.loader.efi.canTouchEfiVariables = true;
}
