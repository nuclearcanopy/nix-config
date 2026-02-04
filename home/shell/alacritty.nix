{ pkgs, ... }:
{
  programs.alacritty = {
    enable = true;

    settings = {
      terminal.shell.program = "${pkgs.fish}/bin/fish";

      font = {
        normal.family = "JetBrainsMonoNerdFont";
        size = 16;
      };

      window.opacity = 1.0;

      cursor.style.shape = "Beam";

      colors = {
        primary = {
          background = "#0c0c0c";
          foreground = "#d0d0d0";
        };

        cursor = {
          text = "#0c0c0c";
          cursor = "#d0d0d0";
        };

        selection = {
          text = "#0c0c0c";
          background = "#c0dfdd";
        };
        
        normal = {
          black   = "#151515";
          red     = "#a04a4a";
          green   = "#758d5a";
          yellow  = "#a89971";
          blue    = "#6c99ba";
          magenta = "#9e4e85";
          cyan    = "#d0d0d0";
          white   = "#f0f0f0";
        };
        
        bright = {
          black   = "#505050";
          red     = "#a04a4a";
          green   = "#758d5a";
          yellow  = "#a89971";
          blue    = "#6c99ba";
          magenta = "#9e4e85";
          cyan    = "#c0dfdd";
          white   = "#f0f0f0";
        };
      };
    };
  };
}
