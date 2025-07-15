{ config, lib, pkgs, ... }:

let
  grubAssets = "/grub";
  gruvboxTheme = pkgs.runCommand "grub-theme" {
    themeTxt = ./. + "${grubAssets}/theme.txt";
    background = ./. + "${grubAssets}/grub-wallpaper.png";
    font = ./. + "${grubAssets}/FiraSans-Regular.pf2";
  } ''
    mkdir -p "$out"
    cp "$themeTxt" "$out/theme.txt"
    cp "$background" "$out/background.png"
    cp "$font" "$out/converted-font.pf2"
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
