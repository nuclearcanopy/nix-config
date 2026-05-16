{ ... }:

# Laptop waybar config.
# Differences from kuraokami:
#   - Output: all outputs (no hardcoded DP-1/DP-2)
#   - Removed: custom/gpu (no LACT)
#   - custom/mouse: shared script, falls back to hidpp_battery_0 (Logitech G502X)
#   - Added: battery module (critical for laptop)
#   - Scripts reused from home/desktop/waybar/scripts/
{
  programs.waybar = {
    enable = true;
    systemd = { enable = true; target = "sway-session.target"; };
    style = builtins.readFile ../../../../home/desktop/waybar/style.css;

    settings = {
      mainBar = {
        reload_style_on_change = false;  # saves CPU - disable when not theming
        fixed-center = true;
        layer = "top";
        position = "top";
        height = 39;
        spacing = 0;

        modules-left = [
          "clock#date"
          "custom/time"
          "custom/sep"
          "custom/volume"
          "wireplumber"
          "custom/sep"
          "custom/brightness"
          "custom/caffeine"
          "custom/sep"
          "custom/vpn"
          "custom/thermalmode"
          "group/expand"
        ];
        modules-center = [
          "sway/workspaces"
        ];
        modules-right = [
          "custom/memory"
          "custom/sep"
          "custom/cpu"
          "custom/battery"
          "custom/mouse"
          "custom/sep"
          "custom/firmware"
          "custom/reboot"
          "custom/sleep"
          "custom/power"
        ];

        "custom/sep" = {
          format = "|";
          tooltip = false;
        };

        "custom/sleep" = {
          format = "SLP";
          on-click-middle = "systemctl suspend";
          tooltip = false;
        };

        "custom/power" = {
          format = "PWR";
          on-click-middle = "systemctl poweroff";
          tooltip = false;
        };

        "custom/firmware" = {
          format = "FRM";
          on-click-middle = "systemctl reboot --firmware-setup";
          tooltip = false;
        };

        "custom/reboot" = {
          format = "RBT";
          on-click-middle = "systemctl reboot";
          tooltip = false;
        };

        "custom/expand" = {
          format = ">";
          tooltip = false;
        };

        "group/expand" = {
          orientation = "horizontal";
          drawer = {
            transition-duration = 0;
            transition-to-right = true;
            click-to-reveal = true;
          };
          modules = [ "custom/expand" "tray" ];
        };

        tray = {
          icon-size = 17;
          spacing = 6;
        };

        "custom/caffeine" = {
          exec = "${../../../../home/desktop/waybar/scripts/caffeine.sh}";
          return-type = "json";
          interval = "once";
          signal = 8;
          on-click = "${../../../../home/desktop/waybar/scripts/caffeine.sh} toggle";
          tooltip = true;
        };

        "custom/vpn" = {
          exec = "${./scripts/vpn_status.sh}";
          interval = 10;
          signal = 9;
          on-click = "${../../../../home/desktop/waybar/scripts/vpn_cycle.sh} next";
          on-click-right = "${../../../../home/desktop/waybar/scripts/vpn_cycle.sh} prev";
          on-click-middle = "${../../../../home/desktop/waybar/scripts/vpn_cycle.sh} last";
          tooltip = false;
        };

        "custom/mpris" = {
          exec = "${../../../../home/desktop/waybar/scripts/mpris.sh}";
          interval = 5;  # battery: reduced from 1s
          tooltip = false;
        };

        "clock#date" = {
          interval = 60;
          format = "{:%F}";
          tooltip = true;
          tooltip-format = "{:L%Y.%m.%d}";
        };

        "custom/time" = {
          exec = "${../../../../home/desktop/waybar/scripts/clock_time.sh}";
          interval = 60;
          tooltip = false;
        };

        "sway/workspaces" = {
          format = "{name} {windows}";
          format-window-separator = " ";
          window-rewrite-default = "";
          window-rewrite = {
            "title<.*youtube.*>" = "";
            "class<firefox>" = "";
            "class<librewolf>" = "";
            "class<Alacritty>" = "";
            "class<thunar>" = "";
            "class<discord>" = "";
          };
          persistent-workspaces = {
            "*" = [ 1 2 3 4 5 ];
          };
        };

        "custom/volume" = {
          exec = "${../../../../home/desktop/waybar/scripts/volume.sh}";
          interval = "once";
          signal = 5;
          on-click = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && pkill -SIGRTMIN+5 waybar";
          on-click-middle = "pavucontrol";
        };

        wireplumber = {
          node-type = "Audio/Source";
          format = "MIC";
          format-muted = "<span color='#B96B6B'>MTD</span>";
          on-click = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
          tooltip-format = "{node_name}";
        };

        "custom/brightness" = {
          exec = "${./scripts/brightness.sh}";
          interval = "once";
          signal = 4;
          tooltip = false;
        };

        "custom/battery" = {
          exec = "${./scripts/battery.sh}";
          interval = 30;
          tooltip = false;
        };

        "custom/mouse" = {
          exec = "${../../../../home/desktop/waybar/scripts/mouse_battery.sh}";
          interval = 60;
          tooltip = false;
        };

        "custom/memory" = {
          exec = "${../../../../home/desktop/waybar/scripts/memory.sh}";
          interval = 10;  # battery: reduced from 5s
          tooltip = false;
        };

        "custom/cpu" = {
          exec = "${../../../../home/desktop/waybar/scripts/cpu_status.sh}";
          interval = 10;  # battery: reduced from 5s
          tooltip = false;
        };

        "custom/thermalmode" = {
          exec = "${./scripts/thermal_mode.sh}";
          interval = 2;
          on-click = "${./scripts/thermal_toggle.sh}";
          on-click-middle = "set-cpu-mode god && pkill -RTMIN+3 waybar";
          signal = 3;
          tooltip = false;
        };
      };
    };
  };
}
