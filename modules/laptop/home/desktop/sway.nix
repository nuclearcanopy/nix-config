{ ... }:

{
  imports = [ ../../../shared/sway-base.nix ];

  wayland.windowManager.sway = {
    config = {
      keybindings = {
        "Mod4+Mod1+4" = "exec ${./waybar/scripts/thermal_toggle.sh}";
      };

      output."*" = {
        bg = "#000000 solid_color";
      };

      input = {
        "*" = {
          xkb_layout = "us";
          xkb_options = "ctrl:nocaps,ctrl:swap_lalt_lctl";
          accel_profile = "flat";
          pointer_accel = "-0.5";
        };

        "type:touchpad" = {
          natural_scroll = "enabled";
          tap = "enabled";
          dwt = "enabled";
          middle_emulation = "enabled";
          pointer_accel = "-0.3";
        };
      };

      startup = [
        { command = "waybar"; }
        { command = "autotiling-rs"; }
      ];
    };
  };
}
