{ config, pkgs, ... }:

let
  nerdFont = pkgs.nerdfonts.override { fonts = [ "FiraCode" ]; };
  gruvboxDark = {
    bg = "#282828";
    fg = "#ebdbb2";
    black = "#1d2021";
    red = "#fb4934";
    green = "#b8bb26";
    yellow = "#fabd2f";
    blue = "#83a598";
    purple = "#d3869b";
    aqua = "#8ec07c";
    gray = "#a89984";
  };
in {
  # ROFI Config
  programs.rofi = {
    enable = true;
    theme = "gruvbox-dark";
    extraConfig = {
      modi = "drun,run";
      show-icons = true;
      font = "FiraCode Nerd Font 11";
    };
  };

  services.feh = {
    enable = true;
    image = "../../assets/wallpaper.png";
    options = [ "--bg-scale" ];                        # or --bg-fill, --bg-center, etc.
  };

  services.picom = {
    enable = true;
    fade = true;
    shadow = true;
    vSync = true;
  };

  programs.alacritty = {
    enable = true;
    settings = {
      colors = {
        primary = {
          background = gruvboxDark.bg;
          foreground = gruvboxDark.fg;
        };
        normal = {
          black = gruvboxDark.black;
          red = gruvboxDark.red;
          green = gruvboxDark.green;
          yellow = gruvboxDark.yellow;
          blue = gruvboxDark.blue;
          magenta = gruvboxDark.purple;
          cyan = gruvboxDark.aqua;
          white = gruvboxDark.fg;
        };
        bright = {
          black = "#928374";
          red = "#fb4934";
          green = "#b8bb26";
          yellow = "#fabd2f";
          blue = "#83a598";
          magenta = "#d3869b";
          cyan = "#8ec07c";
          white = "#ebdbb2";
        };
      };
      font = {
        normal.family = "FiraCode Nerd Font";
        size = 11;
      };
    };
  };
}
