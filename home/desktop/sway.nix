{ ... }:

let
  bemenuStyle = ''-i -c -l 5 -W 0.20 -B 0 -p "" --fn "monospace 16" --tb "#060606" --tf "#cccccc" --fb "#060606" --ff "#cccccc" --nb "#060606" --nf "#888888" --ab "#060606" --af "#888888" --hb "#0d0d0d" --hf "#ffffff" --sb "#060606" --sf "#ffffff" --scb "#060606" --scf "#888888"'';
in
{
  wayland.windowManager.sway = {
    enable = true;

    config = {
      # variables
      terminal = "alacritty";
      menu = "j4-dmenu-desktop --dmenu='bemenu ${bemenuStyle}'";
      
      modifier = "Mod4";  # super

      # monitors
      output = {
        "DP-1" = {
          mode = "2560x1440@119.998Hz";
          #adaptive_sync = "off";
          position = "0,0";
          scale = "1";
          bg = "#060606 solid_color";
        };
        "HDMI-A-1" = {
          mode = "1920x1080@71.92Hz";
          position = "2560,380";
          scale = "1";
          bg = "#060606 solid_color";
        };
        "HDMI-A-2" = {
          mode = "1920x1080@60Hz";
          position = "300,1440";
          scale = "1";
          bg = "#060606 solid_color";
        };
      };

      # ws assign
      workspaceOutputAssign = [
        { workspace = "1"; output = "DP-1"; }
        { workspace = "2"; output = "HDMI-A-1"; }
        { workspace = "3"; output = "HDMI-A-2"; }
      ];

      # input
      input = {
        "*" = {
          xkb_layout = "us";
          accel_profile = "flat";
          pointer_accel = "-0.76";
        };

        "type:touchpad" = {
          natural_scroll = "disabled";
        };

        "type:tablet_tool" = {
          map_to_output = "HDMI-A-2";
        };
      };

      # general
      gaps = {
        inner = 0;
        outer = 0;
      };

      window = {
        border = 4;
        titlebar = false;
      };

      # no bar
      bars = [];

      # colors
      colors = {
        focused = {
          border = "#060606";
          background = "#060606";
          text = "#f0f0f0";
          indicator = "#060606";
          childBorder = "#060606";
        };
        unfocused = {
          border = "#060606";
          background = "#060606";
          text = "#060606";
          indicator = "#060606";
          childBorder = "#060606";
        };
        focusedInactive = {
          border = "#060606";
          background = "#060606";
          text = "#888888";
          indicator = "#060606";
          childBorder = "#060606";
        };
      };

      # autostart
      startup = [
        { command = "mullvad-gui"; }
        { command = "dbus-update-activation-environment --systemd --all"; }
        { command = "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE"; }
        { command = "waybar"; }
        { command = "easyeffects -w"; }
      ];

      # keybinds
      keybindings = let
        mod = "Mod4";  # super
        alt = "Mod1";  # alt
      in {
        # launcher
        "Control+Return" = "exec j4-dmenu-desktop --dmenu='bemenu ${bemenuStyle}'";
        "Control+BackSpace" = "exec bemenu-run ${bemenuStyle}";

        "Print" = "exec grim -g \"$(slurp -b 000000a0)\" - | wl-copy";
        "${mod}+p" = "exec hyprpicker";

        # apps
        "${mod}+q" = "exec alacritty";
        "${mod}+Tab" = "exec librewolf";
        "${mod}+g" = "exec librewolf -P llm";
        "Control+y" = "exec freetube";

        # gpu profiles
        "${mod}+z" = "exec lact cli profile set LOW && pkill -RTMIN+8 waybar";
        "${mod}+x" = "exec lact cli profile set MID && pkill -RTMIN+8 waybar";
        "${mod}+c" = "exec lact cli profile set MAX && pkill -RTMIN+8 waybar";

        # windows
        "${alt}+c" = "kill";
        "${alt}+v" = "floating toggle";
        "${alt}+f" = "fullscreen toggle";
        "${mod}+j" = "layout toggle split";
        "${mod}+m" = "exit";

        # waybar
        "${mod}+${alt}+1" = "exec pactl -- set-sink-mute 0 toggle";
        "${mod}+${alt}+2" = "exec pactl set-source-mute @DEFAULT_SOURCE@ toggle";

        # focus
        "${mod}+a" = "focus left";
        "${mod}+d" = "focus right";
        "${mod}+w" = "focus up";
        "${mod}+s" = "focus down";

        # workspaces
        "${mod}+1" = "workspace number 1";
        "${mod}+2" = "workspace number 2";
        "${mod}+3" = "workspace number 3";
        "${mod}+4" = "workspace number 4";
        "${mod}+5" = "workspace number 5";
        "${mod}+6" = "workspace number 6";
        "${mod}+7" = "workspace number 7";
        "${mod}+8" = "workspace number 8";
        "${mod}+9" = "workspace number 9";
        "${mod}+0" = "workspace number 10";

        # move
        "${mod}+Control+1" = "move container to workspace number 1";
        "${mod}+Control+2" = "move container to workspace number 2";
        "${mod}+Control+3" = "move container to workspace number 3";
        "${mod}+Control+4" = "move container to workspace number 4";
        "${mod}+Control+5" = "move container to workspace number 5";
        "${mod}+Control+6" = "move container to workspace number 6";
        "${mod}+Control+7" = "move container to workspace number 7";
        "${mod}+Control+8" = "move container to workspace number 8";
        "${mod}+Control+9" = "move container to workspace number 9";
        "${mod}+Control+0" = "move container to workspace number 10";

        "${mod}+Shift+a" = "move left";
        "${mod}+Shift+d" = "move right";
        "${mod}+Shift+w" = "move up";
        "${mod}+Shift+s" = "move down";

        "${mod}+t" = "split toggle";  # toggle between h/v

        # media
        "XF86AudioRaiseVolume" = "exec wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+";
        "XF86AudioLowerVolume" = "exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
        "XF86AudioMute" = "exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        "XF86AudioMicMute" = "exec wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
        "XF86MonBrightnessUp" = "exec brightnessctl -e4 -n2 set 5%+";
        "XF86MonBrightnessDown" = "exec brightnessctl -e4 -n2 set 5%-";

        "XF86AudioNext" = "exec playerctl next";
        "XF86AudioPause" = "exec playerctl play-pause";
        "XF86AudioPlay" = "exec playerctl play-pause";
        "XF86AudioPrev" = "exec playerctl previous";
      };

      # floating
      floating = {
        modifier = "Mod4";
      };

      # mouse
      focus = {
        followMouse = true;
        mouseWarping = "container";
      };
    };
  };
}
