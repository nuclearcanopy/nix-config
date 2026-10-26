{
  homeManager.modules.alacritty = { config, ... }: {
    xdg.configFile."alacritty/colors-dark.toml".text = ''
      [colors.primary]
      background = "#000000"
      foreground = "#d0d0d0"

      [colors.cursor]
      text = "#000000"
      cursor = "#d0d0d0"

      [colors.selection]
      text = "#000000"
      background = "#c0dfdd"

      [colors.normal]
      black = "#000000"
      red = "#a04a4a"
      green = "#758d5a"
      yellow = "#a89971"
      blue = "#6c99ba"
      magenta = "#9e4e85"
      cyan = "#d0d0d0"
      white = "#f0f0f0"

      [colors.bright]
      black = "#505050"
      red = "#a04a4a"
      green = "#758d5a"
      yellow = "#a89971"
      blue = "#6c99ba"
      magenta = "#9e4e85"
      cyan = "#c0dfdd"
      white = "#f0f0f0"
    '';

    xdg.configFile."alacritty/colors-light.toml".text = ''
      [colors.primary]
      background = "#f5f5f0"
      foreground = "#2b2b2b"

      [colors.cursor]
      text = "#f5f5f0"
      cursor = "#2b2b2b"

      [colors.selection]
      text = "#2b2b2b"
      background = "#bcd9d6"

      [colors.normal]
      black = "#e8e8e3"
      red = "#a04a4a"
      green = "#5f7548"
      yellow = "#8a7a52"
      blue = "#4f7c9e"
      magenta = "#8a3d70"
      cyan = "#2b6e68"
      white = "#2b2b2b"

      [colors.bright]
      black = "#c5c5c0"
      red = "#a04a4a"
      green = "#5f7548"
      yellow = "#8a7a52"
      blue = "#4f7c9e"
      magenta = "#8a3d70"
      cyan = "#bcd9d6"
      white = "#1a1a1a"
    '';

    programs.alacritty = {
      enable = true;

      settings = {
        # current-colors.toml is a symlink set-theme-mode flips between
        # colors-{dark,light}.toml; alacritty's live_config_reload (default
        # on) inotify-watches imported files, so this applies with no restart.
        general.import = [ "${config.xdg.configHome}/alacritty/current-colors.toml" ];

        font = {
          normal = {
            family = "JetBrainsMono Nerd Font";
            style = "Regular";
          };
          bold = {
            family = "JetBrainsMono Nerd Font";
            style = "Bold";
          };
          italic = {
            family = "JetBrainsMono Nerd Font";
            style = "Italic";
          };
          bold_italic = {
            family = "JetBrainsMono Nerd Font";
            style = "Bold Italic";
          };
          size = 16;
        };

        window.opacity = 1.0;

        cursor.style.shape = "Beam";
      };
    };
  };
}
