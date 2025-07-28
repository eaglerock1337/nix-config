{ config, pkgs, ... }:

let
  colors = import ./colors.nix;
  gruvboxDark = colors.gruvboxDark;
in {
  # POLYBAR CONFIG
  services.polybar = {
    enable = true;
    config = {
      "bar/mainbar" = {
        monitor = "\${env:MONITOR:eDP-1}";
        width = "100%";
        height = "4%";
        bottom = true;
        font-0 = "FiraCode Nerd Font:size=16;2";
        background = gruvboxDark.bg;
        foreground = gruvboxDark.fg;
        modules-left = "xworkspaces";
        modules-right = "wlan separator cpu separator temperature separator memory separator filesystem separator battery separator date";
      };

      "module/separator" = {
        type = "custom/text";
        format-foreground = gruvboxDark.purple;
        format = "󰄽";
      };

      "module/xworkspaces" = {
        type = "internal/xworkspaces";
        label-active = "%name% ";
        label-active-background = gruvboxDark.blue;
        label-active-foreground = gruvboxDark.bg;
        label-active-padding = "1";
        label-occupied = "%name% ";
        label-occupied-background = gruvboxDark.bg;
        label-occupied-foreground = gruvboxDark.yellow;
        label-occupied-padding = "1";
        label-empty = "%name% ";
        label-empty-background = gruvboxDark.bg;
        label-empty-foreground = gruvboxDark.gray;
        label-empty-padding = "1";
        label-urgent = "%name%!";
        label-urgent-background = gruvboxDark.red;
        label-urgent-foreground = gruvboxDark.fg;
        label-urgent-padding = "1";
      };

      "module/wlan" = {
        type = "internal/network";
        interface = "wlp0s20f3";
        interval = 3;
        format-connected = " <label-connected>";
        label-connected = "%essid% %signal%% ";
        format-connected-foreground = gruvboxDark.green;
        format-disconnected = " Down";
        format-disconnected-foreground = gruvboxDark.red;
        format-padding = 1;
      };

      "module/cpu" = {
        type = "internal/cpu";
        format = " <label>";
        format-padding = 1;
        format-foreground = gruvboxDark.blue;
        label = "%percentage%%";
      };

      "module/temperature" = {
        type = "internal/temperature";
        thermal-zone = 0;
        interval = 5;
        format = "<label>";
        format-padding = 1;
        format-foreground = gruvboxDark.yellow;
        label = "%temperature:C%";
      };

      "module/memory" = {
        type = "internal/memory";
        format = " <label>";
        format-padding = 1;
        format-foreground = gruvboxDark.aqua;
        label = "%mb_used% %percentage_used%%";
      };

      "module/filesystem" = {
        type = "internal/fs";
        mount-0 = "/";
        interval = 10;
        format-mounted = " <label-mounted>";
        format-mounted-padding = 1;
        format-mounted-foreground = gruvboxDark.red;
        label-mounted = "%used% %percentage_used%%";
      };

      "module/battery" = {
        type = "internal/battery";
        battery = "BAT0";
        adapter = "AC";
        time-format = "%H:%M";
        full-at = 85;
        low-at = 8;
        poll-interval = 5;

        format-full-padding = 1;
        format-full-foreground = gruvboxDark.green;
        format-full = "󰁹 Full";
        label-full = "%percentage%%";

        format-charging = "<animation-charging> <label-charging>";
        format-charging-foreground = gruvboxDark.green;
        format-charging-padding = 1;
        label-charging = "%percentage%%";
        animation-charging-0 = "󰂆";
        animation-charging-1 = "󰂈";
        animation-charging-2 = "󰂉";
        animation-charging-3 = "󰂊";
        animation-charging-4 = "󰂅";
        animation-charging-framerate = 2000;

        format-discharging = "<ramp-capacity> <label-discharging>";
        format-discharging-padding = 1;
        format-discharging-foreground = gruvboxDark.yellow;
        label-discharging = "%percentage%% %time%";
        ramp-capacity-0 = "󰁻";
        ramp-capacity-1 = "󰁽";
        ramp-capacity-2 = "󰁿";
        ramp-capacity-3 = "󰂁";
        ramp-capacity-4 = "󰁹";

        format-low = "󰂃 <label-low>";
        format-low-padding = 1;
        format-low-foreground = gruvboxDark.red;
        label-low = "%percentage%% %time%";
      };

      "module/volume" = {
        type = "internal/pulseaudio";

        format-volume = "<ramp-volume> <label-volume>";
        format-volume-padding = 1;
        format-volume-foreground = gruvboxDark.yellow;
        label-volume = "%percentage%%";

        format-muted = " <label-muted>";
        format-muted-foreground = gruvboxDark.yellow;
        format-muted-padding = 1;
        label-muted = "%percentage%%";

        ramp-volume-0 = "";
        ramp-volume-1 = "";
        ramp-volume-2 = "";
      };

      "module/date" = {
        type = "internal/date";
        interval = 1;
        date = "%m-%d-%y";
        time = "%H:%M";
        date-alt = "%A, %B %d %Y";
        time-alt = "%H:%M:%S";
        format = " <label>";
        format-padding = 1;
        format-foreground = gruvboxDark.blue;
        label = "%date% %time%";
      };
    };
    script = "polybar mainbar &";
  };

  xdg.configFile."picom/picom.conf".text = ''
    corner-radius = 10;

    # Shadow
    shadow = false;

    # Blur
    blur-background = false;

    blur-background-exclude = [
        "window_type = 'dock'",
        "window_type = 'desktop'",
        "_GTK_FRAME_EXTENTS@:c",
        "class_g = 'Peek'",
        "class_g = 'polybar'",
        "i:e:gnome-screenshot"
    ];

    rounded-corners-exclude = [
        "class_g = 'polybar'",
        "class_g *?= 'rofi'",
        "window_type = 'dock'"
    ];

    # Fading
    fading = false;
    inactive-opacity: 0.9;
    inactive-dim: 0.1;
    mark-ovredir-focused = true;

    # Other
    backend = "xrender"
    mark-wmwin-focused = false;
    use-ewmh-active-win = false;
    detect-rounded-corners = true;
    detect-client-opacity = false;
    refresh-rate = 0;
    vsync = false;
    dbe = false;
    unredir-if-possible = false;
    focus-exclude = [ "class_g ?= 'feh'" ];
    detect-transient = true;
    detect-client-leader = true;

    # GLX backend
    glx-no-stencil = true;
    glx-copy-from-front = false;
    glx-no-rebind-pixmap = true;
  '';
}
