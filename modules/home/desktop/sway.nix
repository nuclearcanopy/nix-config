{ ... }:

{
  imports = [ ../../shared/sway-base.nix ];

  wayland.windowManager.sway = {
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
          pointer_accel = "-0.76";
        };

        "type:touchpad" = {
          natural_scroll = "disabled";
        };

        "type:tablet_tool" = {
          map_to_output = "HDMI-A-2";
        };
      };

      startup = [
        { command = "waybar"; }
        { command = "easyeffects -w"; }
        { command = "autotiling-rs"; }
      ];
    };

    extraConfig = ''
      output DP-1 adaptive_sync on
    '';
  };
}
