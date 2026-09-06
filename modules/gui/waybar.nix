{
  # Single waybar bucket for kuraokami and nidhoggr.
  # Profile-driven: hosts set `waybar.profile = "kuraokami" | "laptop"`.
  # Common modules (clock, time, volume, mic, mpris, vpn, airgap, cpu,
  # memory, mouse, workspaces, reboot, power, expand-tray) live once; the
  # profile flag controls layout, output pinning, start_hidden, intervals,
  # and which extras get added (gpu+firmware for kuraokami; battery, brightness,
  # thermalmode, dock, sleep, scroll-volume for laptop).
  homeManager.modules.waybar = { config, lib, pkgs, ... }:

    let
      profile = config.waybar.profile;
      isLaptop = profile == "laptop";
      isDesktop = profile == "kuraokami";

      scriptsDir = ./waybar/scripts;
      script = name: "${scriptsDir}/${name}";

      # Waybar 0.15 silently loses its layer-shell surface when an output is
      # reconfigured (mode/refresh change, replug) and never rebinds, so we
      # restart it on real output changes. But sway also fires "output" events
      # for DPMS blanking (swayidle screen-off/on) and transient resume events
      # where nothing about the topology actually changed; restarting on those
      # is what produced the duplicate/flashing bars. So we diff a topology
      # signature (name, active, mode, refresh, transform, scale; DPMS excluded)
      # and only restart when it genuinely changes. A 2-second coalesce absorbs
      # the burst of events a single plug/unplug fires.
      outputWatcher = pkgs.writeShellScript "waybar-output-watcher" ''
        set -eu
        sig() {
          ${pkgs.sway}/bin/swaymsg -t get_outputs \
            | ${pkgs.jq}/bin/jq -cS 'sort_by(.name) | map({name, active, transform, scale, m: (.current_mode // {} | {width, height, refresh})})'
        }
        last=$(sig || echo "")
        ${pkgs.sway}/bin/swaymsg -t subscribe -m '["output"]' | while read -r _; do
          while read -r -t 2 _; do :; done
          cur=$(sig || echo "$last")
          if [ "$cur" != "$last" ]; then
            last=$cur
            ${pkgs.systemd}/bin/systemctl --user restart waybar.service
          fi
        done
      '';
    in
    {
      options.waybar.profile = lib.mkOption {
        type = lib.types.enum [ "kuraokami" "laptop" ];
        description = "Selects waybar layout and modules per host.";
      };

      config.systemd.user.services.waybar-output-watcher = {
        Unit = {
          Description = "Restart waybar when sway outputs change";
          PartOf = [ "sway-session.target" ];
          After = [ "sway-session.target" ];
          ConditionEnvironment = "WAYLAND_DISPLAY";
        };
        Service = {
          ExecStart = "${outputWatcher}";
          Restart = "on-failure";
          RestartSec = 3;
        };
        Install.WantedBy = [ "sway-session.target" ];
      };

      # xembedsniproxy owns the _NET_SYSTEM_TRAY_S0 X selection on
      # XWayland and forwards XEmbed tray clients (java AWT, wine, older
      # Qt/GTK) to any StatusNotifierWatcher on the session bus. This is
      # what makes SystemTray.isSupported() return true for OpenJDK on
      # sway. snixembed was the wrong direction (SNI->XEmbed). Comes from
      # kdePackages.plasma-workspace; heavy closure but no lighter proxy
      # exists in nixpkgs.
      config.systemd.user.services.xembedsniproxy = {
        Unit = {
          Description = "XEmbed to StatusNotifierItem tray proxy";
          PartOf = [ "sway-session.target" ];
          After = [ "sway-session.target" "waybar.service" ];
          ConditionEnvironment = "DISPLAY";
        };
        Service = {
          # Force Qt xcb platform; on sway both DISPLAY and WAYLAND_DISPLAY
          # are set and Qt6 defaults to Wayland, which leaves the proxy
          # without an X11 connection and it never claims _NET_SYSTEM_TRAY_S0.
          Environment = "QT_QPA_PLATFORM=xcb";
          ExecStart = "${pkgs.kdePackages.plasma-workspace}/bin/xembedsniproxy";
          Restart = "on-failure";
          RestartSec = 3;
        };
        Install.WantedBy = [ "sway-session.target" ];
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
            start_hidden = false;
            spacing = 0;
          } // lib.optionalAttrs isDesktop {
            output = [ "DP-1" "HDMI-A-1" ];
          } // {
            modules-left =
              [ "clock#date" "custom/time" "custom/sep" "custom/volume" "custom/mic" "custom/sep" ]
              ++ lib.optional isLaptop "custom/brightness"
              ++ [ "custom/caffeine" "custom/sep" "custom/vpn" "custom/airgap" ]
              ++ lib.optional isLaptop "custom/bluetooth"
              ++ lib.optional isLaptop "custom/thermalmode"
              ++ [ "group/expand" ]
              ++ lib.optional isDesktop "custom/mpris";

            modules-center = [ "sway/workspaces" ];

            modules-right =
              [ "custom/mouse" "custom/memory" "custom/ssd" "custom/sep" "custom/cpu" ]
              ++ lib.optional isDesktop "custom/gpu"
              ++ lib.optional isLaptop "custom/battery"
              ++ [ "custom/sep" ]
              ++ lib.optional isLaptop "custom/dock"
              ++ [ "custom/reboot" ]
              ++ lib.optional isDesktop "custom/firmware"
              ++ [ "custom/sleep" "custom/power" ];

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
              on-scroll-up = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
              on-scroll-down = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
            };

            # Custom mic indicator (replaces the builtin wireplumber module,
            # which races on EasyEffects' virtual source node: "Object 'N'
            # not found"). Event-driven via mic.sh; MIC / red MTD when muted.
            "custom/mic" = {
              exec = script "mic.sh";
              on-click = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
              tooltip = false;
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
              # middle-click only: a stray left-click here nukes all
              # connectivity and persists across reboot, so require a
              # deliberate press to arm airgap.
              on-click-middle = script "airgap_toggle.sh";
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
                "class<[Pp]cmanfm>" = "";
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

            "custom/ssd" = {
              exec = script "ssd.sh";
              interval = 60;
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
              on-click-middle = "systemctl poweroff";
              tooltip = false;
            };

            "custom/sleep" = {
              format = "SLP";
              on-click-middle = "systemctl suspend";
              tooltip = false;
            };

            "custom/sep" = {
              format = "|";
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
            "custom/bluetooth" = {
              exec = script "bt_mode.sh";
              interval = 10;
              signal = 12;
              on-click = script "bt_toggle.sh";
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
