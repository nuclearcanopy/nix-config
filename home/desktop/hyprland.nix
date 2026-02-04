{ ... }:

{
  wayland.windowManager.hyprland = {
    enable = true;

    settings = {

      # monitors
      monitor = [
        "DP-1,2560x1440@120,0x0,1"
        "HDMI-A-1,1920x1080@71.92,2560x380,1"
        "HDMI-A-2,1920x1080@60,300x1440,1"
      ];

      # programs
      "$terminal" = "alacritty";
      "$fileManager" = "thunar";
      "$mainMod" = "SUPER";
      "$secMod"  = "ALT";

      # environment
      env = [
        "XCURSOR_SIZE,24"
        "HYPRCURSOR_SIZE,24"
      ];

      # autostart
      exec-once = [
        "protonvpn-app"
        "dbus-update-activation-environment --systemd --all"
        "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE"
        "hyprpaper"
      ];

      # general
      general = {
        gaps_in = 0;
        gaps_out = 0;
        border_size = 4;

        "col.active_border" = "rgba(404040ff)";
        "col.inactive_border" = "rgba(121212aa)";

        resize_on_border = true;
        allow_tearing = false;
        layout = "dwindle";
      };

      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };

      master = {
        new_status = "master";
      };

      misc = {
        force_default_wallpaper = 0;
        disable_hyprland_logo = true;
      };

      # decoration
      decoration = {
        rounding = 15;
        rounding_power = 2;
        border_part_of_window = false;

        active_opacity = 1.0;
        inactive_opacity = 1.0;

        dim_inactive = false;
        dim_strength = 0.2;

        shadow = {
          enabled = true;
          range = 30;
          render_power = 2;
          color = "rgba(000000cc)";
          offset = "0 0";
        };

        blur = {
          enabled = true;
          size = 3;
          passes = 3;
          new_optimizations = "on";
          xray = false;
          input_methods = true;
          ignore_opacity = false;
          vibrancy = 0.18;
        };
      };

      # animations
      animations = {
        enabled = "yes, please :)";

        bezier = [
          "easeOutQuint,0.23,1,0.32,1"
          "easeInOutCubic,0.65,0.05,0.36,1"
          "linear,0,0,1,1"
          "almostLinear,0.5,0.5,0.75,1.0"
          "quick,0.15,0,0.1,1"
          "easeOutBrazy,0.17,0.67,0.31,1"
          "ease,0.15,0.9,0.1,1.0"
        ];

        animation = [
          "border,1,10,default"
          "windows,1,6,ease"
          "windowsOut,1,5,default,popin 80%"
          "fade,1,7,default"
          "workspaces,1,8,default,slidefadevert 5%"
        ];
      };

      # input
      input = {
        kb_layout = "us";
        follow_mouse = 1;
        sensitivity = -0.76;
        accel_profile = "flat";

        touchpad = {
          natural_scroll = false;
        };

        tablet = {
          transform = 0;
          output = "HDMI-A-2";
        };
      };

      # keybinds
      bind = [
        # launcher
        "CTRL,RETURN,exec,wofi --show drun --normal-window"
        "CTRL,BACKSPACE,exec,wofi --show run --normal-window"
        ",Print,exec,grim -g \"$(slurp -b 000000a0)\" - | wl-copy"
        "$mainMod,P,exec,hyprpicker"

        # apps
        "$mainMod,Q,exec,$terminal"
        "$mainMod,TAB,exec,librewolf"
        "$mainMod,G,exec,librewolf -P llm"
        "CTRL,Y,exec,freetube"

        # gpu profiles
        "$mainMod,Z,exec,lact cli profile set LOW && pkill -RTMIN+8 waybar"
        "$mainMod,X,exec,lact cli profile set MID && pkill -RTMIN+8 waybar"
        "$mainMod,C,exec,lact cli profile set MAX && pkill -RTMIN+8 waybar"

        # windows
        "$secMod,C,killactive"
        "$secMod,V,togglefloating"
        "$secMod,F,fullscreen,0"
        "$mainMod,J,togglesplit"
        "$mainMod,M,exit"

        # waybar
        "$mainMod $secMod,1,exec,pactl -- set-sink-mute 0 toggle"
        "$mainMod $secMod,2,exec,pactl set-source-mute @DEFAULT_SOURCE@ toggle"

        # focus
        "$mainMod,a,movefocus,l"
        "$mainMod,d,movefocus,r"
        "$mainMod,w,movefocus,u"
        "$mainMod,s,movefocus,d"

        # workspaces
        "$mainMod,1,workspace,1"
        "$mainMod,2,workspace,2"
        "$mainMod,3,workspace,3"
        "$mainMod,4,workspace,4"
        "$mainMod,5,workspace,5"
        "$mainMod,6,workspace,6"
        "$mainMod,7,workspace,7"
        "$mainMod,8,workspace,8"
        "$mainMod,9,workspace,9"
        "$mainMod,0,workspace,10"

        "$mainMod CTRL,1,movetoworkspace,1"
        "$mainMod CTRL,1,workspace,1"
        "$mainMod CTRL,2,movetoworkspace,2"
        "$mainMod CTRL,2,workspace,2"
        "$mainMod CTRL,3,movetoworkspace,3"
        "$mainMod CTRL,3,workspace,3"
        "$mainMod CTRL,4,movetoworkspace,4"
        "$mainMod CTRL,4,workspace,4"
        "$mainMod CTRL,5,movetoworkspace,5"
        "$mainMod CTRL,5,workspace,5"
        "$mainMod CTRL,6,movetoworkspace,6"
        "$mainMod CTRL,6,workspace,6"
        "$mainMod CTRL,7,movetoworkspace,7"
        "$mainMod CTRL,7,workspace,7"
        "$mainMod CTRL,8,movetoworkspace,8"
        "$mainMod CTRL,8,workspace,8"
        "$mainMod CTRL,9,movetoworkspace,9"
        "$mainMod CTRL,9,workspace,9"
        "$mainMod CTRL,0,movetoworkspace,10"
        "$mainMod CTRL,0,workspace,10"

        # scroll
        "$mainMod,mouse_down,workspace,e+1"
        "$mainMod,mouse_up,workspace,e-1"
      ];

      # defaults
      bindm = [
        "$mainMod,mouse:272,movewindow"
        "$mainMod,mouse:273,resizewindow"
      ];

      bindel = [
        ",XF86AudioRaiseVolume,exec,wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
        ",XF86AudioLowerVolume,exec,wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ",XF86AudioMute,exec,wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ",XF86AudioMicMute,exec,wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
        ",XF86MonBrightnessUp,exec,brightnessctl -e4 -n2 set 5%+"
        ",XF86MonBrightnessDown,exec,brightnessctl -e4 -n2 set 5%-"
      ];

      bindl = [
        ",XF86AudioNext,exec,playerctl next"
        ",XF86AudioPause,exec,playerctl play-pause"
        ",XF86AudioPlay,exec,playerctl play-pause"
        ",XF86AudioPrev,exec,playerctl previous"
      ];
    };
  };
}
