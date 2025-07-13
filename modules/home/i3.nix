{ config, pkgs, ... }:

let
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
  workspaces = {
    "1" = "1 ";        # Terminal
    "2" = "2 ";        # VSCode
    "3" = "3 ";        # Firefox
    "4" = "4 ";        # Xchat
    "5" = "5 ";        # Steam
    "6" = "6 ";        # Terminals
    "7" = "7 ";        # Chromium
    "8" = "8 ";        # File Manager
    "9" = "9 ";        # External Display
  };
in {
  xsession.windowManager.i3 = {
    enable = true;

    config = {
      colors = {
        background = gruvboxDark.bg;
        focused = {
          border = gruvboxDark.yellow;
          background = gruvboxDark.yellow;
          text = gruvboxDark.bg;
          indicator = gruvboxDark.yellow;
          childBorder = gruvboxDark.yellow;
        };
        focusedInactive = {
          border = gruvboxDark.gray;
          background = gruvboxDark.bg;
          text = gruvboxDark.gray;
          indicator = gruvboxDark.gray;
          childBorder = gruvboxDark.gray;
        };
        unfocused = {
          border = gruvboxDark.black;
          background = gruvboxDark.bg;
          text = gruvboxDark.gray;
          indicator = gruvboxDark.black;
          childBorder = gruvboxDark.black;
        };
        urgent = {
          border = gruvboxDark.red;
          background = gruvboxDark.red;
          text = gruvboxDark.fg;
          indicator = gruvboxDark.red;
          childBorder = gruvboxDark.red;
        };
      };

      terminal = "alacritty";
      modifier = "Mod4";
      fonts = {
        names = [ "FiraCode Nerd Font" ];
        size = 24.0;
      };

      gaps = {
        inner = 10;
        outer = 10;
        smartBorders = "on";
      };

      bars = [ ]; # Using polybar

      keybindings = {
        # Workspaces
        "${config.xsession.windowManager.i3.config.modifier}+1" = "workspace \"${workspaces."1"}\"";
        "${config.xsession.windowManager.i3.config.modifier}+2" = "workspace \"${workspaces."2"}\"";
        "${config.xsession.windowManager.i3.config.modifier}+3" = "workspace \"${workspaces."3"}\"";
        "${config.xsession.windowManager.i3.config.modifier}+4" = "workspace \"${workspaces."4"}\"";
        "${config.xsession.windowManager.i3.config.modifier}+5" = "workspace \"${workspaces."5"}\"";
        "${config.xsession.windowManager.i3.config.modifier}+6" = "workspace \"${workspaces."6"}\"";
        "${config.xsession.windowManager.i3.config.modifier}+7" = "workspace \"${workspaces."7"}\"";
        "${config.xsession.windowManager.i3.config.modifier}+8" = "workspace \"${workspaces."8"}\"";
        "${config.xsession.windowManager.i3.config.modifier}+9" = "workspace \"${workspaces."9"}\"";

        # Move containers to workspaces
        "${config.xsession.windowManager.i3.config.modifier}+Shift+1" = "move container to workspace \"${workspaces."1"}\"";
        "${config.xsession.windowManager.i3.config.modifier}+Shift+2" = "move container to workspace \"${workspaces."2"}\"";
        "${config.xsession.windowManager.i3.config.modifier}+Shift+3" = "move container to workspace \"${workspaces."3"}\"";
        "${config.xsession.windowManager.i3.config.modifier}+Shift+4" = "move container to workspace \"${workspaces."4"}\"";
        "${config.xsession.windowManager.i3.config.modifier}+Shift+5" = "move container to workspace \"${workspaces."5"}\"";
        "${config.xsession.windowManager.i3.config.modifier}+Shift+6" = "move container to workspace \"${workspaces."6"}\"";
        "${config.xsession.windowManager.i3.config.modifier}+Shift+7" = "move container to workspace \"${workspaces."7"}\"";
        "${config.xsession.windowManager.i3.config.modifier}+Shift+8" = "move container to workspace \"${workspaces."8"}\"";
        "${config.xsession.windowManager.i3.config.modifier}+Shift+9" = "move container to workspace \"${workspaces."9"}\"";

        # Launch apps
        "${config.xsession.windowManager.i3.config.modifier}+Return" = "exec alacritty";
        "${config.xsession.windowManager.i3.config.modifier}+d" = "exec rofi -show drun";

        # Scratchpad terminal
        "${config.xsession.windowManager.i3.config.modifier}+Shift+minus" = "move container to scratchpad";
        "${config.xsession.windowManager.i3.config.modifier}+minus" = "scratchpad show";

        # Volume keys
        "XF86AudioRaiseVolume" = "exec --no-startup-id pamixer -i 5";
        "XF86AudioLowerVolume" = "exec --no-startup-id pamixer -d 5";
        "XF86AudioMute" = "exec --no-startup-id pamixer -t";

        # Brightness (optional)
        "XF86MonBrightnessUp" = "exec brightnessctl set +10%";
        "XF86MonBrightnessDown" = "exec brightnessctl set 10%-";

        # Lock screen
        "${config.xsession.windowManager.i3.config.modifier}+Shift+l" = "exec i3lock -n -i $HOME/git/nix-config/assets/wallpaper.png";

        # Restart/exit
        "${config.xsession.windowManager.i3.config.modifier}+Shift+w" = "reload";
        "${config.xsession.windowManager.i3.config.modifier}+Shift+r" = "restart";
        "${config.xsession.windowManager.i3.config.modifier}+Shift+e" = "exec i3-nagbar -t warning -m 'Exit i3?' -b 'Yes' 'i3-msg exit'";
        "${config.xsession.windowManager.i3.config.modifier}+Shift+q" = "kill";
      };

      assigns = {
        "${workspaces."1"}" = [ { class = "^Alacritty$"; } { class = "^Xterm$"; } ];
        "${workspaces."2"}" = [ { class = "^Code$"; } ];
        "${workspaces."3"}" = [ { class = "^Firefox$"; } ];
        "${workspaces."4"}" = [ { class = "^Xchat$"; } ];
        "${workspaces."5"}" = [ { class = "^Steam$"; } ];
        "${workspaces."7"}" = [ { class = "^Chromium$"; } ];
        "${workspaces."8"}" = [ { class = "^Thunar$"; } ];
      };

      startup = [
        {
          command = "pkill polybar || true";
          always = true;
        }
        {
          command = "polybar mainbar &";
          always = true;
        }
        {
          command = "picom --config ~/.config/picom/picom.conf &";
          always = true;
        }
        {
          command = "feh --bg-fill ~/git/nix-config/assets/wallpaper.png";
          always = true;
        }
        {
          command = "alacritty --title scratchpad-terminal --class scratchpad-terminal";
          always = false;
          notification = false;
        }
      ];
    };
  };

  # POLYBAR CONFIG
  services.polybar = {
    enable = true;
    config = {
      "bar/mainbar" = {
        monitor = "\${env:MONITOR:eDP-1}";
        width = "100%";
        height = "3%";
        bottom = true;
        font-0 = "FiraCode Nerd Font:size=24;2";
        background = gruvboxDark.bg;
        foreground = gruvboxDark.fg;
        modules-left = "xworkspaces";
        modules-center = "date";
        modules-right = "cpu memory wlan battery";
      };

      "module/xworkspaces" = {
        type = "internal/xworkspaces";
        label-active = "%name%";
        label-active-background = gruvboxDark.bg;
        label-active-foreground = gruvboxDark.fg;
        label-active-padding = "4";
        label-occupied = "%name%";
        label-occupied-background = gruvboxDark.bg;
        label-occupied-foreground = gruvboxDark.blue;
        label-occupied-padding = "4";
        label-empty = "%name%";
        label-empty-background = gruvboxDark.bg;
        label-empty-foreground = gruvboxDark.gray;
        label-empty-padding = "4";
        label-urgent = "%name%!";
        label-urgent-background = gruvboxDark.red;
        label-urgent-foreground = gruvboxDark.fg;
        label-urgent-padding = "4";
      };

      "module/date" = {
        type = "internal/date";
        interval = "1.0";
        date = "%Y-%m-%d%";
        time = "%H:%M";
        date-alt = "%A, %d %B %Y";
        time-alt = "%H:%M:%S";
        format = " <label>";
        label = "%date% %time%";
      };

      "module/cpu" = {
        type = "internal/cpu";
        format = " %percentage%%";
      };

      "module/memory" = {
        type = "internal/memory";
        format = "󰍛 %percentage_used%%";
      };

      "module/battery" = {
        type = "internal/battery";
        battery = "BAT0";
        adapter = "AC";
        full-at = 98;
        format-charging = " %percentage% %";
        format-discharging = "🔋 %percentage%%";
      };

      "module/wlan" = {
        type = "internal/network";
        interface = "wlp0s20f3";
        format-connected = " %essid";
        format-disconnected = "睊 Disconnected";
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
