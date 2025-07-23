{ config, pkgs, ... }:

let
  colors = import ./colors.nix;
  gruvboxDark = colors.gruvboxDark;
  workspaces = {
    "1" = "1 ";        # Terminals
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
          text = gruvboxDark.bg0Hard;
          indicator = gruvboxDark.purple;
          childBorder = gruvboxDark.bg0Hard;
        };
        focusedInactive = {
          border = gruvboxDark.bg0Hard;
          background = gruvboxDark.bg0Hard;
          text = gruvboxDark.yellow;
          indicator = gruvboxDark.purple;
          childBorder = gruvboxDark.bg0Hard;
        };
        unfocused = {
          border = gruvboxDark.bg0Hard;
          background = gruvboxDark.bg0Hard;
          text = gruvboxDark.yellow;
          indicator = gruvboxDark.purple;
          childBorder = gruvboxDark.bg0Hard;
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
        size = 16.0;
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
          always = true;
        }
        {
          command = "xss-lock -- ${config.home.homeDirectory}/.local/bin/lock &";
          always = true;
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
