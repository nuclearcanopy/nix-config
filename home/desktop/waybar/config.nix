{ ... }:

{
  programs.waybar = {
    enable = true;

    systemd.enable = true;
    systemd.target = "hyprland-session.target";

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
          #"network"
          #"custom/vpn"
          "group/expand"
          "mpris"
          "custom/cava"
        ];
        modules-center = [
          "clock"
          "hyprland/workspaces"
          "pulseaudio"
          "wireplumber"
          "custom/updates"
        ];
        modules-right = [
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
          format = "  ";
          on-click-middle = "systemctl suspend";
          tooltip = false;
        };

        "custom/reboot" = {
          format = "  ";
          on-click-middle = "systemctl reboot";
          tooltip = false;
        };

        "custom/logout" = {
          format = " 󰍃 ";
          on-click-middle = "loginctl terminate-user $USER";
          tooltip = false;
        };
        
        #"network" = {
        #  format-ethernet = " 󰀃 ";
        #  tooltip-format = " 󰅧 {bandwidthUpBytes} 󰅢 {bandwidthDownBytes}";
        #  format-linked = "<span color='#FFA500'> 󱘖 </span>{ifname} (No IP)";
        #  format-disconnected = "<span color='#FF4040'>  </span>";
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
          format = " 󰍜 ";
          tooltip = false;
        };

        "group/expand" = {
          orientation = "horizontal";
          drawer = {
            transition-duration = 600;
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
          format = "{status_icon} {dynamic}";
          interval = 0;
          dynamic-len = 50;
          dynamic-separator = " ─ ";
          dynamic-order = [ "artist" ];
          status-icons = {
            playing = "";
            paused = "󰏤";
            stopped = "";
          };

          ignored-players = [ "firefox" ];
        };

        "custom/cava" = {
          exec = "${./scripts/cava.sh}";
        };

        # --/ SYSTEM INFO /---
        clock = {
          interval = 60;
          format = "  {:%H:%M   %d.%m %a}";
          tooltip = true;
          tooltip-format = "{:L%Y.%m.%d, %A}";
        };

        "hyprland/workspaces" = {
          format = "{icon}";
          icon-size = 32;
          spacing = 16;
          persistent-workspaces = { "*" = [ 1 2 3 4 5 ]; };
          format-icons = {
            "1" = "I ";
            "2" = "II ";
            "3" = "III ";
            "4" = "IV ";
            "5" = "V ";
            sort-by-number = true;
          };
        };

        pulseaudio = {
          format = " {volume}% {icon} ";
          format-muted = "<span color='#B96B6B'>00%  </span>";
          format-icons = {
            headphone = " ";
            hands-free = " ";
            headset = " ";
            phone = " ";
            portable = " ";
            car = " ";
            default = [ " " " " " " ];
          };
          on-click = "pactl -- set-sink-mute @DEFAULT_SINK@ toggle";
          on-click-middle = "pavucontrol";
        };

        wireplumber = {
          node-type = "Audio/Source";
          format = "";
          format-muted = "󰍮";
          on-click = "pactl set-source-mute @DEFAULT_SOURCE@ toggle";
          tooltip-format = "{node_name}";
        };

        # --/ HARDWARE  /---
        "custom/lact" = {
          exec = "lact cli profile get";
          interval = 30;
          format = "  {} ";
          on-click = "${./scripts/lact.sh}";
          signal = 8;
        };

        memory = {
          format = " 󰍛 {used:0.1f}G ";
          tooltip = false;
        };

        "group/cpuheader" = {
          orientation = "horizontal";
          modules = [ "temperature#cpu" "cpu" ];
        };
        "temperature#cpu" = {
          hwmon-path = "/sys/class/hwmon/hwmon1/temp1_input";
          format = "  {temperatureC}° ";
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
          format = "󰢮 {temperatureC}° ";
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
          format = " ";
          on-click = "pkill waybar && waybar &";
          tooltip = false;
        };
      };
    };
  };
}
