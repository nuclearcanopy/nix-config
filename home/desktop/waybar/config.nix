{ ... }:

{
  programs.waybar = {
    enable = true;

    # css import
    style = builtins.readFile ./style.css;

    settings = {
      mainBar = {
        reload_style_on_change = true;
        fixed-center = true;
        layer = "top";
        output = [ "DP-1" "DP-2" ];
        position = "top";
        height = 39;
        spacing = 0;

        # layout
        modules-left = [
          "clock#date"
          "custom/time"
          "pulseaudio"
          "wireplumber"
          #"network"
          #"custom/vpn"
          "group/expand"
          "mpris"
        ];
        modules-center = [
          "sway/workspaces"
        ];
        modules-right = [
          "custom/mouse"
          "custom/memory"
          "custom/cpu"
          "custom/gpu"
          "custom/firmware"
          "custom/reboot"
          "custom/power"
        ];

        # power session
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

        #"network" = {
        #  format-ethernet = "NET";
        #  tooltip-format = "UP {bandwidthUpBytes} DOWN {bandwidthDownBytes}";
        #  format-linked = "<span color='#FFA500'>NET</span>{ifname} (No IP)";
        #  format-disconnected = "<span color='#FF4040'>NO NET</span>";
        #  interval = 1;
        #};

        #"custom/vpn" = {
        #  format = "{}";
        #  return-type = "json";
        #  exec = "${./scripts/vpn.sh}";
        #  interval = 5;
        #  tooltip = true;
        #  on-click = "mullvad-gui";
        #};

        # tray
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

        # media
        mpris = {
          format = "[{status}] {dynamic}";
          interval = 0;
          dynamic-len = 50;
          dynamic-separator = " - ";
          dynamic-order = [ "artist" ];
          status-icons = {
            playing = ">";
            paused = "||";
            stopped = "[]";
          };

          ignored-players = [ "firefox" ];
        };

        # system
        "clock#date" = {
          interval = 60;
          format = "{:%F}";
          tooltip = true;
          tooltip-format = "{:L%Y.%m.%d}";
        };

        "custom/time" = {
          exec = "${./scripts/clock_time.sh}";
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
            "class<steam>" = "";
          };
          persistent-workspaces = {
            "*" = [ 1 2 3 4 5 ];
          };
        };

        pulseaudio = {
          format = "VOL {volume}%";
          format-muted = "<span color='#B96B6B'>VOL MUTE</span>";
          on-click = "pactl -- set-sink-mute @DEFAULT_SINK@ toggle";
          on-click-middle = "pavucontrol";
        };

        wireplumber = {
          node-type = "Audio/Source";
          format = "MIC";
          format-muted = "<span color='#B96B6B'>MTD</span>";
          on-click = "pactl set-source-mute @DEFAULT_SOURCE@ toggle";
          tooltip-format = "{node_name}";
        };

        # hardware
        "custom/mouse" = {
          exec = "${./scripts/mouse_battery.sh}";
          format = "MOU {}%";
          interval = 60;
          tooltip = false;
        };

        "custom/memory" = {
          exec = "${./scripts/memory.sh}";
          interval = 5;
          tooltip = false;
        };

        "custom/cpu" = {
          exec = "${./scripts/cpu_status.sh}";
          interval = 5;
          tooltip = false;
        };

        "custom/gpu" = {
          exec = "${./scripts/gpu_status.sh}";
          interval = 5;
          tooltip = false;
        };

        "custom/refresh" = {
          format = "R";
          on-click = "pkill waybar && waybar &";
          tooltip = false;
        };
      };
    };
  };
}
