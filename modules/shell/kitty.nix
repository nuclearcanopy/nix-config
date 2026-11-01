{
  # Primary terminal. Kitty provides the graphics protocol used by mpv's
  # --vo=kitty output without an additional desktop UI layer.
  homeManager.modules.kitty = { config, ... }: {
    xdg.configFile."kitty/colors-dark.conf".text = ''
      background #000000
      foreground #d0d0d0
      cursor #d0d0d0
      cursor_text_color #000000
      selection_background #c0dfdd
      selection_foreground #000000
      color0 #000000
      color1 #a04a4a
      color2 #758d5a
      color3 #a89971
      color4 #6c99ba
      color5 #9e4e85
      color6 #d0d0d0
      color7 #f0f0f0
      color8 #505050
      color9 #a04a4a
      color10 #758d5a
      color11 #a89971
      color12 #6c99ba
      color13 #9e4e85
      color14 #c0dfdd
      color15 #f0f0f0
    '';

    xdg.configFile."kitty/colors-light.conf".text = ''
      background #f5f5f0
      foreground #2b2b2b
      cursor #2b2b2b
      cursor_text_color #f5f5f0
      selection_background #bcd9d6
      selection_foreground #2b2b2b
      color0 #e8e8e3
      color1 #a04a4a
      color2 #5f7548
      color3 #8a7a52
      color4 #4f7c9e
      color5 #8a3d70
      color6 #2b6e68
      color7 #2b2b2b
      color8 #c5c5c0
      color9 #a04a4a
      color10 #5f7548
      color11 #8a7a52
      color12 #4f7c9e
      color13 #8a3d70
      color14 #bcd9d6
      color15 #1a1a1a
    '';

    programs.kitty = {
      enable = true;
      settings = {
        font_family = "JetBrainsMono Nerd Font";
        font_size = 16;
        scrollback_lines = 50000000;
        window_padding_width = 8;
        window_padding_height = 6;
        cursor_shape = "beam";
        copy_on_select = true;
        hide_window_decorations = "yes";
        tab_bar_style = "hidden";
        confirm_os_window_close = 0;
        enable_audio_bell = false;
        visual_bell_duration = 0;
        notify_on_cmd_finish = "never";
        allow_remote_control = "no";
        update_check_interval = 0;
        shell_integration = "disabled";
      };
      extraConfig = ''
        include ${config.xdg.configHome}/kitty/current-colors.conf
      '';
    };
  };
}
