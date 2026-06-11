{ ... }:

{
  imports = [ ../../../shared/sway-base.nix ];

  wayland.windowManager.sway = {
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

        # xkb_options only on the internal keyboard; keeps HHKB unaffected
        "1:2:AT_Raw_Set_2_keyboard" = {
          xkb_options = "ctrl:nocaps,ctrl:swap_lalt_lctl";
        };

        "2:10:TPPS/2_IBM_TrackPoint" = {
          accel_profile = "flat";
          pointer_accel = "0.3";
        };

        "type:touchpad" = {
          accel_profile = "adaptive";
          pointer_accel = "-0.1";
          natural_scroll = "enabled";
          tap = "enabled";
          dwt = "disabled";
          middle_emulation = "enabled";
        };
      };

      startup = [
        { command = "autotiling-rs"; }
        { command = "swaymsg workspace 1"; }
      ];
    };
  };
}
