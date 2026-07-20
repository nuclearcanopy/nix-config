{
  # Shared sway config for desktop (kuraokami) and laptop (nidhoggr).
  # Hosts add their own output/input/startup overrides on top via separate buckets.
  homeManager.modules.sway-base = { pkgs, ... }:

    let
      bemenuStyle = ''-i -c -l 5 -W 0.20 -B 0 -p "" --fn "monospace 16" --tb "#000000" --tf "#cccccc" --fb "#000000" --ff "#cccccc" --nb "#000000" --nf "#888888" --ab "#000000" --af "#888888" --hb "#000000" --hf "#ffffff" --sb "#000000" --sf "#ffffff" --scb "#000000" --scf "#888888"'';
      mod = "Mod4";
      alt = "Mod1";
      caffeineToggle = pkgs.writeShellScript "caffeine-toggle" ''
        PIDFILE="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/waybar-caffeine.pid"
        if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
          kill "$(cat "$PIDFILE")"
          rm -f "$PIDFILE"
        else
          systemd-inhibit --what=idle:sleep:handle-lid-switch --who=waybar-caffeine \
            --why="Caffeine mode active" --mode=block \
            sleep infinity &
          echo $! > "$PIDFILE"
        fi
        pkill -RTMIN+8 waybar
      '';
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
          menu = "j4-dmenu-desktop --dmenu='bemenu ${bemenuStyle}'";
          modifier = mod;

          gaps = { inner = 0; outer = 0; };
          window = {
            border = 4;
            titlebar = false;
            commands = [
              {
                criteria = { app_id = "zenity"; };
                command = "floating enable, resize set 420 180, move position center";
              }
            ];
          };
          bars = [];

          colors = {
            focused = {
              border = "#000000";
              background = "#000000";
              text = "#f0f0f0";
              indicator = "#000000";
              childBorder = "#000000";
            };
            unfocused = {
              border = "#000000";
              background = "#000000";
              text = "#000000";
              indicator = "#000000";
              childBorder = "#000000";
            };
            focusedInactive = {
              border = "#000000";
              background = "#000000";
              text = "#888888";
              indicator = "#000000";
              childBorder = "#000000";
            };
          };

          keybindings = {
            "Control+Return" = "exec j4-dmenu-desktop --dmenu='bemenu ${bemenuStyle}'";
            "Control+BackSpace" = "exec bemenu-run ${bemenuStyle}";

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
            "${mod}+${alt}+3" = "exec ${caffeineToggle}";
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
          };
        };

        extraConfig = ''
          bindsym --no-repeat Control+space exec sh -c '[ "$(cat $HOME/.local/state/waybar-vis 2>/dev/null || echo SHW)" = HID ] && pkill -SIGUSR1 waybar'
          bindsym --release Control+space exec sh -c '[ "$(cat $HOME/.local/state/waybar-vis 2>/dev/null || echo SHW)" = HID ] && pkill -SIGUSR1 waybar'
        '';
      };
    };
}
