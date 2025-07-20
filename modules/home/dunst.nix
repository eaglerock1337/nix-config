{ config, pkgs, ... }:

let
  colors = import ./colors.nix;
  gruvboxDark = colors.gruvboxDark;
in {
  services.dunst = {
    enable = true;
    settings = {
      global = {
        monitor = 0;
        follow = "none";
        geometry = "300x5-10-40"; # width x max_count -x_offset -y_offset from bottom-right
        origin = "bottom-right";
        offset = "10x40";
        padding = 16;
        horizontal_padding = 16;
        frame_width = 2;
        frame_color = gruvboxDark.bg0Hard;
        separator_color = "frame";
        font = "Fira Sans 10";
        line_height = 4;
        markup = "full";
        format = "<b>%s</b>\n%b"; # Use Fira Code for bolded title via markup
        alignment = "left";
        word_wrap = true;
        show_age_threshold = 60;
        icon_position = "left";
        min_icon_size = 32;
        max_icon_size = 64;
        transparency = 0;
        idle_threshold = 120;
        mouse_left_click = "close_current";
        mouse_middle_click = "do_action";
        mouse_right_click = "close_all";
        stack_duplicates = true;
      };

      urgency_low = {
        background = gruvboxDark.bg1; # Gruvbox dark gray
        foreground = gruvboxDark.fg; # Gruvbox light text
        timeout = 5;
      };

      urgency_normal = {
        background = gruvboxDark.blue; # Gruvbox yellow
        foreground = gruvboxDark.fg; # Gruvbox dark background for contrast
        timeout = 20;
      };

      urgency_critical = {
        background = gruvboxDark.red; # Gruvbox red
        foreground = gruvboxDark.fg; # Gruvbox very light
        timeout = 0;
      };
    };
  };
}
