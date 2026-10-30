{
  # Primary terminal. Picked over foot for the kitty graphics protocol: the
  # terminal media player draws mpv's `--vo=kitty` output into a sub-rect of
  # the grid, so nothing here may disable or shrink inline graphics. Rationale
  # and the full option-by-option reasoning: docs/terminal.md.
  homeManager.modules.ghostty = {
    programs.ghostty = {
      enable = true;

      settings = {
        # Unlike every other themed app here, ghostty needs no symlink and no
        # reload: it picks between the two themes below from the gtk portal's
        # org.freedesktop.appearance color-scheme, which set-theme-mode moves
        # via dconf. See docs/gui.md.
        theme = "dark:mono-dark,light:mono-light";

        # Matches alacritty and fonts.nix's monospace default; the second
        # entry is an explicit fallback for codepoints JetBrains Mono lacks.
        font-family = [ "JetBrainsMono Nerd Font" "Noto Color Emoji" ];
        font-size = 16;

        # 1GiB, up from the 320MB default, and counted per screen. Video into
        # a sub-rect transmits and frees a frame continuously; headroom here
        # keeps ghostty from evicting live placements mid-stream.
        image-storage-limit = 1073741824;

        # One resident process serves every window. Measured, launch to
        # window mapped in sway: 350ms cold, 200ms against a warm instance,
        # 100ms via `ghostty +new-window` (what mod+q uses). Staying
        # resident with zero windows is the point of the second line, and
        # is what the systemd unit's --initial-window=false expects.
        gtk-single-instance = true;
        quit-after-last-window-closed = false;

        # sway draws the border and runs titlebar = false; client-side
        # decorations would just add a header bar inside the tile.
        window-decoration = "none";
        # Constant in a tiling WM, so the size popup is pure noise.
        resize-overlay = "never";
        window-padding-x = 8;
        window-padding-y = 6;

        # Beam, as in alacritty. The shell-integration `cursor` feature
        # (on by default) swaps it to a block while a command runs, which
        # is the same visual cue alacritty's vi-mode block gave.
        cursor-style = "bar";

        scrollback-limit = 50000000;
        mouse-hide-while-typing = true;
        # alacritty never asked, and these windows hold long-running jobs
        # often enough that a prompt on every close is friction.
        confirm-close-surface = false;

        keybind = [
          # ctrl+shift+q defaults to `quit`, which under gtk-single-instance
          # tears down every window at once; alacritty had no such binding.
          "ctrl+shift+q=unbind"
        ];
      };

      # Ported 1:1 from alacritty's colors-{dark,light}.toml so the two
      # terminals look identical during the changeover. Note the terminal
      # background is the one surface that is not the #f0f0f0 of the rest of
      # the light theme; it keeps alacritty's warmer #f5f5f0.
      themes = {
        mono-dark = {
          background = "#000000";
          foreground = "#d0d0d0";
          cursor-color = "#d0d0d0";
          cursor-text = "#000000";
          selection-background = "#c0dfdd";
          selection-foreground = "#000000";
          palette = [
            "0=#000000"
            "1=#a04a4a"
            "2=#758d5a"
            "3=#a89971"
            "4=#6c99ba"
            "5=#9e4e85"
            "6=#d0d0d0"
            "7=#f0f0f0"
            "8=#505050"
            "9=#a04a4a"
            "10=#758d5a"
            "11=#a89971"
            "12=#6c99ba"
            "13=#9e4e85"
            "14=#c0dfdd"
            "15=#f0f0f0"
          ];
        };

        mono-light = {
          background = "#f5f5f0";
          foreground = "#2b2b2b";
          cursor-color = "#2b2b2b";
          cursor-text = "#f5f5f0";
          selection-background = "#bcd9d6";
          selection-foreground = "#2b2b2b";
          palette = [
            "0=#e8e8e3"
            "1=#a04a4a"
            "2=#5f7548"
            "3=#8a7a52"
            "4=#4f7c9e"
            "5=#8a3d70"
            "6=#2b6e68"
            "7=#2b2b2b"
            "8=#c5c5c0"
            "9=#a04a4a"
            "10=#5f7548"
            "11=#8a7a52"
            "12=#4f7c9e"
            "13=#8a3d70"
            "14=#bcd9d6"
            "15=#1a1a1a"
          ];
        };
      };
    };
  };
}
