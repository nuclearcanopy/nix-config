{
  # Host-specific sway: monitor outputs, input devices, host-only keybindings,
  # adaptive-sync extraConfig. Selected by reading osConfig.networking.hostName
  # so computers/<host>.nix contains zero sway content.
  homeManager.modules.sway-host = { osConfig, lib, ... }: {
    wayland.windowManager.sway = lib.mkMerge [
      (lib.mkIf (osConfig.networking.hostName == "kuraokami") {
        config = {
          output = {
            "DP-1" = {
              mode = "2560x1440@120Hz";
              position = "0,0";
              scale = "1";
              bg = "#000000 solid_color";
            };
            "DP-2" = {
              mode = "2560x1440@120Hz";
              position = "2560,0";
              scale = "1";
              bg = "#000000 solid_color";
            };
            "HDMI-A-2" = {
              mode = "1920x1080@60Hz";
              position = "0,1440";
              scale = "1";
              bg = "#000000 solid_color";
            };
          };

          workspaceOutputAssign = [
            { workspace = "1"; output = "DP-1"; }
            { workspace = "2"; output = "DP-2"; }
          ];

          input = {
            "*" = {
              xkb_layout = "us";
              accel_profile = "flat";
              pointer_accel = "-0.84";
            };

            "type:touchpad" = {
              natural_scroll = "disabled";
            };

            "type:tablet_tool" = {
              map_to_output = "HDMI-A-2";
            };
          };
        };

        extraConfig = ''
          output DP-1 adaptive_sync on
        '';
      })

      (lib.mkIf (osConfig.networking.hostName == "nidhoggr") {
        config = {
          keybindings = {
            "Mod4+Mod1+4" = "exec ${./waybar/scripts/thermal_toggle.sh}";
          };

          output = {
            "*" = {
              bg = "#000000 solid_color";
            };
            # external HDMI sits on top, laptop panel directly below
            "HDMI-A-2" = {
              position = "0 0";
            };
            "eDP-1" = {
              position = "0 1440";
            };
          };

          input = {
            "*" = {
              xkb_layout = "us";
              accel_profile = "flat";
              pointer_accel = "-0.5";
            };

            # xkb_options only on the internal keyboard; HHKB unaffected
            "1:2:AT_Raw_Set_2_keyboard" = {
              xkb_options = "ctrl:nocaps,ctrl:swap_lalt_lctl";
            };

            "2:10:TPPS/2_IBM_TrackPoint" = {
              accel_profile = "flat";
              pointer_accel = "0.3";
              scroll_factor = "0.25";
            };

            "type:touchpad" = {
              accel_profile = "adaptive";
              pointer_accel = "-0.1";
              natural_scroll = "enabled";
              tap = "disabled";
              dwt = "disabled";
              middle_emulation = "enabled";
            };
          };
        };
      })
    ];
  };
}
