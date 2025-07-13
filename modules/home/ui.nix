{ config, pkgs, ... }:

let
  nerdFont = pkgs.nerdfonts.override { fonts = [ "FiraCode" ]; };
in {
  # ROFI Config
  programs.rofi = {
    enable = true;
    theme = "gruvbox-dark";
    extraConfig = {
      modi = "drun,run";
      show-icons = true;
      font = "FiraCode Nerd Font 16";
    };
  };

  services.picom = {
    enable = true;
    fade = true;
    shadow = true;
    vSync = true;
  };

  programs.alacritty = {
    enable = true;
    theme = "gruvbox-dark";
    settings = {
      font = {
        normal.family = "FiraCode Nerd Font";
        size = 11;
      };
      window = {
        opacity = 0.8;
      };
    };
  };
}
