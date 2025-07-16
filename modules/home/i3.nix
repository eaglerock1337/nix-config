{ config, pkgs, ... }:

let
  gruvboxDark = {
    bg = "#282828";
    fg = "#ebdbb2";
    red = "#cc241d";
    green = "#98971a";
    yellow = "#d79921";
    blue = "#458588";
    purple = "#b16286";
    aqua = "#689d68";
    gray = "#a89984";
    darkgray = "#1d2021";
  };
  workspaces = {
    "1" = "1 ";        # Terminal
    "2" = "2 ";        # VSCode
    "3" = "3 ";        # Firefox
    "4" = "4 ";        # Chat programs
    "5" = "5 ";        # Steam
    "6" = "6 ";        # Terminals
    "7" = "7 ";        # Chromium
    "8" = "8 ";        # File Manager
    "9" = "9 ";        # External Display
    "10" = "10 ";      # External Display
  };
  wallpaper = "~/git/nix-config/assets/wallpaper-gibson.png";
in {
  # TODO: See if this is needed
  # xresources = {
  #   enable = true;
  #   settings = {
  #     # bump from 96 to e.g. 144 DPI
  #     "Xft.dpi" = 144;
  #   };
  # };

  xsession.windowManager.i3 = {
    enable = true;
    
    config = {
      colors = {
        background = gruvboxDark.bg;
        focused = {
          border = gruvboxDark.blue;
          background = gruvboxDark.blue;
          text = gruvboxDark.darkgray;
          indicator = gruvboxDark.purple;
          childBorder = gruvboxDark.darkgray;
        };
        focusedInactive = {
          border = gruvboxDark.darkgray;
          background = gruvboxDark.darkgray;
          text = gruvboxDark.yellow;
          indicator = gruvboxDark.purple;
          childBorder = gruvboxDark.darkgray;
        };
        unfocused = {
          border = gruvboxDark.darkgray;
          background = gruvboxDark.darkgray;
          text = gruvboxDark.yellow;
          indicator = gruvboxDark.purple;
          childBorder = gruvboxDark.darkgray;
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
      floating.modifier = "${config.xsession.windowManager.i3.config.modifier}";

      fonts = {
        names = [ "FiraCode Nerd Font" ];
        size = 18.0;
      };

      gaps = {
        inner = 10;
        outer = 10;
        smartBorders = "on";
      };

      bars = [ ]; # Using polybar

      keybindings = {
        # Launch apps
        "${config.xsession.windowManager.i3.config.modifier}+Return" = "exec alacritty";
        "${config.xsession.windowManager.i3.config.modifier}+d" = "exec rofi -show drun";

        # Change focus
        "${config.xsession.windowManager.i3.config.modifier}+j" = "focus left";
        "${config.xsession.windowManager.i3.config.modifier}+k" = "focus down";
        "${config.xsession.windowManager.i3.config.modifier}+l" = "focus up";
        "${config.xsession.windowManager.i3.config.modifier}+semicolon" = "focus right";  

        # Change focus with cursor keys
        "${config.xsession.windowManager.i3.config.modifier}+Left" = "focus left";
        "${config.xsession.windowManager.i3.config.modifier}+Down" = "focus down";
        "${config.xsession.windowManager.i3.config.modifier}+Up" = "focus up";
        "${config.xsession.windowManager.i3.config.modifier}+Right" = "focus right";

        # Move focused window
        "${config.xsession.windowManager.i3.config.modifier}+Shift+j" = "move left";
        "${config.xsession.windowManager.i3.config.modifier}+Shift+k" = "move down";
        "${config.xsession.windowManager.i3.config.modifier}+Shift+l" = "move up";
        "${config.xsession.windowManager.i3.config.modifier}+Shift+semicolon" = "move right";

        # Move focused window with cursor keys
        "${config.xsession.windowManager.i3.config.modifier}+Shift+Left" = "move left";
        "${config.xsession.windowManager.i3.config.modifier}+Shift+Down" = "move down"; 
        "${config.xsession.windowManager.i3.config.modifier}+Shift+Up" = "move up";
        "${config.xsession.windowManager.i3.config.modifier}+Shift+Right" = "move right";

        # Split windows
        "${config.xsession.windowManager.i3.config.modifier}+v" = "split vertical";
        "${config.xsession.windowManager.i3.config.modifier}+h" = "split horizontal";

        # Fullscreen focused window
        "${config.xsession.windowManager.i3.config.modifier}+f" = "fullscreen";

        # Change container layout
        "${config.xsession.windowManager.i3.config.modifier}+s" = "layout stacking";
        "${config.xsession.windowManager.i3.config.modifier}+w" = "layout tabbed";
        "${config.xsession.windowManager.i3.config.modifier}+e" = "layout toggle split";

        # Toggle floating mode
        "${config.xsession.windowManager.i3.config.modifier}+Shift+space" = "floating toggle";

        # Change focus between tiling and floating windows
        "${config.xsession.windowManager.i3.config.modifier}+space" = "focus mode_toggle";

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
        "${config.xsession.windowManager.i3.config.modifier}+0" = "workspace \"${workspaces."10"}\"";

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
        "${config.xsession.windowManager.i3.config.modifier}+Shift+0" = "move container to workspace \"${workspaces."10"}\"";

        # Restart/exit
        "${config.xsession.windowManager.i3.config.modifier}+Shift+c" = "reload";
        "${config.xsession.windowManager.i3.config.modifier}+Shift+r" = "restart";
        "${config.xsession.windowManager.i3.config.modifier}+Shift+e" = "exec i3-nagbar -t warning -m 'Exit i3?' -b 'Yes' 'i3-msg exit'";
        "${config.xsession.windowManager.i3.config.modifier}+Shift+q" = "kill";

        # Enter resize mode
        "${config.xsession.windowManager.i3.config.modifier}+r" = "mode resize";

        # Custom Stuff

        # Print screen
        "${config.xsession.windowManager.i3.config.modifier}+p" = "exec scrot ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png";
        "${config.xsession.windowManager.i3.config.modifier}+Shift+p" = "exec flameshot gui";

        # Lock screen
        "${config.xsession.windowManager.i3.config.modifier}+Shift+x" = "exec ~/.local/bin/lock";

        # Volume keys
        "XF86AudioRaiseVolume" = "exec --no-startup-id pamixer -i 5";
        "XF86AudioLowerVolume" = "exec --no-startup-id pamixer -d 5";
        "XF86AudioMute" = "exec --no-startup-id pamixer -t";

        # Brightness (optional)
        "XF86MonBrightnessUp" = "exec brightnessctl set +10%";
        "XF86MonBrightnessDown" = "exec brightnessctl set 10%-";

        # Scratchpad terminal
        "${config.xsession.windowManager.i3.config.modifier}+Shift+minus" = "move scratchpad";
        "${config.xsession.windowManager.i3.config.modifier}+minus" = "scratchpad show";

        # TODO: Enable later
        # # Toggle workspace between monitors
        # "${config.xsession.windowManager.i3.config.modifier}+x" = "move workspace to output right"; 

        # Switch between tty sessions
        # "${config.xsession.windowManager.i3.config.modifier}+Shift+F1" = "exec --no-startup-id chvt 1";
        # "${config.xsession.windowManager.i3.config.modifier}+Shift+F2" = "exec --no-startup-id chvt 2";
        # "${config.xsession.windowManager.i3.config.modifier}+Shift+F3" = "exec --no-startup-id chvt 3";
        # "${config.xsession.windowManager.i3.config.modifier}+Shift+F4" = "exec --no-startup-id chvt 4";
        # "${config.xsession.windowManager.i3.config.modifier}+Shift+F5" = "exec --no-startup-id chvt 5";
        # "${config.xsession.windowManager.i3.config.modifier}+Shift+F6" = "exec --no-startup-id chvt 6";
        # "${config.xsession.windowManager.i3.config.modifier}+Shift+F7" = "exec --no-startup-id chvt 7";

      };

      # Resize mode keybindings
      modes.resize = {
        "j"  = "resize shrink width 10 px or 10 ppt";
        "k"  = "resize grow height 10 px or 10 ppt";
        "l"    = "resize shrink height 10 px or 10 ppt";
        "semicolon" = "resize grow width 10 px or 10 ppt";

        "Left"  = "resize shrink width 10 px or 10 ppt";
        "Down"  = "resize grow height 10 px or 10 ppt";
        "Up"    = "resize shrink height 10 px or 10 ppt";
        "Right" = "resize grow width 10 px or 10 ppt";

        # Exit resize mode with Escape or Return
        "Return" = "mode default";
        "Escape" = "mode default";
      };

      assigns = {
        "${workspaces."2"}" = [ { class = "^Code$"; } ];
        "${workspaces."3"}" = [ { class = "^firefox$"; } ];
        "${workspaces."4"}" = [ { class = "^Hexchat$"; } { class = "^discord$"; } ];
        "${workspaces."5"}" = [ { class = "^steam$"; } ];
        "${workspaces."7"}" = [ { class = "^Chromium$"; } ];
        "${workspaces."8"}" = [ { class = "^Thunar$"; } ];
      };

      # TODO: Enable later
      # workspaceOutputAssign = [
      #   {
      #     workspace = "9";
      #     output = "HDMI-1";
      #   }
      #   {
      #     workspace = "10";
      #     output = "HDMI-1";
      #   }
      # ];

      startup = [
        {
          command = "xrandr --output eDP-1 --scale 0.8x0.8 --dpi 144";
        }
        {
          command = "systemctl --user restart polybar.service";
          always = true;
        }
        {
          command = "picom --config ~/.config/picom/picom.conf &";
          always = true;
        }
        {
          command = "feh --bg-fill ${wallpaper}";
          always = true;
        }
        {
          command = ''i3-msg "workspace ${workspaces."1"}; append_layout ${./layouts/workspace-1.json}"'';
          always = false;
        }
        {
          command = ''i3-msg "workspace ${workspaces."1"}; exec alacritty --class Terminal"'';
          always = false;
          notification = false;
        }
        {
          command = ''i3-msg "workspace ${workspaces."1"}; exec alacritty --class Terminal"'';
          always = false;
          notification = false;
        }        
        {
          command = ''i3-msg "workspace ${workspaces."1"}; exec alacritty --class Terminal"'';
          always = false;
          notification = false;
        }
        {
          command = ''i3-msg "workspace ${workspaces."1"}"'';
          always = false;
          notification = false;
        }
        {
          command = ''i3-msg "exec alacritty --class Scratchpad"'';
          always = false;
          notification = false;
        }
      ];

      window.commands = [
        {
          criteria = { 
            instance = "^Scratchpad$";
            class = "^Scratchpad$";
          };
          command = "floating enable";
        }
        {
          criteria = { 
            instance = "^Scratchpad$";
            class = "^Scratchpad$";
          };
          command = "move scratchpad; scratchpad show; resize set 1600px 960px; move position 224px 80px; scratchpad show";
        }
      ];
    };
  };

  # TODO: Enable this command later
  # {
  #   command = "xrandr --output HDMI-1 --mode 1920x1080 --right-of eDP-1";
  # }

  # POLYBAR CONFIG
  services.polybar = {
    enable = true;
    config = {
      "bar/mainbar" = {
        monitor = "\${env:MONITOR:eDP-1}";
        width = "100%";
        height = "4%";
        bottom = true;
        font-0 = "FiraCode Nerd Font:size=18;2";
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
        label-active-foreground = gruvboxDark.yellow;
        label-active-padding = "1";
        label-occupied = "%name% ";
        label-occupied-background = gruvboxDark.bg;
        label-occupied-foreground = gruvboxDark.blue;
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
        label-connected = "%essid% %signal:2%% ";
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
        label = "CPU %percentage:2%%";
      };

      "module/temperature" = {
        type = "internal/temperature";
        thermal-zone = 0;
        interval = 5;
        format = " <label>";
        format-padding = 1;
        format-foreground = gruvboxDark.yellow;
        label = "%temperature:C%";
      };

      "module/memory" = {
        type = "internal/memory";
        format = " <label>";
        format-padding = 1;
        format-foreground = gruvboxDark.aqua;
        label = "RAM %free:0:2%GiB";
      };

      "module/filesystem" = {
        type = "internal/fs";
        mount-0 = "/";
        interval = 10;
        format-mounted = " <label-mounted>";
        format-mounted-padding = 1;
        format-mounted-foreground = gruvboxDark.red;
        label-mounted = "%free% Free";
      };

      "module/battery" = {
        type = "internal/battery";
        battery = "BAT0";
        adapter = "AC";
        full-at = 97;
        low-at = 10;
        poll-interval = 5;
        format-full-padding = 1;
        format-full-foreground = gruvboxDark.green;
        format-full = " <label-full>";
        label-full = "%percentage%%";
        format-charging-foreground = gruvboxDark.yellow;
        format-charging-padding = 1;
        format-charging = "<animation-charging> <label-charging>";
        label-charging = "%percentage%%";
        animation-charging-0 = "󰢟";
        animation-charging-1 = "󱊤";
        animation-charging-2 = "󱊥";
        animation-charging-3 = "󱊦";
        animation-charging-framerate = 2000;
        format-discharging = "<animation-discharging> <label-discharging>";
        format-discharging-padding = 1;
        format-discharging-foreground = gruvboxDark.yellow;
        label-discharging = "%percentage%%";
        animation-discharging-0 = "󱊣";
        animation-discharging-1 = "󱊢";
        animation-discharging-2 = "󱊡";
        animation-discharging-3 = "󰂎";
        animation-discharging-framerate = 2000;
        format-low = "󰂃 <label-low>";
        format-low-padding = 1;
        format-low-foreground = gruvboxDark.red;
        label-low = "%percentage%%";
      };

      "module/date" = {
        type = "internal/date";
        interval = 1;
        date = "%Y-%m-%d%";
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
