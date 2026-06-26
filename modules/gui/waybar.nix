{
  # Single waybar bucket for kuraokami and nidhoggr.
  # Profile-driven: hosts set `waybar.profile = "kuraokami" | "laptop"`.
  # Common modules (clock, time, volume, mic, mpris, vpn, airgap, cpu,
  # memory, mouse, workspaces, reboot, power, expand-tray) live once; the
  # profile flag controls layout, output pinning, start_hidden, intervals,
  # and which extras get added (gpu+firmware for kuraokami; battery, brightness,
  # thermalmode, dock, sleep, scroll-volume for laptop).
  homeManager.modules.waybar = { config, lib, ... }:

    let
      profile = config.waybar.profile;
      isLaptop = profile == "laptop";
      isDesktop = profile == "kuraokami";

      scriptsDir = ./waybar/scripts;
      script = name: "${scriptsDir}/${name}";
    in
    {
      options.waybar.profile = lib.mkOption {
        type = lib.types.enum [ "kuraokami" "laptop" ];
        description = "Selects waybar layout and modules per host.";
      };

      config.programs.waybar = {
        enable = true;
        systemd = { enable = true; targets = [ "sway-session.target" ]; };
        style = builtins.readFile ./waybar/style.css;

        settings = {
          mainBar = {
            reload_style_on_change = isDesktop;
            fixed-center = true;
            layer = "top";
            position = "top";
            height = 39;
            start_hidden = isDesktop;
            spacing = 0;
          } // lib.optionalAttrs isDesktop {
            output = [ "DP-1" "DP-2" ];
          } // {
            modules-left =
              [ "clock#date" "custom/time" ]
              ++ lib.optional isLaptop "custom/sep"
              ++ [ "custom/volume" "wireplumber" ]
              ++ lib.optional isLaptop "custom/sep"
              ++ lib.optional isLaptop "custom/brightness"
              ++ [ "custom/caffeine" ]
              ++ lib.optional isLaptop "custom/sep"
              ++ [ "custom/vpn" "custom/airgap" ]
              ++ lib.optional isLaptop "custom/thermalmode"
              ++ [ "group/expand" ]
              ++ lib.optional isDesktop "custom/mpris";

            modules-center = [ "sway/workspaces" ];

            modules-right =
              [ "custom/mouse" "custom/memory" ]
              ++ lib.optional isLaptop "custom/sep"
              ++ [ "custom/cpu" ]
              ++ lib.optional isDesktop "custom/gpu"
              ++ lib.optional isDesktop "custom/firmware"
              ++ lib.optional isLaptop "custom/battery"
              ++ lib.optional isLaptop "custom/sep"
              ++ lib.optional isLaptop "custom/dock"
              ++ [ "custom/reboot" ]
              ++ lib.optional isLaptop "custom/sleep"
              ++ [ "custom/power" ];

            # ── Common modules ────────────────────────────────────────────
            "clock#date" = {
              interval = 60;
              format = "{:%F}";
              tooltip = true;
              tooltip-format = "{:L%Y.%m.%d}";
            };

            "custom/time" = {
              exec = script "clock_time.sh";
              interval = 60;
              tooltip = false;
            };

            "custom/volume" = {
              exec = script "volume.sh";
              on-click = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
              on-click-middle = "pavucontrol";
            } // lib.optionalAttrs isLaptop {
              on-scroll-up = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
              on-scroll-down = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
            };

            wireplumber = {
              node-type = "Audio/Source";
              format = "MIC";
              format-muted = "<span color='#B96B6B'>MTD</span>";
              on-click = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
              tooltip-format = "{node_name}";
            };

            "custom/caffeine" = {
              exec = script "caffeine.sh";
              return-type = "json";
              interval = "once";
              signal = 8;
              on-click = "${script "caffeine.sh"} toggle";
              tooltip = true;
            };

            "custom/vpn" = {
              exec = script "vpn_status.sh";
              interval = 10;
              signal = 9;
              on-click = "${script "vpn_cycle.sh"} next";
              on-click-right = "${script "vpn_cycle.sh"} prev";
              on-click-middle = "${script "vpn_cycle.sh"} last";
              tooltip = false;
            };

            "custom/airgap" = {
              exec = script "airgap_mode.sh";
              interval = 10;
              signal = 11;
              on-click = script "airgap_toggle.sh";
              tooltip = false;
            };

            "custom/mpris" = {
              exec = script "mpris.sh";
              interval = if isLaptop then 5 else 5;
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
              } // lib.optionalAttrs isDesktop {
                "class<steam>" = "";
              };
              persistent-workspaces = {
                "*" = [ 1 2 3 4 5 ];
              };
            };

            "custom/cpu" = {
              exec = script "cpu_status.sh";
              interval = if isLaptop then 10 else 5;
              tooltip = false;
            };

            "custom/memory" = {
              exec = script "memory.sh";
              interval = if isLaptop then 10 else 5;
              tooltip = false;
            };

            "custom/mouse" = {
              exec = script "mouse_battery.sh";
              interval = 60;
              tooltip = false;
            };

            "custom/reboot" = {
              format = "RBT";
              on-click-middle = "systemctl reboot";
              tooltip = false;
            };

            "custom/power" = {
              format = "PWR";
              on-click-middle = if isLaptop then "systemctl poweroff" else "systemctl suspend";
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
          } // lib.optionalAttrs isDesktop {
            # ── Desktop-only modules ──────────────────────────────────────
            "custom/gpu" = {
              exec = script "gpu_status.sh";
              interval = 5;
              tooltip = false;
            };

            "custom/firmware" = {
              format = "FRM";
              on-click-middle = "systemctl reboot --firmware-setup";
              tooltip = false;
            };
          } // lib.optionalAttrs isLaptop {
            # ── Laptop-only modules ───────────────────────────────────────
            "custom/sep" = {
              format = "|";
              tooltip = false;
            };

            "custom/sleep" = {
              format = "SLP";
              on-click-middle = "systemctl suspend";
              tooltip = false;
            };

            "custom/brightness" = {
              exec = script "brightness.sh";
              interval = "once";
              signal = 4;
              on-scroll-up = "set-brightness 10%+ && pkill -SIGRTMIN+4 waybar";
              on-scroll-down = "set-brightness 10%- && pkill -SIGRTMIN+4 waybar";
              tooltip = false;
            };

            "custom/battery" = {
              exec = script "battery.sh";
              interval = 30;
              signal = 7;
              on-click-middle = "sudo -A tlp fullcharge BAT1 && pkill -RTMIN+7 waybar";
              tooltip = false;
            };

            "custom/dock" = {
              exec = script "dock_mode.sh";
              return-type = "json";
              interval = "once";
              signal = 10;
              on-click = script "dock_toggle.sh";
              tooltip = true;
            };

            "custom/thermalmode" = {
              exec = script "thermal_mode.sh";
              interval = 5;
              on-click = "${script "thermal_toggle.sh"} next";
              on-click-right = "${script "thermal_toggle.sh"} prev";
              on-click-middle = "set-cpu-mode god && pkill -RTMIN+3 waybar";
              signal = 3;
              tooltip = false;
            };
          };
        };
      };
    };
}
