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
            # external HDMI sits on top, laptop panel directly below.
            # forced to 1080p@30 to reduce iGPU load (UHD 620 struggles at 1440p60).
            "HDMI-A-2" = {
              mode = "1920x1080@30Hz";
              position = "0 0";
            };
            "eDP-1" = {
              position = "0 1080";
            };
          };

          input = {
            "*" = {
              xkb_layout = "us";
              accel_profile = "flat";
              pointer_accel = "-0.5";
            };

            # xkb_options only on the internal keyboard; HHKB unaffected.
            # Both identifiers covered: current kernel exposes Translated Set 2,
            # older/alternate paths surfaced Raw Set 2. Sway silently no-ops
            # whichever doesn't match, so listing both is safe.
            "1:1:AT_Translated_Set_2_keyboard" = {
              xkb_options = "ctrl:nocaps,ctrl:swap_lalt_lctl";
            };

            "1:2:AT_Raw_Set_2_keyboard" = {
              xkb_options = "ctrl:nocaps,ctrl:swap_lalt_lctl";
            };

            "2:10:TPPS/2_IBM_TrackPoint" = {
              accel_profile = "flat";
              pointer_accel = "0.3";
              scroll_factor = "0.25";
            };

            # Razer DeathAdder V4 Pro: flat profile (no accel), ~25% slower than kuraokami.
            "5426:191:Razer_DeathAdder_V4_Pro" = {
              accel_profile = "flat";
              pointer_accel = "-0.88";
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
