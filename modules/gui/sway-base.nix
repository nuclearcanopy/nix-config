{
  # Shared sway config for desktop (kuraokami) and laptop (nidhoggr).
  # Hosts add their own output/input/startup overrides on top via separate buckets.
  homeManager.modules.sway-base = { pkgs, ... }:

    let
      mod = "Mod4";
      alt = "Mod1";
    in
    {
      wayland.windowManager.sway = {
        enable = true;
        systemd = {
          enable = true;
          variables = [ "--all" ];
        };

        config = {
          terminal = "alacritty";
          menu = "j4-dmenu-desktop --dmenu='themed-bemenu'";
          modifier = mod;

          gaps = { inner = 0; outer = 0; };
          window = {
            border = 2;
            titlebar = false;
            commands = [
              {
                criteria = { app_id = "zenity"; };
                command = "floating enable, resize set 420 180, move position center";
              }
            ];
          };
          bars = [];

          keybindings = {
            "Control+Return" = "exec j4-dmenu-desktop --dmenu='themed-bemenu'";
            "Control+BackSpace" = "exec themed-bemenu-run";

            "Print" = "exec grim -g \"$(slurp -b 000000a0)\" - | wl-copy";
            "${mod}+p" = "exec hyprpicker";

            "${mod}+q" = "exec alacritty";
            "${mod}+Tab" = "exec firefox";

            "${alt}+c" = "kill";
            "${alt}+v" = "floating toggle";
            "${alt}+f" = "fullscreen toggle";
            "${mod}+j" = "layout toggle split";
            "${mod}+m" = "exit";

            "${mod}+${alt}+1" = "exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && pkill -SIGRTMIN+5 waybar";
            "${mod}+${alt}+2" = "exec wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
            "${mod}+${alt}+3" = "exec ${./waybar/scripts/caffeine.sh} toggle";
            "${mod}+${alt}+t" = "exec set-theme-mode toggle";
            "${mod}+${alt}+Shift+p" = "exec systemctl suspend";
            "${mod}+Shift+b" = "exec systemctl --user restart waybar.service";

            "${mod}+a" = "focus left";
            "${mod}+d" = "focus right";
            "${mod}+w" = "focus up";
            "${mod}+s" = "focus down";

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

            "${mod}+Shift+1" = "move container to workspace number 1";
            "${mod}+Shift+2" = "move container to workspace number 2";
            "${mod}+Shift+3" = "move container to workspace number 3";
            "${mod}+Shift+4" = "move container to workspace number 4";
            "${mod}+Shift+5" = "move container to workspace number 5";
            "${mod}+Shift+6" = "move container to workspace number 6";
            "${mod}+Shift+7" = "move container to workspace number 7";
            "${mod}+Shift+8" = "move container to workspace number 8";
            "${mod}+Shift+9" = "move container to workspace number 9";
            "${mod}+Shift+0" = "move container to workspace number 10";

            "${mod}+Shift+a" = "move left";
            "${mod}+Shift+d" = "move right";
            "${mod}+Shift+w" = "move up";
            "${mod}+Shift+s" = "move down";

            "${mod}+t" = "split toggle";

            "XF86AudioRaiseVolume" = "exec wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+ && pkill -SIGRTMIN+5 waybar";
            "XF86AudioLowerVolume" = "exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- && pkill -SIGRTMIN+5 waybar";
            "XF86AudioMute" = "exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && pkill -SIGRTMIN+5 waybar";
            "XF86AudioMicMute" = "exec wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
            "XF86MonBrightnessUp" = "exec set-brightness 5%+ && pkill -SIGRTMIN+4 waybar";
            "XF86MonBrightnessDown" = "exec set-brightness 5%- && pkill -SIGRTMIN+4 waybar";

            "XF86AudioNext" = "exec playerctl next";
            "XF86AudioPause" = "exec playerctl play-pause";
            "XF86AudioPlay" = "exec playerctl play-pause";
            "XF86AudioPrev" = "exec playerctl previous";
          };

          floating.modifier = mod;

          focus = {
            followMouse = true;
            mouseWarping = "container";
            # "smart" (the default) still honors self-activation requests,
            # which is how Minecraft/Xwayland yanks you across workspaces
            # without a click. "none" ignores those entirely; windows only
            # get focus from an explicit click or keybinding.
            newWindow = "none";
          };
        };

        # colors.conf is a symlink set-theme-mode flips between
        # colors-{dark,light}.conf (window border/bg/text/indicator/
        # childBorder + the output wallpaper color); applied instantly via
        # `swaymsg reload`, no rebuild needed.
        extraConfig = ''
          include ~/.config/sway/colors.conf
        '';
      };

      xdg.configFile."sway/colors-dark.conf".text = ''
        client.focused          #2a2a2a #000000 #f0f0f0 #2a2a2a #2a2a2a
        client.unfocused        #141414 #000000 #000000 #141414 #141414
        client.focused_inactive #1c1c1c #000000 #888888 #1c1c1c #1c1c1c
        output * background #000000 solid_color
      '';
      xdg.configFile."sway/colors-light.conf".text = ''
        client.focused          #a0a0a0 #f0f0f0 #000000 #a0a0a0 #a0a0a0
        client.unfocused        #e2e2e2 #f0f0f0 #f0f0f0 #e2e2e2 #e2e2e2
        client.focused_inactive #cfcfcf #f0f0f0 #868686 #cfcfcf #cfcfcf
        output * background #f0f0f0 solid_color
      '';
    };
}
