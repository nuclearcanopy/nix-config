{ ... }:

{
  programs.waybar = {
    enable = true;

    systemd.enable = true;
    systemd.target = "sway-session.target";

    # Import the external CSS file
    style = builtins.readFile ./style.css;

    settings = {
      mainBar = {
        reload_style_on_change = true;
        fixed-center = true;
        layer = "top";
        output = [ "DP-1" "HDMI-A-1" ];
        position = "top";
        height = 39;
        spacing = 0;

        # Layout
        modules-left = [
          "custom/power"
          "custom/reboot"
          "custom/logout"
          "clock"
          #"network"
          #"custom/vpn"
          "group/expand"
          "mpris"
        ];
        modules-center = [
          "sway/workspaces"
        ];
        modules-right = [
          "pulseaudio"
          "wireplumber"
          "custom/lact"
          "memory"
          "group/cpuheader"
          "group/gpuheader"
        ];

        # =========================
        # Modules
        # =========================

        # --/ POWER & SESSION /---
        "custom/power" = {
          format = "PWR";
          on-click-middle = "systemctl suspend";
          tooltip = false;
        };

        "custom/reboot" = {
          format = "RBT";
          on-click-middle = "systemctl reboot";
          tooltip = false;
        };

        "custom/logout" = {
          format = "OUT";
          on-click-middle = "loginctl terminate-user $USER";
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

        # --/ CUSTOM TRAY /---
        "custom/expand" = {
          format = ">";
          tooltip = false;
        };

        "group/expand" = {
          orientation = "horizontal";
          drawer = {
            transition-duration = 300;
            transition-to-right = true;
            click-to-reveal = true;
          };
          modules = [ "custom/expand" "tray" ];
        };

        tray = {
          icon-size = 17;
          spacing = 6;
        };

        # --/ MEDIA & VISUALIZER /---
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

        # --/ SYSTEM INFO /---
        clock = {
          interval = 60;
          format = "{:%H:%M  %d.%m %a}";
          tooltip = true;
          tooltip-format = "{:L%Y.%m.%d, %A}";
        };

        "sway/workspaces" = {
          format = "{name}: {windows}";
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
          format-muted = "<span color='#B96B6B'>MIC MUTE</span>";
          on-click = "pactl set-source-mute @DEFAULT_SOURCE@ toggle";
          tooltip-format = "{node_name}";
        };

        # --/ HARDWARE  /---
        "custom/lact" = {
          exec = "lact cli profile get";
          interval = 30;
          format = "GPU:{}";
          on-click = "${./scripts/lact.sh}";
          signal = 8;
        };

        memory = {
          format = "MEM {used:0.1f}G";
          tooltip = false;
        };

        "group/cpuheader" = {
          orientation = "horizontal";
          modules = [ "temperature#cpu" "cpu" ];
        };
        "temperature#cpu" = {
          hwmon-path = "/sys/class/hwmon/hwmon1/temp1_input";
          format = "CPU {temperatureC}°";
          tooltip = false;
        };
        cpu = {
          format = "{usage}%";
          tooltip = true;
        };

        "group/gpuheader" = {
          orientation = "horizontal";
          modules = [ "temperature#gpu" "custom/gpu" ];
        };
        "temperature#gpu" = {
          hwmon-path = "/sys/class/hwmon/hwmon5/temp2_input";
          format = "GPU {temperatureC}°";
          tooltip = false;
        };
        "custom/gpu" = {
          exec = "cat /sys/class/hwmon/hwmon5/device/gpu_busy_percent";
          format = "{}%";
          return-type = "";
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
