{ config, pkgs, ... }:

let
  nerdFont = pkgs.nerdfonts.override { fonts = [ "FiraCode" ]; };
in {
  home.packages = with pkgs; [
    feh
    rofi
    picom
    xterm
    firefox
    hexchat
    xfce.thunar
    playerctl
    nerd-fonts.fira-code
    nerd-fonts.droid-sans-mono
    themix-gui
    pamixer        # volume control
    brightnessctl  # brightness (optional)
    i3lock         # lock screen
    alacritty      # terminal
  ];

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
    theme = "gruvbox_dark";
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
