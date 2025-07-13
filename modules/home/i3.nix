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
in {
  # POLYBAR CONFIG
  services.polybar = {
    enable = true;
    config = {
      "bar/mainbar" = {
        monitor = "\${env:MONITOR:HDMI-1}";
        width = "100%";
        height = 30;
        font-0 = "FiraCode Nerd Font:size=11;2";
        background = gruvboxDark.bg;
        foreground = gruvboxDark.fg;
        modules-left = "workspaces";
        modules-center = "date";
        modules-right = "cpu memory wlan battery";
      };

      "module/date" = {
        type = "internal/date";
        format = " %Y-%m-%d  %H:%M";
      };

      "module/cpu" = {
        type = "internal/cpu";
        format = " %percentage%%";
      };

      "module/memory" = {
        type = "internal/memory";
        format = " %percentage_used%%";
      };

      "module/battery" = {
        type = "internal/battery";
        battery = "BAT0";
        adapter = "AC";
        full-at = 98;
        format-charging = " %percentage%%";
        format-discharging = "🔋 %percentage%%";
      };

      "module/wlan" = {
        type = "internal/network";
        interface = "wlan0";
        format-connected = " %essid";
        format-disconnected = "睊 Disconnected";
      };

      "module/workspaces" = {
        type = "internal/i3";
        format = "<label-state>";
        label-focused = "%name%";
        label-unfocused = "%name%";
        label-urgent = "%name%!";
      };
    };
    script = ''polybar mainbar & '';
  };

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
        size = 11.0;
      };

      gaps = {
        inner = 10;
        outer = 10;
        smartBorders = "on";
      };

      bars = [ ]; # Using polybar

      keybindings = {
        # Workspaces
        "${config.xsession.windowManager.i3.config.modifier}+1" = "workspace 1: $";        # Terminal
        "${config.xsession.windowManager.i3.config.modifier}+2" = "workspace 2: ";        # VSCode
        "${config.xsession.windowManager.i3.config.modifier}+3" = "workspace 3: ";        # Firefox
        "${config.xsession.windowManager.i3.config.modifier}+4" = "workspace 4: ";        # Xchat
        "${config.xsession.windowManager.i3.config.modifier}+5" = "workspace 5: ";        # Steam
        "${config.xsession.windowManager.i3.config.modifier}+6" = "workspace 6: ";        # Terminals
        "${config.xsession.windowManager.i3.config.modifier}+7" = "workspace 7: ";        # Firefox
        "${config.xsession.windowManager.i3.config.modifier}+8" = "workspace 8: ";        # File Manager
        "${config.xsession.windowManager.i3.config.modifier}+9" = "workspace 9: ";        # External Display

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
        "${config.xsession.windowManager.i3.config.modifier}+Shift+l" = "exec i3lock -c 000000";

        # Restart/exit
        "${config.xsession.windowManager.i3.config.modifier}+Shift+r" = "restart";
        "${config.xsession.windowManager.i3.config.modifier}+Shift+e" = "exec i3-nagbar -t warning -m 'Exit i3?' -b 'Yes' 'i3-msg exit'";
        "${config.xsession.windowManager.i3.config.modifier}+Shift+q" = "kill";
      };

      startup = [
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
}
