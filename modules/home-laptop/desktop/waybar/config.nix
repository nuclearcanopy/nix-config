{ ... }:

# Laptop waybar config.
# Differences from kuraokami:
#   - Output: all outputs (no hardcoded DP-1/DP-2)
#   - Removed: custom/gpu (no LACT), custom/mouse (no wireless mouse tracking)
#   - Added: battery module (critical for laptop)
#   - Scripts reused from home/desktop/waybar/scripts/
{
  programs.waybar = {
    enable = true;
    style = builtins.readFile ../../../home/desktop/waybar/style.css;

    settings = {
      mainBar = {
        reload_style_on_change = true;
        fixed-center = true;
        layer = "top";
        position = "top";
        height = 39;
        spacing = 0;

        modules-left = [
          "clock#date"
          "custom/time"
          "custom/volume"
          "wireplumber"
          "group/expand"
          "custom/mpris"
        ];
        modules-center = [
          "sway/workspaces"
        ];
        modules-right = [
          "custom/battery"
          "custom/memory"
          "custom/cpu"
          "custom/firmware"
          "custom/reboot"
          "custom/power"
        ];

        "custom/power" = {
          format = "PWR";
          on-click-middle = "systemctl suspend";
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

        "custom/mpris" = {
          exec = "${../../../home/desktop/waybar/scripts/mpris.sh}";
          interval = 1;
          tooltip = false;
        };

        "clock#date" = {
          interval = 60;
          format = "{:%F}";
          tooltip = true;
          tooltip-format = "{:L%Y.%m.%d}";
        };

        "custom/time" = {
          exec = "${../../../home/desktop/waybar/scripts/clock_time.sh}";
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
          exec = "${../../../home/desktop/waybar/scripts/volume.sh}";
          interval = 1;
          on-click = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
          on-click-middle = "pavucontrol";
        };

        wireplumber = {
          node-type = "Audio/Source";
          format = "MIC";
          format-muted = "<span color='#B96B6B'>MTD</span>";
          on-click = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
          tooltip-format = "{node_name}";
        };

        "custom/battery" = {
          exec = "${./scripts/battery.sh}";
          interval = 30;
          tooltip = false;
        };

        "custom/memory" = {
          exec = "${../../../home/desktop/waybar/scripts/memory.sh}";
          interval = 5;
          tooltip = false;
        };

        "custom/cpu" = {
          exec = "${../../../home/desktop/waybar/scripts/cpu_status.sh}";
          interval = 5;
          tooltip = false;
        };
      };
    };
  };
}
